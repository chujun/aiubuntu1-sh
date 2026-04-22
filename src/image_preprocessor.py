"""微信读书截图预处理：UI 裁剪、双页分割、颜色反转"""

import logging
from dataclasses import dataclass

import numpy as np
from PIL import Image, ImageOps

from src.config import CropConfig, SplitConfig

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class SinglePage:
    """分割后的单页图片"""
    page_number: int   # 书籍中的逻辑页码
    image: Image.Image
    is_left: bool      # 是否为左页


def crop_ui(image: Image.Image, config: CropConfig) -> Image.Image:
    """裁剪微信读书 UI 元素（顶部书名栏、底部翻页提示）。

    Args:
        image: 原始截图
        config: 裁剪参数

    Returns:
        裁剪后的图片
    """
    w, h = image.size
    left = config.left
    upper = config.top
    right = w - config.right
    lower = h - config.bottom
    return image.crop((left, upper, right, lower))


def find_center_gap(image: Image.Image, config: SplitConfig) -> int:
    """通过垂直投影检测双页中间的间隔位置。

    在图片水平中心 ±search_ratio 范围内，寻找最大亮度值最低的连续列区域的中心。

    Args:
        image: 裁剪 UI 后的图片
        config: 分割参数

    Returns:
        中线列坐标
    """
    arr = np.array(image)
    w = arr.shape[1]
    mid = w // 2
    search_range = int(w * config.search_ratio)

    # 每列的最大亮度值（文字列会有高亮度像素，间隔列全是暗色）
    col_max = arr.max(axis=(0, 2)) if arr.ndim == 3 else arr.max(axis=0)

    # 在搜索范围内找连续暗列区域
    start = mid - search_range
    end = mid + search_range
    region = col_max[start:end]

    # 找到亮度低于阈值的连续暗列
    threshold = arr.min() + (arr.max() - arr.min()) * config.brightness_threshold
    dark_mask = region < threshold

    if not dark_mask.any():
        logger.warning("未检测到明显的双页间隔，使用中点分割")
        return mid

    # 找最长的连续暗列区域
    dark_indices = np.where(dark_mask)[0]
    if len(dark_indices) == 0:
        return mid

    # 计算连续区域
    gaps = np.diff(dark_indices)
    split_points = np.where(gaps > 1)[0]

    if len(split_points) == 0:
        # 所有暗列连续
        gap_start = dark_indices[0]
        gap_end = dark_indices[-1]
    else:
        # 找最长的连续段
        segments = np.split(dark_indices, split_points + 1)
        longest = max(segments, key=len)
        gap_start = longest[0]
        gap_end = longest[-1]

    gap_center = start + (gap_start + gap_end) // 2
    gap_width = gap_end - gap_start + 1

    if gap_width < config.min_gap_width:
        logger.warning(
            f"检测到的间隔宽度 {gap_width}px 小于阈值 {config.min_gap_width}px，使用中点分割"
        )
        return mid

    logger.debug(f"检测到双页间隔: 列 {start + gap_start}-{start + gap_end}，中心: {gap_center}")
    return gap_center


def split_dual_page(
    image: Image.Image,
    screenshot_number: int,
    config: SplitConfig,
) -> tuple[SinglePage, SinglePage]:
    """将双页截图分割为左页和右页。

    Args:
        image: 裁剪 UI 后的双页图片
        screenshot_number: 截图序号（从 1 开始）
        config: 分割参数

    Returns:
        (左页, 右页) 元组
    """
    center = find_center_gap(image, config)
    w, h = image.size

    left_img = image.crop((0, 0, center, h))
    right_img = image.crop((center, 0, w, h))

    left_page = SinglePage(
        page_number=screenshot_number * 2 - 1,
        image=left_img,
        is_left=True,
    )
    right_page = SinglePage(
        page_number=screenshot_number * 2,
        image=right_img,
        is_left=False,
    )

    return left_page, right_page


def invert_colors(image: Image.Image) -> Image.Image:
    """将深色背景白色文字反转为白底黑字。

    Args:
        image: 深色背景图片

    Returns:
        颜色反转后的图片
    """
    return ImageOps.invert(image.convert("RGB"))


def preprocess_screenshot(
    image_data: bytes,
    screenshot_number: int,
    crop_config: CropConfig,
    split_config: SplitConfig,
) -> tuple[SinglePage, SinglePage]:
    """完整的截图预处理管道：裁剪 → 分割 → 返回双页。

    颜色反转在版面分析后按区域执行，此处不做。

    Args:
        image_data: 原始图片字节数据
        screenshot_number: 截图序号（从 1 开始）
        crop_config: UI 裁剪参数
        split_config: 双页分割参数

    Returns:
        (左页 SinglePage, 右页 SinglePage)
    """
    import io
    image = Image.open(io.BytesIO(image_data))

    # Step 1: 裁剪 UI
    cropped = crop_ui(image, crop_config)

    # Step 2: 双页分割
    left, right = split_dual_page(cropped, screenshot_number, split_config)

    return left, right
