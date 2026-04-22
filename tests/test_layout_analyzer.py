"""layout_analyzer 测试"""

import io
import tempfile
import pytest
from pathlib import Path
from PIL import Image

from src.pdf_extractor import extract_pages
from src.image_preprocessor import preprocess_screenshot, CropConfig, SplitConfig
from src.layout_analyzer import (
    Region,
    LayoutResult,
    analyze_layout,
    save_figures,
    _sort_reading_order,
)
from src.config import LayoutConfig

SAMPLE_TEXT_PDF = Path("/root/ai/claudecode/wexinread/approval-books/独立宣言/独立宣言.pdf")
SAMPLE_FIG_PDF = Path("/root/ai/claudecode/wexinread/approval-books/分布式系统架构：架构策略与难题求解/分布式系统架构：架构策略与难题求解.pdf")


@pytest.fixture(scope="module")
def layout_model():
    """共享版面检测模型实例（避免重复加载）"""
    from paddlex import create_model
    return create_model("RT-DETR-H_layout_17cls", pp_option={"run_mode": "paddle"})


@pytest.fixture(scope="module")
def text_page_image() -> Image.Image:
    """纯文字页面（独立宣言第3页左页）"""
    pages = extract_pages(SAMPLE_TEXT_PDF)
    left, _ = preprocess_screenshot(pages[2].image_data, 3, CropConfig(), SplitConfig())
    return left.image


@pytest.fixture(scope="module")
def figure_page_image() -> Image.Image:
    """含图页面（分布式系统架构第31截图左页，含架构图）"""
    pages = extract_pages(SAMPLE_FIG_PDF)
    left, _ = preprocess_screenshot(pages[30].image_data, 31, CropConfig(), SplitConfig())
    return left.image


class TestSortReadingOrder:
    def test_empty_list(self):
        assert _sort_reading_order([]) == []

    def test_vertical_order(self):
        """不同行的区域应按 y 坐标排序"""
        regions = [
            Region("text", 10, 200, 100, 250, 0.9),
            Region("text", 10, 50, 100, 100, 0.9),
            Region("text", 10, 350, 100, 400, 0.9),
        ]
        sorted_r = _sort_reading_order(regions)
        assert [r.y1 for r in sorted_r] == [50, 200, 350]

    def test_same_row_left_to_right(self):
        """同一行内按 x 坐标排序"""
        regions = [
            Region("text", 300, 50, 400, 100, 0.9),
            Region("text", 10, 55, 100, 105, 0.9),
            Region("text", 150, 52, 250, 102, 0.9),
        ]
        sorted_r = _sort_reading_order(regions)
        assert [r.x1 for r in sorted_r] == [10, 150, 300]


class TestAnalyzeLayout:
    def test_text_page_detects_regions(self, text_page_image, layout_model):
        """纯文字页面应检测到多个文字区域"""
        config = LayoutConfig()
        result = analyze_layout(text_page_image, 5, config, model=layout_model)

        assert isinstance(result, LayoutResult)
        assert result.page_number == 5
        assert len(result.text_regions) > 0

    def test_text_page_no_figures(self, text_page_image, layout_model):
        """纯文字页面不应检测到图片"""
        config = LayoutConfig()
        result = analyze_layout(text_page_image, 5, config, model=layout_model)
        assert len(result.figures) == 0

    def test_text_page_regions_ordered(self, text_page_image, layout_model):
        """区域应按 y 坐标从上到下排序"""
        config = LayoutConfig()
        result = analyze_layout(text_page_image, 5, config, model=layout_model)
        y_values = [r.y1 for r in result.regions]
        assert y_values == sorted(y_values)

    def test_figure_page_detects_image(self, figure_page_image, layout_model):
        """含图页面应检测到图片区域"""
        config = LayoutConfig()
        result = analyze_layout(figure_page_image, 61, config, model=layout_model)
        assert len(result.figures) > 0
        # 图片区域应有合理的尺寸
        for fig in result.figures:
            assert fig.image.width > 50
            assert fig.image.height > 50

    def test_figure_page_detects_title(self, figure_page_image, layout_model):
        """含图页面应检测到标题区域"""
        config = LayoutConfig()
        result = analyze_layout(figure_page_image, 61, config, model=layout_model)
        assert len(result.title_regions) > 0

    def test_region_confidence_above_threshold(self, text_page_image, layout_model):
        """所有返回的区域置信度应高于阈值"""
        config = LayoutConfig(min_confidence=0.6)
        result = analyze_layout(text_page_image, 5, config, model=layout_model)
        for r in result.regions:
            assert r.confidence >= 0.6


class TestSaveFigures:
    def test_save_creates_files(self, figure_page_image, layout_model):
        """保存图片应创建 PNG 文件"""
        config = LayoutConfig()
        result = analyze_layout(figure_page_image, 61, config, model=layout_model)

        if not result.figures:
            pytest.skip("此页面未检测到图片")

        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir) / "images"
            paths = save_figures(result.figures, 61, output_dir)

            assert len(paths) == len(result.figures)
            for p in paths:
                assert p.startswith("images/")
                full_path = Path(tmpdir) / p
                assert full_path.exists()
                # 验证是有效的图片
                img = Image.open(full_path)
                assert img.width > 0
