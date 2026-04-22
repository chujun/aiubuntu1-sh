"""pdf_extractor 测试"""

import pytest
from pathlib import Path
from src.pdf_extractor import extract_pages

SAMPLE_PDF = Path("/root/ai/claudecode/wexinread/approval-books/独立宣言/独立宣言.pdf")
SAMPLE_PDF_WITH_IMAGES = Path(
    "/root/ai/claudecode/wexinread/approval-books/"
    "分布式系统架构：架构策略与难题求解/分布式系统架构：架构策略与难题求解.pdf"
)


class TestExtractPages:
    def test_extract_all_pages(self):
        """《独立宣言》应提取 11 页图片"""
        pages = extract_pages(SAMPLE_PDF)
        assert len(pages) == 11

    def test_page_order(self):
        """页码应按顺序排列"""
        pages = extract_pages(SAMPLE_PDF)
        page_numbers = [p.page_number for p in pages]
        assert page_numbers == list(range(1, 12))

    def test_image_format(self):
        """所有图片应为 JPEG 格式"""
        pages = extract_pages(SAMPLE_PDF)
        for page in pages:
            assert page.image_format == "jpeg"

    def test_image_dimensions(self):
        """微信读书 iPad 截图应为 1536x948"""
        pages = extract_pages(SAMPLE_PDF)
        for page in pages:
            assert page.width == 1536
            assert page.height == 948

    def test_image_data_not_empty(self):
        """图片数据不应为空"""
        pages = extract_pages(SAMPLE_PDF)
        for page in pages:
            assert len(page.image_data) > 0

    def test_larger_pdf(self):
        """《分布式系统架构》应提取 183 页图片"""
        if not SAMPLE_PDF_WITH_IMAGES.exists():
            pytest.skip("样本 PDF 不存在")
        pages = extract_pages(SAMPLE_PDF_WITH_IMAGES)
        assert len(pages) == 183

    def test_invalid_path(self):
        """不存在的文件应抛出 FileNotFoundError"""
        with pytest.raises(FileNotFoundError):
            extract_pages("/nonexistent/path.pdf")

    def test_non_pdf_file(self):
        """非 PDF 文件应抛出 ValueError"""
        with pytest.raises(ValueError):
            extract_pages("/etc/hostname")
