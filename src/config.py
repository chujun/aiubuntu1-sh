"""预处理配置参数"""

from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class CropConfig:
    """微信读书 UI 裁剪参数（像素值）"""
    top: int = 40       # 顶部书名栏高度（实测行0-39为UI区域）
    bottom: int = 34    # 底部翻页提示高度（实测行914后为UI区域，948-914=34）
    left: int = 0       # 左侧边距
    right: int = 0      # 右侧边距


@dataclass(frozen=True)
class SplitConfig:
    """双页分割参数"""
    search_ratio: float = 0.1      # 在中心 ±10% 范围内搜索中线
    min_gap_width: int = 10        # 最小间隔宽度（像素）
    brightness_threshold: float = 0.15  # 亮度谷值阈值（归一化）


@dataclass(frozen=True)
class LayoutConfig:
    """版面分析参数"""
    model_name: str = "RT-DETR-H_layout_17cls"  # 版面检测模型
    min_confidence: float = 0.5          # 最低置信度阈值
    caption_pattern: str = r"图\s*\d+[-—]\d+"  # 图注匹配模式
    caption_max_distance: int = 50       # 图注与图片的最大距离（像素）
    figure_labels: tuple = ("image", "figure")  # 图片区域标签
    title_labels: tuple = ("paragraph_title", "doc_title", "section_title")  # 标题标签
    header_labels: tuple = ("header", "footer", "page_number")  # 页眉页脚标签


@dataclass(frozen=True)
class OcrConfig:
    """OCR 引擎参数"""
    paddle_lang: str = "ch"         # PaddleOCR 语言
    paddle_det_model: str = "PP-OCRv5_mobile_det"  # 检测模型（mobile 更快）
    paddle_rec_model: str = "PP-OCRv5_mobile_rec"  # 识别模型
    surya_langs: tuple = ("zh", "en")  # Surya 语言
    line_overlap_threshold: float = 0.5  # 行对齐 y 坐标重叠度阈值


@dataclass(frozen=True)
class OutputConfig:
    """输出配置"""
    default_output_dir: Path = Path("output")
    image_format: str = "png"
    image_prefix: str = "page"


@dataclass(frozen=True)
class AppConfig:
    """应用总配置"""
    crop: CropConfig = field(default_factory=CropConfig)
    split: SplitConfig = field(default_factory=SplitConfig)
    layout: LayoutConfig = field(default_factory=LayoutConfig)
    ocr: OcrConfig = field(default_factory=OcrConfig)
    output: OutputConfig = field(default_factory=OutputConfig)
