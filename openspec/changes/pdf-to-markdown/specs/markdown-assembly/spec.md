## ADDED Requirements

### Requirement: Assemble single Markdown file
系统 SHALL 将所有页面的 OCR 结果和图片引用组装为一个单独的 `book.md` 文件。

#### Scenario: Pure text book
- **WHEN** 处理一本纯文字书籍（如《独立宣言》，11 页截图）
- **THEN** 输出一个 `book.md` 文件，包含按页码顺序排列的全部文字内容

#### Scenario: Book with figures
- **WHEN** 处理一本包含插图的书籍（如《分布式系统架构》）
- **THEN** 输出 `book.md` 文件中，图片位置插入 `![图注](images/page{页码}_fig{序号}.png)` 引用

### Requirement: Title hierarchy mapping
系统 SHALL 将版面分析检测到的标题区域映射为 Markdown 标题层级（`#` / `##` / `###`）。

#### Scenario: Chapter title
- **WHEN** 检测到 h1 级别的标题区域，文字内容为"第3章 模块化"
- **THEN** 在 Markdown 中输出 `# 第3章 模块化`

#### Scenario: Section title
- **WHEN** 检测到 h2 级别的标题区域，文字内容为"3.1.1 可维护性"
- **THEN** 在 Markdown 中输出 `### 3.1.1 可维护性`

### Requirement: Paragraph concatenation
系统 SHALL 按阅读顺序拼接同一页内的文字段落，段落之间以空行分隔。

#### Scenario: Normal paragraphs
- **WHEN** 一个页面包含 3 个独立的文字区域
- **THEN** 在 Markdown 中每个段落之间插入一个空行

#### Scenario: Cross-page paragraph continuation
- **WHEN** 左页末尾文字不以句号/问号/感叹号/冒号结尾
- **THEN** 系统将左页末尾与右页开头拼接为同一段落，不插入空行

### Requirement: Insert review markers
系统 SHALL 在双引擎 OCR 结果不一致的位置插入 HTML 注释标记，供人工审核。

#### Scenario: Disagreement marker
- **WHEN** 某行文字两个引擎识别结果不同
- **THEN** 在该行文字上方插入 `<!-- REVIEW: paddle="PaddleOCR结果" surya="Surya结果" -->`

#### Scenario: Review markers are valid HTML comments
- **WHEN** Markdown 文件包含 REVIEW 标记
- **THEN** 标记为标准 HTML 注释格式，不影响 Markdown 渲染，仅在源码中可见

### Requirement: Output directory structure
系统 SHALL 在指定输出目录下创建 `{书名}/book.md` 和 `{书名}/images/` 的目录结构。

#### Scenario: Output structure
- **WHEN** 处理书籍"分布式系统架构"并指定输出目录为 `output/`
- **THEN** 生成 `output/分布式系统架构/book.md` 和 `output/分布式系统架构/images/` 目录

### Requirement: CLI interface
系统 SHALL 提供命令行接口，支持单本转换和批量转换两种模式。

#### Scenario: Single book conversion
- **WHEN** 用户执行 `python src/main.py convert /path/to/book.pdf -o output/`
- **THEN** 系统转换该 PDF 并输出到指定目录

#### Scenario: Batch conversion
- **WHEN** 用户执行 `python src/main.py batch /path/to/books/ -o output/`
- **THEN** 系统遍历目录下所有 PDF 文件，逐个转换并输出到指定目录

#### Scenario: Progress reporting
- **WHEN** 正在处理一本 183 页的书
- **THEN** 系统输出处理进度，如 `[42/183] 处理中...`
