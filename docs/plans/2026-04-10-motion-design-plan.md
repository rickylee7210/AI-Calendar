# Motion Design 实现计划 — iOS 风格过渡动画

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 AI 日历应用添加 iOS 风格的 spring 过渡动画，覆盖日期切换、录音交互、弹窗模态、事项卡片四个场景。

**Architecture:** 纯 Flutter 内置动画，零依赖。用 `Curves.easeOutBack`（模拟 spring 过冲回弹）、`BouncingScrollPhysics`（iOS 回弹）、`AnimationController` + `Tween` 组合实现。

**Tech Stack:** Flutter AnimationController, CurvedAnimation, Tween, BouncingScrollPhysics, GestureDetector

---

### Task 1: 日期切换 — PageView 每页独立渲染 + iOS 回弹

**Files:**
- Modify: `lib/screens/calendar_home_screen.dart`

**Step 1:** 将 `_calendarItems` / `_loading` 替换为 `Map<String, List<CalendarItem>> _itemsCache`

**Step 2:** 新增 `_loadItemsForDate(DateTime)` 方法，按日期 key 缓存查询结果

**Step 3:** `_loadItems()` 改为清除当前日期缓存 + setState 触发重建

**Step 4:** PageView 加 `physics: BouncingScrollPhysics()`，`itemBuilder` 中每页用 `FutureBuilder` 独立加载渲染

**Step 5:** 删除旧的 `_buildTodoList` 方法

**Step 6:** `flutter analyze` 验证，提交

---

### Task 2: 录音交互 — spring 入场 + ColorTween 取消过渡

**Files:**
- Modify: `lib/widgets/voice_overlay.dart`

**Step 1:** 添加 `_springCtl` AnimationController (250ms)，驱动椭圆 scale 0.8→1.0 和气泡 scale 0.9→1.0 + offset(0,10)→(0,0)，curve 用 `Curves.easeOutBack`

**Step 2:** 椭圆用 `ScaleTransition` 包裹

**Step 3:** 气泡用 `AnimatedBuilder` 包裹，组合 scale + translate

**Step 4:** 添加 `_cancelCtl` AnimationController (150ms)，`didUpdateWidget` 中根据 `inCancelZone` 变化 forward/reverse

**Step 5:** `_EllipsePainter` 的 `isCancel` bool 改为 `cancelProgress` double，用 `Color.lerp` 插值白色→红色

**Step 6:** `flutter analyze` 验证，提交

---

### Task 3: 弹窗 — spring 弹起 + 手势下滑关闭

**Files:**
- Modify: `lib/screens/calendar_home_screen.dart`

**Step 1:** 创建 `_DraggableSheet` StatefulWidget — 跟踪 `_dragOffset`，`onVerticalDragUpdate` 更新偏移，`onVerticalDragEnd` 判断是否关闭（>100px 或速度 >500）否则弹回

**Step 2:** 创建 `_showSpringSheet` 通用方法 — `showGeneralDialog` + `Curves.easeOutBack` 弹起 + `Curves.easeInCubic` 关闭 + 遮罩 FadeTransition + 内容 SlideTransition + `_DraggableSheet` 包裹

**Step 3:** `_showCreateItem` 改用 `_showSpringSheet`，topOffset=100

**Step 4:** `_showCalendarPicker` 改用 `_showSpringSheet`，topOffset 靠近底部

**Step 5:** `flutter analyze` 验证，提交

---

### Task 4: 事项卡片 — 新增入场 + 完成动画

**Files:**
- Modify: `lib/widgets/todo_card.dart`
- Modify: `lib/screens/calendar_home_screen.dart` (`_ScheduleCard`)

**Step 1:** `TodoCard` 改为 StatefulWidget，`initState` 中创建 `_entryCtl` (200ms)，驱动 FadeTransition + SlideTransition(0.3,0)→(0,0)

**Step 2:** 外层包裹 `AnimatedOpacity`(150ms) + `AnimatedScale`(150ms)，根据 `isCompleted` 切换 opacity 0.4/1.0 和 scale 0.98/1.0

**Step 3:** `_ScheduleCard` 同样外层包裹 `AnimatedOpacity` + `AnimatedScale`

**Step 4:** `flutter analyze` 验证，提交

---

### Task 真机验证 + 最终提交

**Step 1:** `flutter build apk --debug --dart-define-from-file=.env && adb install -r`

**Step 2:** 验证清单：
- 左右滑动切天：卡片跟着滑，有 iOS 回弹
- 长按录音：椭圆 spring 弹出，气泡从下方滑入
- 上滑取消：椭圆颜色平滑过渡到红色，滑回来恢复
- 松手退出：快速 fade out
- 创建事项弹窗：spring 弹起，手指下滑可关闭
- 日历选择器：同上
- 新增事项：卡片从右侧 slide in
- 勾选完成：opacity + scale 平滑过渡

**Step 3:** `git push origin main`
