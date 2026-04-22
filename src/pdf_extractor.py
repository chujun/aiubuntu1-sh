"""PDF 文件解析与逐页图片提取"""

import logging
from dataclasses import dataclass
from pathlib import Path

import fitz  # PyMuPDF

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class ExtractedPage:
    """提取的单页图片数据"""
    page_number: int        # PDF 页码（从 1 开始）
    image_data: bytes       # 原始图片字节数据
    image_format: str       # 图片格式（如 "jpeg"）
    width: int
    height: int


def extract_pages(pdf_path: str | Path) -> list[ExtractedPage]:
    """从 PDF 中逐页提取嵌入的图片。

    Args:
        pdf_path: PDF 文件路径

    Returns:
        按页码排序的 ExtractedPage 列表

    Raises:
        FileNotFoundError: PDF 文件不存在
        ValueError: 文件不是有效的 PDF
    """
    pdf_path = Path(pdf_path)

    if not pdf_path.exists():
        raise FileNotFoundError(f"PDF 文件不存在: {pdf_path}")

    if not pdf_path.suffix.lower() == ".pdf":
        raise ValueError(f"不是 PDF 文件: {pdf_path}")

    try:
        doc = fitz.open(str(pdf_path))
    except Exception as e:
        raise ValueError(f"无法打开 PDF 文件: {pdf_path} — {e}") from e

    pages: list[ExtractedPage] = []

    try:
        for page_idx in range(doc.page_count):
            page = doc[page_idx]
            images = page.get_images(full=True)

            if not images:
                logger.warning(f"第 {page_idx + 1} 页无嵌入图片，跳过")
                continue

            # 微信读书 PDF 每页恰好一张图片，取第一张
            xref = images[0][0]
            base_image = doc.extract_image(xref)

            pages.append(ExtractedPage(
                page_number=page_idx + 1,
                image_data=base_image["image"],
                image_format=base_image["ext"],
                width=base_image["width"],
                height=base_image["height"],
            ))

            if len(images) > 1:
                logger.warning(
                    f"第 {page_idx + 1} 页有 {len(images)} 张图片，仅提取第一张"
                )
    finally:
        doc.close()

    logger.info(f"从 {pdf_path.name} 提取了 {len(pages)} 页图片")
    return pages
