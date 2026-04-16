import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiOverlay extends StatefulWidget {
  final Offset origin;
  final VoidCallback onComplete;

  const ConfettiOverlay({
    super.key,
    required this.origin,
    required this.onComplete,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _particles = List.generate(30, (_) => _Particle(rng));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onComplete();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(
          origin: widget.origin,
          progress: _controller.value,
          particles: _particles,
        ),
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double rotationSpeed;

  static const _colors = [
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFF6BCB77),
    Color(0xFF4D96FF),
    Color(0xFFFF8E53),
    Color(0xFFA66CFF),
    Color(0xFFFF61D2),
  ];

  _Particle(Random rng)
      : angle = -pi / 2 + (rng.nextDouble() - 0.5) * pi * 0.8,
        speed = 150 + rng.nextDouble() * 200,
        size = 3 + rng.nextDouble() * 4,
        color = _colors[rng.nextInt(_colors.length)],
        rotationSpeed = rng.nextDouble() * 4 - 2;
}

class _ConfettiPainter extends CustomPainter {
  final Offset origin;
  final double progress;
  final List<_Particle> particles;

  _ConfettiPainter({
    required this.origin,
    required this.progress,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = progress;
      final gravity = 300 * t * t;
      final dx = origin.dx + cos(p.angle) * p.speed * t;
      final dy = origin.dy + sin(p.angle) * p.speed * t + gravity;
      final opacity = (1 - t).clamp(0.0, 1.0);

      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rotationSpeed * t * pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}
