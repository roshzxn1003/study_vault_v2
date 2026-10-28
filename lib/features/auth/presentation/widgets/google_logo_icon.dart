import 'package:flutter/material.dart';

/// Crisp, pixel-accurate vector Google 'G' brand logo rendered via CustomPainter.
/// Adheres to Google's official brand colors:
/// - Blue: #4285F4
/// - Green: #34A853
/// - Yellow: #FBBC05
/// - Red: #EA4335
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 20.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 24.0;

    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()..style = PaintingStyle.fill;

    // Blue segment (#4285F4)
    paint.color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(23.49, 12.27)
      ..cubicTo(23.49, 11.42, 23.41, 10.6, 23.27, 9.82)
      ..lineTo(12.0, 9.82)
      ..lineTo(12.0, 14.45)
      ..lineTo(18.44, 14.45)
      ..cubicTo(18.16, 15.96, 17.31, 17.26, 16.03, 18.12)
      ..lineTo(19.95, 21.16)
      ..cubicTo(22.24, 19.05, 23.49, 15.95, 23.49, 12.27)
      ..close();
    canvas.drawPath(bluePath, paint);

    // Green segment (#34A853)
    paint.color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(12.0, 24.0)
      ..cubicTo(15.24, 24.0, 17.96, 22.92, 19.95, 21.08)
      ..lineTo(16.03, 18.04)
      ..cubicTo(14.95, 18.77, 13.58, 19.25, 12.0, 19.25)
      ..cubicTo(8.92, 19.25, 6.32, 17.16, 5.37, 14.32)
      ..lineTo(1.36, 17.43)
      ..cubicTo(3.39, 21.33, 7.35, 24.0, 12.0, 24.0)
      ..close();
    canvas.drawPath(greenPath, paint);

    // Yellow segment (#FBBC05)
    paint.color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(5.37, 14.32)
      ..cubicTo(5.12, 13.6, 4.98, 12.81, 4.98, 12.0)
      ..cubicTo(4.98, 11.19, 5.12, 10.4, 5.37, 9.68)
      ..lineTo(1.36, 6.57)
      ..cubicTo(0.49, 8.28, 0.0, 10.08, 0.0, 12.0)
      ..cubicTo(0.0, 13.92, 0.49, 15.72, 1.36, 17.43)
      ..lineTo(5.37, 14.32)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // Red segment (#EA4335)
    paint.color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(12.0, 4.75)
      ..cubicTo(13.77, 4.75, 15.35, 5.36, 16.6, 6.55)
      ..lineTo(20.03, 3.12)
      ..cubicTo(17.96, 1.19, 15.24, 0.0, 12.0, 0.0)
      ..cubicTo(7.35, 0.0, 3.39, 2.67, 1.36, 6.57)
      ..lineTo(5.37, 9.68)
      ..cubicTo(6.32, 6.84, 8.92, 4.75, 12.0, 4.75)
      ..close();
    canvas.drawPath(redPath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
