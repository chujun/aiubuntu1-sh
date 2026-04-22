## ADDED Requirements

### Requirement: PaddleOCR text recognition
系统 SHALL 使用 PaddleOCR PP-OCRv4 对文字区域进行文本识别，返回逐行文本及其坐标位置。

#### Scenario: Chinese text recognition
- **WHEN** 输入一个包含中文正文的页面图片
- **THEN** PaddleOCR 返回逐行识别结果，每行包含文本内容、边界坐标和置信度分数

#### Scenario: Mixed Chinese-English text
- **WHEN** 输入一个中英文混排的页面（如《独立宣言》英文原文附录）
- **THEN** PaddleOCR 正确识别中英文混合内容，不丢失英文单词

### Requirement: Surya text recognition
系统 SHALL 使用 Surya OCR 对相同的文字区域进行独立文本识别，作为交叉校验的第二引擎。

#### Scenario: Surya Chinese text recognition
- **WHEN** 输入与 PaddleOCR 相同的页面图片
- **THEN** Surya 返回逐行识别结果，包含文本内容和坐标位置

### Requirement: Cross-validation by line diff
系统 SHALL 对两个引擎的识别结果进行逐行对齐和比对，标记差异位置。

#### Scenario: Both engines agree
- **WHEN** PaddleOCR 和 Surya 对某行文字的识别结果完全一致
- **THEN** 该行直接采信，标记为高置信度

#### Scenario: Engines disagree
- **WHEN** PaddleOCR 识别为 "Equifax数据泄露事件"，Surya 识别为 "Equitax数据泄露事件"
- **THEN** 系统默认采用 PaddleOCR 结果，同时插入审核标记 `<!-- REVIEW: paddle="Equifax" surya="Equitax" -->`

#### Scenario: Line alignment with tolerance
- **WHEN** 两个引擎的文本行切分粒度不同（如 PaddleOCR 切为 2 行，Surya 切为 3 行）
- **THEN** 系统按 y 坐标重叠度进行模糊匹配，将对应区域的文本拼接后做全文 diff

### Requirement: Output validation summary
系统 SHALL 在处理完成后输出校验摘要，包括总行数、一致行数、差异行数和差异率。

#### Scenario: Validation report
- **WHEN** 一本书处理完成
- **THEN** 系统输出摘要：总行数 N，一致 M 行（X%），差异 K 行（Y%），并列出所有差异位置的页码和行号
