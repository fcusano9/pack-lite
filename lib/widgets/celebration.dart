import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// A brief, non-blocking confetti burst for the "all packed" moment.
/// Inserted as an overlay, ignores pointers, removes itself after ~1.3s.
void showCelebration(BuildContext context) {
  final overlay = Overlay.of(context);
  final harbor = context.harbor;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: _ConfettiBurst(
        colors: [harbor.accent, harbor.good, const Color(0xFFE9B949)],
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
  _Particle(Random random, List<Color> colors)
      : angle = -pi / 2 + (random.nextDouble() - 0.5) * pi * 0.9,
        speed = 260 + random.nextDouble() * 240,
        size = 4.5 + random.nextDouble() * 3.5,
        spin = (random.nextDouble() - 0.5) * 10,
        color = colors[random.nextInt(colors.length)],
        xJitter = (random.nextDouble() - 0.5) * 80;

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
    final random = Random();
    _particles = List.generate(22, (_) => _Particle(random, widget.colors));
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
  _ConfettiPainter(this.particles, this.progress);

  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, 110);
    final paint = Paint();
    for (final particle in particles) {
      final dist = particle.speed * progress;
      final x = origin.dx + particle.xJitter + cos(particle.angle) * dist;
      final y = origin.dy + sin(particle.angle) * dist + 380 * progress * progress;
      final opacity = (1 - progress).clamp(0.0, 1.0);
      paint.color = particle.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.spin * progress);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: particle.size, height: particle.size * 0.7),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}
