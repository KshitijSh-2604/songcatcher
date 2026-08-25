import 'package:flutter/material.dart';
import '../../../models/app_user.dart';

class SkribblAvatar extends StatelessWidget {
  final AvatarConfig config;
  final double size;

  const SkribblAvatar({
    super.key,
    required this.config,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SkribblPainter(config, Theme.of(context).brightness),
    );
  }
}

class _SkribblPainter extends CustomPainter {
  final AvatarConfig config;
  final Brightness brightness;

  _SkribblPainter(this.config, this.brightness);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = config.bodyColor
      ..style = PaintingStyle.fill;

    final outlineColor = brightness == Brightness.dark ? Colors.white : Colors.black;

    final borderPaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;

    // Body (Roundish square)
    final rect = Rect.fromLTWH(
      size.width * 0.1, size.height * 0.1,
      size.width * 0.8, size.height * 0.8,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.2));
    
    canvas.drawRRect(rrect, paint);
    canvas.drawRRect(rrect, borderPaint);

    // Eyes
    final eyePaint = Paint()..color = outlineColor;
    final eyeSize = size.width * 0.08;
    final leftEyePos = Offset(size.width * 0.35, size.height * 0.4);
    final rightEyePos = Offset(size.width * 0.65, size.height * 0.4);
    
    // ...

    switch (config.eyeType) {
      case 0: // Dots
        canvas.drawCircle(leftEyePos, eyeSize, eyePaint);
        canvas.drawCircle(rightEyePos, eyeSize, eyePaint);
        break;
      case 1: // Lines
        canvas.drawLine(leftEyePos - Offset(eyeSize, 0), leftEyePos + Offset(eyeSize, 0), borderPaint);
        canvas.drawLine(rightEyePos - Offset(eyeSize, 0), rightEyePos + Offset(eyeSize, 0), borderPaint);
        break;
      case 2: // X
        canvas.drawLine(leftEyePos - Offset(eyeSize, eyeSize), leftEyePos + Offset(eyeSize, eyeSize), borderPaint);
        canvas.drawLine(leftEyePos + Offset(-eyeSize, eyeSize), leftEyePos + Offset(eyeSize, -eyeSize), borderPaint);
        canvas.drawLine(rightEyePos - Offset(eyeSize, eyeSize), rightEyePos + Offset(eyeSize, eyeSize), borderPaint);
        canvas.drawLine(rightEyePos + Offset(-eyeSize, eyeSize), rightEyePos + Offset(eyeSize, -eyeSize), borderPaint);
        break;
      case 3: // O
        canvas.drawCircle(leftEyePos, eyeSize, borderPaint);
        canvas.drawCircle(rightEyePos, eyeSize, borderPaint);
        break;
    }

    // Mouth
    final mouthPos = Offset(size.width * 0.5, size.height * 0.65);
    final mouthWidth = size.width * 0.25;

    switch (config.mouthType) {
      case 0: // Smile
        final path = Path()
          ..moveTo(mouthPos.dx - mouthWidth, mouthPos.dy)
          ..quadraticBezierTo(mouthPos.dx, mouthPos.dy + mouthWidth * 0.5, mouthPos.dx + mouthWidth, mouthPos.dy);
        canvas.drawPath(path, borderPaint);
        break;
      case 1: // Flat
        canvas.drawLine(Offset(mouthPos.dx - mouthWidth, mouthPos.dy), Offset(mouthPos.dx + mouthWidth, mouthPos.dy), borderPaint);
        break;
      case 2: // O
        canvas.drawCircle(mouthPos, mouthWidth * 0.4, borderPaint);
        break;
      case 3: // Zigzag
        final path = Path()
          ..moveTo(mouthPos.dx - mouthWidth, mouthPos.dy)
          ..lineTo(mouthPos.dx - mouthWidth * 0.5, mouthPos.dy + 5)
          ..lineTo(mouthPos.dx, mouthPos.dy - 5)
          ..lineTo(mouthPos.dx + mouthWidth * 0.5, mouthPos.dy + 5)
          ..lineTo(mouthPos.dx + mouthWidth, mouthPos.dy);
        canvas.drawPath(path, borderPaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
