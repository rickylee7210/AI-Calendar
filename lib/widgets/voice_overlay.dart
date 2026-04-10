import 'dart:async';
import 'package:flutter/material.dart';

class VoiceOverlay extends StatefulWidget {
  final Stream<double> amplitudeStream;
  final bool inCancelZone;
  final String hintText;
  final bool isProcessing;

  const VoiceOverlay({
    super.key,
    required this.amplitudeStream,
    this.inCancelZone = false,
    this.hintText = '正在聆听...',
    this.isProcessing = false,
  });

  @override
  State<VoiceOverlay> createState() => _VoiceOverlayState();
}

class _VoiceOverlayState extends State<VoiceOverlay>
    with TickerProviderStateMixin {
  StreamSubscription<double>? _ampSub;
  double _currentAmp = 0.0;
  late AnimationController _fadeCtl;

  @override
  void initState() {
    super.initState();
    _fadeCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _ampSub = widget.amplitudeStream.listen((amp) {
      setState(() => _currentAmp = amp.clamp(0.0, 1.0));
    });
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _fadeCtl.dispose();
    super.dispose();
  }

  /// Figma 基准宽度 392，按屏幕等比缩放
  double _s(double v) => v * MediaQuery.of(context).size.width / 392;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isCancel = widget.inCancelZone;

    // Figma 尺寸（全部走 _s 缩放）
    final ellipseW = _s(471);
    final ellipseH = _s(234);
    final bubbleW = _s(336);
    final bubbleH = _s(74);
    final bubbleLeft = _s(28);

    // Figma 定位换算（从屏幕底部算起）:
    // BottomBar 高 142，椭圆 top=-17 → 椭圆顶距底 142+17=159
    // 椭圆高 234 → 底部超出屏幕 234-159=75
    // 气泡 top=-119 → 气泡顶距底 142+119=261，气泡高 74 → bottom=261-74=187
    // 提示文字 top=10 within BottomBar → 距底 142-10=132，文字高≈19 → bottom≈113
    final ellipseBottom = -_s(75);
    final bubbleBottom = _s(187);
    final hintBottom = _s(113);

    return FadeTransition(
      opacity: CurvedAnimation(parent: _fadeCtl, curve: Curves.easeOut),
      child: IgnorePointer(
        child: SizedBox.expand(
          child: Stack(
            children: [
              // ① 全屏渐变遮罩 — 模态效果
              // Figma: rgba(243,243,243,0) @2.6% → 0.94 @41.6% → 1.0 @100%
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: const [
                        Color(0x00F3F3F3),
                        Color(0xF0F3F3F3),
                        Color(0xFFF3F3F3),
                      ],
                      stops: const [0.026, 0.416, 1.0],
                    ),
                  ),
            ),
              ),

              // ② 白色椭圆（正常态）/ 红色椭圆（取消态）— 静态，无呼吸动画
              Positioned(
                bottom: ellipseBottom,
                left: (screenW - ellipseW) / 2,
                width: ellipseW,
                height: ellipseH,
                child: CustomPaint(
                  painter: _EllipsePainter(isCancel: isCancel),
                  size: Size.infinite,
                ),
              ),

              // ③ 提示文字
              Positioned(
                left: 0,
                right: 0,
                bottom: hintBottom,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      isCancel
                          ? '取消录音'
                          : widget.isProcessing
                              ? '处理中...'
                              : '松手完成录音，上滑取消',
                      key: ValueKey('$isCancel-${widget.isProcessing}'),
                      style: TextStyle(
                        fontFamily: 'MiSans',
                        fontSize: _s(14),
                        fontWeight: FontWeight.w500,
                        color: isCancel
                            ? const Color(0xFFFA382E)
                            : const Color(0xCC000000),
                      ),
                    ),
                  ),
                ),
              ),

              // ④ 白色气泡
              // Figma: Union 336×74, 白色圆角矩形 + 底部居中弧形尾巴
              Positioned(
                left: bubbleLeft,
                bottom: bubbleBottom,
                child: SizedBox(
                  width: bubbleW,
                  height: bubbleH,
                  child: CustomPaint(
                    painter: _BubblePainter(),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: _s(14),
                        right: _s(14),
                        bottom: _s(13), // 尾巴高度
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                   '"${widget.hintText}"',
                       style: TextStyle(
                            fontFamily: 'MiSans',
                            fontSize: _s(16),
                            fontWeight: FontWeight.w500,
                            color: const Color(0xDE000000), // 87% opacity
                            height: 1.0,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 白色/红色渐变椭圆 — 还原 Figma SVG
// 正常态: 白色线性渐变填充(56%→0%) + 白色渐变描边
// 取消态: 红色渐变
// ---------------------------------------------------------------------------
class _EllipsePainter extends CustomPainter {
  final bool isCancel;
  _EllipsePainter({required this.isCancel});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (isCancel) {
      // 取消态：红色渐变椭圆
      final fillGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0x8FFA382E), // 56% red
          Color(0x00FA382E), // 0% red
        ],
      );
      canvas.drawOval(rect, Paint()..shader = fillGradient.createShader(rect));

      final strokeGradient = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0x1AFA382E),
          Color(0xFFFA382E),
          Color(0x59FA382E),
        ],
        stops: const [0.0, 0.51, 1.0],
      );
      canvas.drawOval(
        rect.deflate(1),
        Paint()
          ..shader = strokeGradient.createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    } else {
      // 正常态：白色渐变椭圆（精确还原 Figma SVG）
      // fill: white 56% → white 0%, top → y=149/234 ≈ 63.7%
      final fillGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: const Alignment(0, 0.274), // 149/234 mapped to -1..1
        colors: const [
          Color(0x8FFFFFFF), // white 56%
          Color(0x00FFFFFF), // white 0%
        ],
      );
      canvas.drawOval(rect, Paint()..shader = fillGradient.createShader(rect));

      // stroke: white 10% → white 100% → white 35%
      final strokeGradient = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0x1AFFFFFF), // 10%
          Color(0xFFFFFFFF), // 100%
          Color(0x59FFFFFF), // 35%
        ],
        stops: const [0.0, 0.51, 1.0],
      );
      canvas.drawOval(
        rect.deflate(1),
        Paint()
          ..shader = strokeGradient.createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EllipsePainter old) => old.isCancel != isCancel;
}

// ---------------------------------------------------------------------------
// 白色气泡 — 还原 Figma Union SVG
// 圆角矩形(336×60, radius≈26) + 底部居中弧形尾巴(宽≈50, 高≈13)
// ---------------------------------------------------------------------------
class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 主体占大部分高度，尾巴固定 8px 锐角三角
    const tailH = 8.0;
    const tailHalfW = 6.0; // 窄三角 = 锐角

    final bodyH = size.height - tailH;
    final radius = size.width * (25.6 / 336.0);
    final tailCenterX = size.width * (168.0 / 336.0);

    final path = Path();

    // 主体圆角矩形
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, bodyH),
      Radius.circular(radius),
    ));

    // 底部锐角三角 — lineTo 直线，不用贝塞尔曲线
    final tailPath = Path()
      ..moveTo(tailCenterX - tailHalfW, bodyH)
      ..lineTo(tailCenterX, bodyH + tailH)
      ..lineTo(tailCenterX + tailHalfW, bodyH)
      ..close();
    path.addPath(tailPath, Offset.zero);

    // 阴影
    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      Paint()
        ..color = const Color(0x14000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // 白色填充
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
