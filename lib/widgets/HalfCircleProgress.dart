import 'dart:math';
import 'package:flutter/material.dart';

class HalfCircleProgress extends StatelessWidget {
  final double progress; // 0.0〜1.0
  final double size;
  final Color color;
  final Color backgroundColor;
  final String centerText;

  const HalfCircleProgress({
    super.key,
    required this.progress,
    this.size = 96,
    required this.centerText,
    this.color = const Color(0xFF8B6A2B),
    this.backgroundColor = const Color(0xFFEADFCB),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size / 2 + 12, // 半円なので高さは半分
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          CustomPaint(
            size: Size(size, size / 2),
            painter: _HalfCirclePainter(
              progress: progress,
              color: color,
              backgroundColor: backgroundColor,
            ),
          ),
          Positioned(
            bottom: 0,
            child: Text(
              centerText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _HalfCirclePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _HalfCirclePainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 10.0;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // 背景（半円）
    canvas.drawArc(rect, pi, pi, false, bgPaint);

    // 進捗
    canvas.drawArc(
      rect,
      pi,
      pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}