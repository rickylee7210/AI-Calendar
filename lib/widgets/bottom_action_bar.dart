import 'package:flutter/material.dart';
import '../theme/app_icons.dart';
import '../utils/haptic.dart';

class BottomActionBar extends StatelessWidget {
  final VoidCallback onKeyboardTap;
  final VoidCallback? onVoiceTap;
  final VoidCallback? onVoiceLongPressStart;
  final VoidCallback? onVoiceLongPressEnd;
  final void Function(double)? onVoiceLongPressMoveUpdate;
  final VoidCallback onCalendarTap;
  final bool showBackToToday;

  const BottomActionBar({
    super.key,
    required this.onKeyboardTap,
    this.onVoiceTap,
    this.onVoiceLongPressStart,
    this.onVoiceLongPressEnd,
    this.onVoiceLongPressMoveUpdate,
    required this.onCalendarTap,
    this.showBackToToday = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Keyboard — HyperOS Medium 18.75px
            _GlassButton(
              key: const Key('btn-keyboard'),
              codePoint: AppIcons.keyboard.codePoint,
              fontSize: 18.75,
              fontWeight: FontWeight.w500,
              size: 50,
              onTap: onKeyboardTap,
            ),
            // Voice — HyperOS Medium 21px, wide pill (长按录音)
            _GlassButton(
              key: const Key('btn-voice'),
              codePoint: AppIcons.mic.codePoint,
              fontSize: 21,
              fontWeight: FontWeight.w500,
              width: 140,
              height: 50,
              onTap: onVoiceTap,
              onLongPressStart: onVoiceLongPressStart,
              onLongPressEnd: onVoiceLongPressEnd,
              onLongPressMoveUpdate: onVoiceLongPressMoveUpdate,
            ),
            // Calendar or Back-to-today — HyperOS Medium 21px
            _GlassButton(
              key: const Key('btn-calendar'),
              codePoint: showBackToToday
                  ? AppIcons.backToday.codePoint
                  : AppIcons.calendar.codePoint,
              fontSize: 21,
              fontWeight: FontWeight.w500,
              size: 50,
              onTap: onCalendarTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassButton extends StatefulWidget {
  final int codePoint;
  final double fontSize;
  final FontWeight fontWeight;
  final double? size;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final void Function(double)? onLongPressMoveUpdate;

  const _GlassButton({
    super.key,
    required this.codePoint,
    required this.fontSize,
    required this.fontWeight,
    this.size,
    this.width,
    this.height,
    this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onLongPressMoveUpdate,
  });

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  double _startY = 0;

  @override
  Widget build(BuildContext context) {
    final w = widget.width ?? widget.size ?? 50;
    final h = widget.height ?? widget.size ?? 50;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        hapticTap();
        widget.onTap?.call();
      },
      onLongPressStart: widget.onLongPressStart != null
          ? (details) {
              hapticHeavy();
              _startY = details.globalPosition.dy;
              widget.onLongPressStart!();
            }
          : null,
      onLongPressMoveUpdate: widget.onLongPressMoveUpdate != null
          ? (details) {
              final delta = details.globalPosition.dy - _startY;
              widget.onLongPressMoveUpdate!(delta);
            }
          : null,
      onLongPressEnd: widget.onLongPressEnd != null
          ? (_) => widget.onLongPressEnd!()
          : null,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(89.286),
          color: Colors.white.withValues(alpha: 0.65),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 53.571,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 71.429,
              offset: const Offset(0, 32.143),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 0.893,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          String.fromCharCode(widget.codePoint),
          style: TextStyle(
            fontFamily: 'HyperOS Symbols',
            fontSize: widget.fontSize,
            fontWeight: widget.fontWeight,
            color: Colors.black,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
