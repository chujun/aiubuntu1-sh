## Why

微信读书截图生成的 PDF 电子书（每页为图片，无文字层）无法直接搜索、编辑或引用。需要一个本地工具将这类 PDF 转换为 Markdown 格式的电子书，要求文字一字不改地还原，书中嵌入的插图裁剪保存并以图片链接引用。当前有 10+ 本书待处理，且为持续使用场景，要求零 API 成本（纯本地运行）。

## What Changes

- 新建 Python CLI 工具，接受 PDF 文件路径，输出单个 `book.md` + `images/` 目录
- 使用 PyMuPDF 从 PDF 中直接提取嵌入的 JPEG 图片（无损）
- 图像预处理：裁剪微信读书 UI 元素（顶部书名、底部翻页提示）、双页分割为左右单页、深色反转为白底黑字
- 使用 PaddleOCR PP-Structure 进行版面分析，区分文字区域、标题区域、图片区域、表格区域
- 图片区域裁剪保存为独立 PNG 文件，Markdown 中以 `![图注](images/xxx.png)` 引用
- 双引擎 OCR 交叉校验：PaddleOCR PP-OCRv4 + Surya，两者结果一致则采信，不一致则标记 `<!-- REVIEW -->` 供人工审核
- 支持单本转换和批量转换模式
- 输出为单个 `book.md` 文件

## Capabilities

### New Capabilities

- `pdf-extraction`: PDF 文件解析与逐页图片提取（PyMuPDF）
- `image-preprocessing`: 微信读书截图预处理——UI 裁剪、双页分割、颜色反转
- `layout-analysis`: 版面分析——区分文字、标题、图片、表格区域（PP-Structure）
- `dual-ocr`: 双引擎 OCR 识别与交叉校验（PaddleOCR + Surya），差异标记机制
- `markdown-assembly`: Markdown 文件组装——段落拼接、标题层级、图片引用、审核标记

### Modified Capabilities

（无已有能力需要修改，这是全新项目）

## Impact

- **依赖**: PyMuPDF, PaddlePaddle, PaddleOCR, Surya, Pillow
- **运行环境**: 本地 Python 3.10+，推荐 GPU（PaddleOCR/Surya 加速），CPU 亦可运行
- **存储**: 每本书约 50-200MB 原始图片（处理过程中临时），最终输出 Markdown + 提取的插图
- **输入格式**: 微信读书 iPad 横屏双页截图生成的 PDF（1536x948 JPEG，深色模式）
- **输出格式**: 单个 `book.md` + `images/` 目录
