import 'dart:math';
import 'package:flutter/material.dart';

class StarfieldBackground extends StatefulWidget {
  final Widget child;
  const StarfieldBackground({super.key, required this.child});

  @override
  State<StarfieldBackground> createState() => _StarfieldBackgroundState();
}

class _StarfieldBackgroundState extends State<StarfieldBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Star> _stars = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Generate stars
    for (int i = 0; i < 100; i++) {
      _stars.add(Star(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 2 + 1,
        blinkSpeed: _random.nextDouble() * 0.05 + 0.01,
        offset: _random.nextDouble() * pi * 2,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: Colors.black),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: StarPainter(_stars, _controller.value),
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

class Star {
  final double x;
  final double y;
  final double size;
  final double blinkSpeed;
  final double offset;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.blinkSpeed,
    required this.offset,
  });
}

class StarPainter extends CustomPainter {
  final List<Star> stars;
  final double animationValue;

  StarPainter(this.stars, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    for (var star in stars) {
      final opacity = (sin(animationValue * 2 * pi + star.offset) + 1) / 2;
      paint.color = Colors.white.withOpacity(opacity * 0.8 + 0.2);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
