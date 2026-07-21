import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// A brief, non-blocking confetti burst for the "all packed" moment.
/// Inserted as an overlay, ignores pointers, removes itself after ~1.3s.
void showCelebration(BuildContext context) {
  final overlay = Overlay.of(context);
  final h = context.harbor;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: _ConfettiBurst(
        colors: [h.accent, h.good, const Color(0xFFE9B949)],
        onDone: () => entry.remove(),
      ),
    ),
  );
  overlay.insert(entry);
}

class _ConfettiBurst extends StatefulWidget {
  const _ConfettiBurst({required this.colors, required this.onDone});

  final List<Color> colors;
  final VoidCallback onDone;

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Particle {
  _Particle(Random rnd, List<Color> colors)
      : angle = -pi / 2 + (rnd.nextDouble() - 0.5) * pi * 0.9,
        speed = 260 + rnd.nextDouble() * 240,
        size = 4.5 + rnd.nextDouble() * 3.5,
        spin = (rnd.nextDouble() - 0.5) * 10,
        color = colors[rnd.nextInt(colors.length)],
        xJitter = (rnd.nextDouble() - 0.5) * 80;

  final double angle;
  final double speed;
  final double size;
  final double spin;
  final double xJitter;
  final Color color;
}

class _ConfettiBurstState extends State<_ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _particles = List.generate(22, (_) => _Particle(rnd, widget.colors));
    final reduced = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (reduced) {
      // Respect reduced-motion: skip the burst entirely.
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
    } else {
      _controller.forward().whenCompleteOrCancel(widget.onDone);
    }
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
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(_particles, _controller.value),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t);

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, 110);
    final paint = Paint();
    for (final p in particles) {
      final dist = p.speed * t;
      final x = origin.dx + p.xJitter + cos(p.angle) * dist;
      final y = origin.dy + sin(p.angle) * dist + 380 * t * t;
      final opacity = (1 - t).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.7),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.t != t;
}
