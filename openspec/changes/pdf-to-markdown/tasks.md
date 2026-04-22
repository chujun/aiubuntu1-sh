## 1. 项目初始化

- [x] 1.1 创建项目目录结构（src/、tests/、output/）和 `__init__.py`
- [x] 1.2 创建 `requirements.txt`，添加依赖：PyMuPDF、PaddlePaddle、PaddleOCR、paddleocr[structure]、surya-ocr、Pillow
- [x] 1.3 创建 `src/config.py`，定义预处理配置参数（UI 裁剪边距、分割容差、默认输出目录等）
- [x] 1.4 搭建 venv 虚拟环境，验证所有依赖安装成功

## 2. PDF 图片提取（pdf-extraction）

- [x] 2.1 实现 `src/pdf_extractor.py`：使用 PyMuPDF 逐页提取嵌入 JPEG 图片，返回有序图片列表及页码元数据
- [x] 2.2 处理异常情况：无嵌入图片的页面跳过并记录警告、无效 PDF 路径报错
- [x] 2.3 编写 `tests/test_pdf_extractor.py`：用《独立宣言》样本验证提取 11 页图片、页码顺序正确

## 3. 图像预处理（image-preprocessing）

- [x] 3.1 实现 `src/image_preprocessor.py` — UI 裁剪：基于配置参数裁剪顶部书名栏和底部翻页提示区域
- [x] 3.2 实现双页分割：垂直投影法检测中线位置，分割为左页和右页，输出正确的页码顺序（2N-1, 2N）
- [x] 3.3 实现颜色反转：深色背景白色文字 → 白底黑字（整页反转，图片区域在版面分析后单独处理）
- [x] 3.4 编写 `tests/test_image_preprocessor.py`：验证裁剪、分割、反转三个步骤的输出正确性
- [x] 3.5 用样本实测调优 UI 裁剪边距参数和中线检测阈值

## 4. 版面分析（layout-analysis）

- [ ] 4.1 实现 `src/layout_analyzer.py`：调用 PP-Structure 对单页图片做版面分析，返回区域列表（类型、坐标、置信度）
- [ ] 4.2 实现图片区域裁剪：根据检测到的 figure 区域坐标，从原始（未反转）页面裁剪保存为 PNG 文件
- [ ] 4.3 实现图注检测：识别图片下方紧邻的"图X-Y"格式文字作为图注
- [ ] 4.4 实现标题层级推断：根据文字区域高度比例判断 h1/h2/h3
- [ ] 4.5 实现阅读顺序排序：按 y 坐标从上到下、x 坐标从左到右排列所有区域
- [ ] 4.6 编写 `tests/test_layout_analyzer.py`：用《分布式系统架构》含图页面验证图片检测和区域分类

## 5. 双引擎 OCR（dual-ocr）

- [ ] 5.1 实现 `src/ocr_engine.py` — PaddleOCR 封装：调用 PP-OCRv4 对文字区域做识别，返回逐行文本及坐标
- [ ] 5.2 实现 `src/ocr_engine.py` — Surya 封装：调用 Surya OCR 对相同区域做识别，返回逐行文本及坐标
- [ ] 5.3 实现 `src/cross_validator.py`：按 y 坐标重叠度对齐两引擎结果，逐行 diff 比对
- [ ] 5.4 实现差异标记：不一致行默认采用 PaddleOCR 结果，插入 `<!-- REVIEW: paddle="X" surya="Y" -->` 注释
- [ ] 5.5 实现校验摘要输出：总行数、一致行数、差异行数、差异率
- [ ] 5.6 编写 `tests/test_ocr_engine.py` 和 `tests/test_cross_validator.py`：验证单引擎识别和交叉校验逻辑

## 6. Markdown 组装（markdown-assembly）

- [ ] 6.1 实现 `src/markdown_assembler.py`：按页码顺序拼接 OCR 文本，段落间插入空行
- [ ] 6.2 实现标题映射：将版面分析的标题区域转为 `#`/`##`/`###` Markdown 标题
- [ ] 6.3 实现图片引用插入：在图片区域位置插入 `![图注](images/pageXXX_figYY.png)`
- [ ] 6.4 实现跨页段落拼接：检测左页末尾标点，非句末标点时与右页开头合并为同一段落
- [ ] 6.5 实现审核标记插入：将 cross_validator 的差异标记嵌入 Markdown 文本
- [ ] 6.6 实现输出目录结构：创建 `{书名}/book.md` + `{书名}/images/` 目录
- [ ] 6.7 编写 `tests/test_markdown_assembler.py`：验证段落拼接、标题映射、图片引用格式

## 7. CLI 入口与集成

- [ ] 7.1 实现 `src/main.py`：argparse CLI，支持 `convert` 单本和 `batch` 批量两种子命令
- [ ] 7.2 实现处理进度输出：`[N/M] 处理中...` 格式的进度报告
- [ ] 7.3 串联完整管道：PDF提取 → 预处理 → 版面分析 → 双引擎OCR → 交叉校验 → Markdown组装
- [ ] 7.4 用《独立宣言》（纯文字，11页）做端到端验证，检查输出 Markdown 完整性
- [ ] 7.5 用《分布式系统架构》（含图，183页）做端到端验证，检查图片提取和引用正确性

## 8. 调优与收尾

- [ ] 8.1 对比两本样本书的 OCR 输出与原文，统计准确率和差异率
- [ ] 8.2 根据实测结果调优：UI 裁剪参数、中线检测阈值、标题高度比例阈值、行对齐容差
- [ ] 8.3 处理边界情况：版权页、目录页、空白页的识别和标记
- [ ] 8.4 编写 README.md：安装说明、使用方法、配置参数说明
