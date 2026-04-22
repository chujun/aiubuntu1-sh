"""image_preprocessor 测试"""

import io
import pytest
from PIL import Image
from pathlib import Path

from src.pdf_extractor import extract_pages
from src.image_preprocessor import (
    crop_ui, find_center_gap, split_dual_page,
    invert_colors, preprocess_screenshot,
)
from src.config import CropConfig, SplitConfig

SAMPLE_PDF = Path("/root/ai/claudecode/wexinread/approval-books/独立宣言/独立宣言.pdf")


@pytest.fixture
def sample_image() -> Image.Image:
    """从样本 PDF 提取第 3 页作为测试图片"""
    pages = extract_pages(SAMPLE_PDF)
    return Image.open(io.BytesIO(pages[2].image_data))


@pytest.fixture
def crop_config() -> CropConfig:
    return CropConfig()


@pytest.fixture
def split_config() -> SplitConfig:
    return SplitConfig()


class TestCropUI:
    def test_crop_reduces_height(self, sample_image, crop_config):
        """裁剪后高度应减少 top + bottom"""
        cropped = crop_ui(sample_image, crop_config)
        expected_h = sample_image.height - crop_config.top - crop_config.bottom
        assert cropped.height == expected_h

    def test_crop_preserves_width(self, sample_image, crop_config):
        """默认配置下宽度不变"""
        cropped = crop_ui(sample_image, crop_config)
        assert cropped.width == sample_image.width

    def test_custom_crop(self, sample_image):
        """自定义裁剪参数"""
        config = CropConfig(top=50, bottom=50, left=10, right=10)
        cropped = crop_ui(sample_image, config)
        assert cropped.width == sample_image.width - 20
        assert cropped.height == sample_image.height - 100


class TestFindCenterGap:
    def test_detects_gap_near_center(self, sample_image, crop_config, split_config):
        """应在图片中心附近检测到间隔"""
        cropped = crop_ui(sample_image, crop_config)
        center = find_center_gap(cropped, split_config)
        mid = cropped.width // 2
        # 中线应在图片中心 ±15% 范围内
        assert abs(center - mid) < cropped.width * 0.15


class TestSplitDualPage:
    def test_split_produces_two_pages(self, sample_image, crop_config, split_config):
        """分割应产生左页和右页"""
        cropped = crop_ui(sample_image, crop_config)
        left, right = split_dual_page(cropped, 1, split_config)
        assert left.is_left is True
        assert right.is_left is False

    def test_page_numbers(self, sample_image, crop_config, split_config):
        """截图 N 的左页为 2N-1，右页为 2N"""
        cropped = crop_ui(sample_image, crop_config)
        left, right = split_dual_page(cropped, 3, split_config)
        assert left.page_number == 5
        assert right.page_number == 6

    def test_split_widths_reasonable(self, sample_image, crop_config, split_config):
        """左右页宽度应各约为原图一半"""
        cropped = crop_ui(sample_image, crop_config)
        left, right = split_dual_page(cropped, 1, split_config)
        total = left.image.width + right.image.width
        assert total == cropped.width
        # 每页宽度至少是总宽的 30%
        assert left.image.width > cropped.width * 0.3
        assert right.image.width > cropped.width * 0.3


class TestInvertColors:
    def test_invert_changes_brightness(self, sample_image):
        """反转后平均亮度应显著变化"""
        import numpy as np
        original_brightness = np.array(sample_image).mean()
        inverted = invert_colors(sample_image)
        inverted_brightness = np.array(inverted).mean()
        # 深色图反转后应变亮
        assert inverted_brightness > original_brightness

    def test_double_invert_restores(self, sample_image):
        """两次反转应还原"""
        import numpy as np
        inverted_once = invert_colors(sample_image)
        inverted_twice = invert_colors(inverted_once)
        original_arr = np.array(sample_image.convert("RGB"))
        restored_arr = np.array(inverted_twice)
        assert np.array_equal(original_arr, restored_arr)


class TestPreprocessScreenshot:
    def test_full_pipeline(self, crop_config, split_config):
        """完整预处理管道应返回两个单页"""
        pages = extract_pages(SAMPLE_PDF)
        left, right = preprocess_screenshot(
            pages[2].image_data, 3, crop_config, split_config
        )
        assert left.page_number == 5
        assert right.page_number == 6
        assert left.image.width > 0
        assert right.image.width > 0
