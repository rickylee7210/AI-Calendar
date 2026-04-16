import 'package:flutter/services.dart';

/// 轻触反馈（按钮、checkbox、列表项点击）
void hapticTap() => HapticFeedback.lightImpact();

/// 重触反馈（完成任务、长按）
void hapticHeavy() => HapticFeedback.mediumImpact();
