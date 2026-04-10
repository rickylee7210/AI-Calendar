# 语音输入功能设计文档

## 概述

实现点击语音 icon 后的完整语音交互流程：录音 → ASR 转文字 → NLU 意图解析 → 创建待办/日程。

## 交互流程

### 状态 1：录音中（设计稿 959:27210）

用户点击底部语音按钮后：
- 底部升起渐变光晕背景（两个椭圆径向渐变叠加）
- 中间白色文字显示识别内容（如"提醒我晚上吃药"）
- 底部音频波形可视化（~50根竖条，宽2.4px，间距2px，白色，高度随音量变化）
- 日历头部保持可见

### 状态 2：卡片确认（设计稿 966:5639）

NLU 解析完成后：
- 保持光晕背景 + 波形 + 识别文字
- 毛玻璃卡片滑入（圆角20px，278×70）：
  - 标题：事项名称（17px MiSans Medium）
  - 副标题：时间信息（14px MiSans Regular，60%透明度）
- 卡片上方提示："已为你创建好提醒事项，要添加吗？"（15px，50%透明度）
- "添加"按钮（66×38，圆角100px，毛玻璃，蓝色文字 #3482FF）

### 完整流程

1. 点击语音 icon → 进入录音状态
2. 说话 → 波形动画
3. 再次点击 / 自动停止 → ASR 转文字
4. NLU 解析意图 → 卡片确认状态
5. 点击"添加" → 保存事项，返回首页
6. 点击空白区域 → 取消，返回首页

## 技术方案

### 架构：两步走（ASR + NLU 分离）

```
录音(record包) → 智谱 ASR(转文字) → 智谱 NLU(意图解析) → 创建事项
```

保持现有 `IAsrService` / `INluService` 接口不变。

### 需要实现的模块

1. **RealAudioRecorderService** — 替换 MockAudioRecorderService
   - 使用 `record` 包（已在 pubspec.yaml）
   - 实现 `IAudioRecorder` 接口
   - 提供振幅流用于波形可视化

2. **ZhipuAsrService** — 替换 MockAsrService
   - 调用智谱 `audio/transcriptions` 接口
   - 实现 `IAsrService` 接口
   - 复用现有智谱 API Key

3. **VoiceOverlayWidget** — 新增录音态 UI
   - 渐变光晕背景（RadialGradient）
   - 音频波形可视化（CustomPaint）
   - 识别文字展示
   - 毛玻璃结果卡片 + "添加"按钮

4. **main.dart 更新** — Mock → 真实实现

### 视觉规格

- 光晕背景：两个椭圆径向渐变叠加，覆盖屏幕下半部分
- 波形条：宽2.4px，圆角4.446px，间距2px，白色渐变填充
- 毛玻璃卡片：BackdropFilter blur 20px，圆角20px，内阴影
- 添加按钮：BackdropFilter blur 20px，圆角100px，文字 #3482FF
- 字体：MiSans 全局
