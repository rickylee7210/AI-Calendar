# Motion Design — iOS 风格过渡动画

## 方案

纯 Flutter 内置动画，零依赖。用 SpringSimulation / CurvedAnimation 模拟 iOS spring 效果。整体节奏偏快（150-250ms）。

## 场景 1：日期切换

**当前问题**：PageView 切换时非当前页是空白，内容不跟着滑动。

**设计**：
- PageView 物理效果改为 `BouncingScrollPhysics`（iOS 回弹手感）
- 每页独立渲染自己日期的事项列表，不再只渲染当前页
- 用缓存 Map 存最近几天的数据，避免重复查询
- 滑动时卡片自然跟着 PageView 一起滑进滑出
- 空状态"暂无事项"做 fade in

## 场景 2：录音交互

**当前问题**：overlay 只有 AnimatedOpacity 淡入淡出，生硬。

**设计**：
- 长按进入录音：
  - overlay 背景 fade in 200ms
  - 底部椭圆 scale 0.8 → 1.0 弹出（spring curve，150ms）
  - 气泡 scale 0.9 + 向上偏移 10px → 正常位置（spring，200ms）
- 松手退出：整体 fade out 150ms
- 上滑进入取消区：椭圆颜色 `ColorTween` 平滑过渡到红色（150ms）
- 滑回来恢复：`ColorTween` 平滑回白色

## 场景 3：弹窗/模态

**当前问题**：SlideTransition 300ms easeOut，没有 spring 感，不支持手势下滑关闭。

**设计**：
- 创建事项弹窗：从底部 spring 弹起（先过冲 5% 再回弹，200ms），遮罩 fade in 150ms
- 日历选择器弹窗：同样 spring 弹起，起始位置更近（从 20% 处），更轻盈
- 关闭：`Curves.easeInCubic` 加速滑下，180ms
- 遮罩和弹窗同步关闭
- **新增手势下滑关闭**：手指往下拖弹窗跟着走，松手时拖了足够距离就关闭，否则 spring 弹回

## 场景 4：事项卡片

**当前问题**：新增/完成没有动画，直接刷新。

**设计**：
- 新增事项：卡片从右侧 slide in + fade in，200ms，easeOutCubic
- 勾选完成：opacity 降到 0.4 + scale 缩小到 0.98，150ms

## 动画参数规范

| 参数 | 值 |
|------|-----|
| Spring damping | 0.8 |
| Spring stiffness | 300 |
| 快速过渡 | 150ms |
| 标准过渡 | 200ms |
| 弹窗弹起 | 200ms spring |
| 弹窗关闭 | 180ms easeInCubic |
| 滚动物理 | BouncingScrollPhysics |

## 需要修改的文件

1. `lib/screens/calendar_home_screen.dart` — PageView 每页独立渲染 + 数据缓存 + 弹窗 spring + 手势下滑关闭
2. `lib/widgets/voice_overlay.dart` — 椭圆/气泡 spring 入场 + ColorTween 取消态过渡
3. `lib/widgets/todo_card.dart` — 新增入场动画 + 完成动画
4. `lib/widgets/create_item_modal.dart` — 支持手势下滑关闭
5. `lib/widgets/calendar_picker_modal.dart` — 支持手势下滑关闭
