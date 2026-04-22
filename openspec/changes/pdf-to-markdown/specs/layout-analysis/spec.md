## ADDED Requirements

### Requirement: Detect page layout regions
系统 SHALL 使用 PaddleOCR PP-Structure 对每个单页图片进行版面分析，识别并分类页面中的不同区域。

#### Scenario: Page with text only
- **WHEN** 输入一个纯文字页面
- **THEN** 系统识别出文字区域和标题区域，返回每个区域的类型、边界坐标和置信度

#### Scenario: Page with embedded figure
- **WHEN** 输入一个包含架构图/流程图的页面
- **THEN** 系统将图片区域与文字区域分开标识，图片区域返回类型为 "figure"，附带边界坐标

#### Scenario: Page with table
- **WHEN** 输入一个包含表格的页面
- **THEN** 系统将表格区域标识为 "table" 类型，与普通文字区域区分

### Requirement: Extract figure regions as images
系统 SHALL 根据版面分析检测到的图片区域坐标，从原始页面图片中裁剪并保存为独立的 PNG 文件。

#### Scenario: Single figure on page
- **WHEN** 版面分析检测到页面中有一个图片区域
- **THEN** 系统按坐标裁剪该区域，保存为 `images/page{页码}_fig{序号}.png`

#### Scenario: Multiple figures on page
- **WHEN** 版面分析检测到页面中有多个图片区域
- **THEN** 系统分别裁剪保存，按从上到下的顺序编号

#### Scenario: Figure with caption detection
- **WHEN** 图片区域下方紧邻一个文字区域，内容匹配"图X-Y"模式
- **THEN** 系统将该文字识别为图注，与图片关联，用作 Markdown 的 alt text

### Requirement: Classify title regions
系统 SHALL 识别标题区域并推断其层级（h1/h2/h3），基于文字区域的高度比例与位置特征。

#### Scenario: Chapter title detection
- **WHEN** 页面中有一个文字区域的字体高度明显大于正文（>1.5倍）
- **THEN** 系统将其标记为标题区域，推断为 h1 或 h2 层级

#### Scenario: Section title detection
- **WHEN** 页面中有一个文字区域的字体高度略大于正文（1.2-1.5倍）
- **THEN** 系统将其标记为小节标题，推断为 h3 层级

### Requirement: Return regions in reading order
系统 SHALL 按阅读顺序（从上到下、从左到右）排列所有检测到的区域。

#### Scenario: Mixed content page
- **WHEN** 页面包含标题、文字段落、图片等混合内容
- **THEN** 返回的区域列表按 y 坐标从小到大排序，同一行内按 x 坐标排序
