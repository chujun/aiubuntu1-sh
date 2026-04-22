"""版面分析：检测页面区域类型、裁剪图片、推断阅读顺序"""

import logging
import re
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

from src.config import LayoutConfig

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class Region:
    """检测到的页面区域"""
    region_type: str       # text, image, paragraph_title, header, figure_title, ...
    x1: int                # 左上角 x
    y1: int                # 左上角 y
    x2: int                # 右下角 x
    y2: int                # 右下角 y
    confidence: float      # 置信度


@dataclass(frozen=True)
class FigureInfo:
    """提取的图片信息"""
    image: Image.Image     # 裁剪出的图片
    caption: str           # 图注文本（可为空）
    region: Region         # 对应的版面区域


@dataclass(frozen=True)
class LayoutResult:
    """单页版面分析结果"""
    page_number: int
    regions: list[Region]          # 按阅读顺序排列的所有区域
    figures: list[FigureInfo]      # 提取的图片列表
    text_regions: list[Region]     # 文字区域（供 OCR 使用）
    title_regions: list[Region]    # 标题区域


def _create_model(config: LayoutConfig):
    """延迟加载版面检测模型（避免在导入时加载）"""
    from paddlex import create_model
    return create_model(
        config.model_name,
        pp_option={"run_mode": "paddle"},
    )


def _sort_reading_order(regions: list[Region]) -> list[Region]:
    """按阅读顺序排序：先按 y 坐标从上到下，同一行内按 x 从左到右。

    同一行的判定：两个区域的 y 中心点差值小于较小区域高度的一半。
    """
    if not regions:
        return []

    sorted_by_y = sorted(regions, key=lambda r: r.y1)

    rows: list[list[Region]] = []
    current_row: list[Region] = [sorted_by_y[0]]

    for region in sorted_by_y[1:]:
        prev = current_row[-1]
        prev_center_y = (prev.y1 + prev.y2) / 2
        curr_center_y = (region.y1 + region.y2) / 2
        min_height = min(prev.y2 - prev.y1, region.y2 - region.y1)

        if abs(curr_center_y - prev_center_y) < min_height / 2:
            current_row.append(region)
        else:
            rows.append(current_row)
            current_row = [region]

    rows.append(current_row)

    result = []
    for row in rows:
        result.extend(sorted(row, key=lambda r: r.x1))
    return result


def _find_caption_for_figure(
    figure: Region,
    regions: list[Region],
    config: LayoutConfig,
) -> str:
    """查找图片下方紧邻的图注文本。"""
    for r in regions:
        if r.region_type != "figure_title":
            continue
        # 图注应在图片正下方，距离不超过阈值
        vertical_gap = r.y1 - figure.y2
        if 0 <= vertical_gap <= config.caption_max_distance:
            # 水平位置应有重叠
            overlap_x = min(r.x2, figure.x2) - max(r.x1, figure.x1)
            if overlap_x > 0:
                return ""  # 占位：实际文本需要 OCR 识别后填充
    return ""


def analyze_layout(
    page_image: Image.Image,
    page_number: int,
    config: LayoutConfig,
    *,
    model=None,
) -> LayoutResult:
    """对单页图片执行版面分析。

    输入图片应为深色背景原图，函数内部会反转颜色后再分析。

    Args:
        page_image: 单页图片（深色背景）
        page_number: 页码
        config: 版面分析配置
        model: 预加载的模型实例（可选，避免重复创建）

    Returns:
        LayoutResult 包含所有检测区域和提取的图片
    """
    if model is None:
        model = _create_model(config)

    # 反转颜色：深色背景 → 白底黑字（版面检测效果更好）
    inverted = ImageOps.invert(page_image.convert("RGB"))

    # 保存临时文件供模型读取
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        tmp_path = f.name
        inverted.save(tmp_path)

    try:
        results = list(model.predict(tmp_path))
    finally:
        Path(tmp_path).unlink(missing_ok=True)

    if not results:
        logger.warning(f"页 {page_number}: 版面分析无结果")
        return LayoutResult(
            page_number=page_number,
            regions=[],
            figures=[],
            text_regions=[],
            title_regions=[],
        )

    boxes = results[0].get("boxes", [])

    # 解析检测框为 Region 对象
    all_regions: list[Region] = []
    for box in boxes:
        score = box["score"]
        if score < config.min_confidence:
            continue
        coord = box["coordinate"]
        region = Region(
            region_type=box["label"],
            x1=int(round(float(coord[0]))),
            y1=int(round(float(coord[1]))),
            x2=int(round(float(coord[2]))),
            y2=int(round(float(coord[3]))),
            confidence=score,
        )
        all_regions.append(region)

    # 按阅读顺序排序
    ordered = _sort_reading_order(all_regions)

    # 过滤掉页眉页脚
    content_regions = [
        r for r in ordered
        if r.region_type not in config.header_labels
    ]

    # 分类区域
    text_regions = [
        r for r in content_regions
        if r.region_type not in config.figure_labels
        and r.region_type != "figure_title"
    ]
    title_regions = [
        r for r in content_regions
        if r.region_type in config.title_labels
    ]

    # 提取图片区域
    figures: list[FigureInfo] = []
    for r in content_regions:
        if r.region_type not in config.figure_labels:
            continue
        # 从原始深色图片裁剪（保留原貌）
        fig_img = page_image.crop((r.x1, r.y1, r.x2, r.y2))
        caption = _find_caption_for_figure(r, all_regions, config)
        figures.append(FigureInfo(image=fig_img, caption=caption, region=r))

    logger.info(
        f"页 {page_number}: 检测到 {len(content_regions)} 个内容区域"
        f"（{len(text_regions)} 文字, {len(title_regions)} 标题, {len(figures)} 图片）"
    )

    return LayoutResult(
        page_number=page_number,
        regions=content_regions,
        figures=figures,
        text_regions=text_regions,
        title_regions=title_regions,
    )


def save_figures(
    figures: list[FigureInfo],
    page_number: int,
    output_dir: Path,
    image_prefix: str = "page",
) -> list[str]:
    """保存提取的图片到输出目录。

    Args:
        figures: 图片信息列表
        page_number: 页码
        output_dir: 图片输出目录
        image_prefix: 文件名前缀

    Returns:
        保存的文件路径列表（相对于 output_dir 的父目录）
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    paths: list[str] = []

    for idx, fig in enumerate(figures, 1):
        filename = f"{image_prefix}{page_number:03d}_fig{idx:02d}.png"
        filepath = output_dir / filename
        fig.image.save(filepath)
        # 返回相对路径（用于 Markdown 引用）
        paths.append(f"images/{filename}")
        logger.debug(f"保存图片: {filepath}")

    return paths
