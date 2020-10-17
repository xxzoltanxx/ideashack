import 'package:flutter/material.dart';

class CustomBlockPainter extends CustomPainter {
  CustomBlockPainter({@required this.gradientColors});

  List<Color> gradientColors;

  @override
  void paint(Canvas canvas, Size size) {
    final shapeBounds = Rect.fromLTRB(0, 0, size.width, size.height);
    final gradient = LinearGradient(colors: gradientColors, stops: [0, 1.0]);
    Paint paint = Paint()..shader = gradient.createShader(shapeBounds);

    final backgroundPath = Path()
      ..moveTo(shapeBounds.left, shapeBounds.top)
      ..lineTo(shapeBounds.bottomLeft.dx, shapeBounds.bottomLeft.dy)
      ..lineTo(shapeBounds.bottomRight.dx * 0.5, shapeBounds.bottomRight.dy)
      ..lineTo(
          shapeBounds.bottomRight.dx * 0.6, shapeBounds.bottomRight.dy * 1.2)
      ..lineTo(shapeBounds.bottomRight.dx * 0.7, shapeBounds.bottomRight.dy)
      ..lineTo(shapeBounds.bottomRight.dx, shapeBounds.bottomRight.dy)
      ..lineTo(shapeBounds.topRight.dx, shapeBounds.topRight.dy)
      ..close();

    canvas.drawPath(backgroundPath, paint);
  }

  @override
  bool shouldRepaint(CustomBlockPainter oldDelegate) {
    return gradientColors != oldDelegate.gradientColors;
  }
}

class CustomBubble extends CustomPainter {
  CustomBubble(this.isLeft);

  bool isLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 0.5;
    final shapeBounds = Rect.fromLTRB(0, 0, size.width, size.height);
    if (isLeft) {
      canvas.drawLine(Offset(0, 20), Offset(30, 20), paint);
      canvas.drawLine(Offset(30, 20), Offset(50, 0), paint);
      canvas.drawLine(Offset(50, 0), Offset(70, 20), paint);
      if (shapeBounds.topRight.dx - 70 > 0) {
        canvas.drawLine(
            Offset(70, 20), Offset(shapeBounds.topRight.dx, 20), paint);
      }
    } else {
      if (shapeBounds.topRight.dx - 70 > 0) {
        canvas.drawLine(
            Offset(0, 20), Offset(shapeBounds.topRight.dx - 70, 20), paint);
      }
      canvas.drawLine(Offset(shapeBounds.topRight.dx - 70, 20),
          Offset(shapeBounds.topRight.dx - 50, 0), paint);
      canvas.drawLine(Offset(shapeBounds.topRight.dx - 50, 0),
          Offset(shapeBounds.topRight.dx - 30, 20), paint);
      canvas.drawLine(Offset(shapeBounds.topRight.dx - 30, 20),
          Offset(shapeBounds.topRight.dx, 20), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
