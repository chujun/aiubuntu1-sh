## ADDED Requirements

### Requirement: Crop WeChat Read UI elements
系统 SHALL 裁剪微信读书截图中的 UI 元素，包括顶部书名栏和底部翻页提示区域，仅保留正文内容区域。

#### Scenario: Standard iPad landscape screenshot
- **WHEN** 输入一张 1536x948 的微信读书 iPad 横屏截图
- **THEN** 系统裁剪掉顶部书名区域和底部"< 上一页 / 下一页 >"区域，输出仅含正文的图片

#### Scenario: Configurable crop margins
- **WHEN** 用户通过配置参数指定自定义裁剪边距（top, bottom）
- **THEN** 系统使用用户指定的像素值进行裁剪，覆盖默认值

### Requirement: Split dual-page into left and right pages
系统 SHALL 将双页截图沿中线分割为独立的左页和右页图片。

#### Scenario: Standard dual-page with visible gap
- **WHEN** 输入一张含左右两页的截图，中间有明显的深色间距
- **THEN** 系统通过垂直投影检测中线位置，分割为左页和右页两张独立图片

#### Scenario: Split produces correct page order
- **WHEN** 第 N 张截图被分割
- **THEN** 输出顺序为：第 N 张截图的左页（页码 2N-1）、第 N 张截图的右页（页码 2N）

#### Scenario: First page special handling
- **WHEN** 第一张截图的左页为版权信息页
- **THEN** 系统仍然正常分割和处理，版权页内容作为 Markdown 的开头部分

### Requirement: Invert dark background to light
系统 SHALL 将深色背景白色文字的图片反转为白色背景黑色文字，以提升 OCR 识别率。

#### Scenario: Dark mode screenshot inversion
- **WHEN** 输入一张深色背景、浅色文字的微信读书截图
- **THEN** 系统对颜色进行反转，输出白底黑字的图片

#### Scenario: Inversion applies only to text regions
- **WHEN** 页面包含图片区域（如架构图）
- **THEN** 系统仅对文字区域执行反转，图片区域保持原始颜色用于裁剪保存
