## ADDED Requirements

### Requirement: Extract embedded images from PDF
系统 SHALL 使用 PyMuPDF 从 PDF 文件中逐页提取嵌入的图片，保持原始格式（JPEG）不做重编码。

#### Scenario: Standard WeChat Read PDF
- **WHEN** 输入一个微信读书截图生成的 PDF 文件（每页嵌入一张 JPEG 图片）
- **THEN** 系统按页码顺序提取所有嵌入图片，输出为有序的图片列表，每张图片保留原始 JPEG 数据

#### Scenario: PDF with no embedded images
- **WHEN** 输入的 PDF 某页不包含嵌入图片
- **THEN** 系统跳过该页并记录警告日志，继续处理后续页面

### Requirement: Preserve page order and metadata
系统 SHALL 为每张提取的图片记录其来源页码，确保后续处理按原书顺序进行。

#### Scenario: Multi-page PDF ordering
- **WHEN** 输入一个 183 页的 PDF
- **THEN** 输出 183 张图片，每张图片附带页码编号（1-183），顺序与 PDF 页码一致

### Requirement: Support PDF file path input
系统 SHALL 接受本地文件路径作为输入，验证文件存在且为有效 PDF。

#### Scenario: Valid PDF path
- **WHEN** 输入路径指向一个有效的 PDF 文件
- **THEN** 系统成功打开并开始提取

#### Scenario: Invalid path
- **WHEN** 输入路径不存在或文件不是有效 PDF
- **THEN** 系统报错并给出明确的错误信息
