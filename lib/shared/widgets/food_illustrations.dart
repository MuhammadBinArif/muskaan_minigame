import 'package:flutter/material.dart';

/// Asset-free street-food illustrations shared by onboarding and gameplay.
class GolgappaIcon extends StatelessWidget {
  const GolgappaIcon({super.key, this.size = 72, this.pani = false});
  final double size;
  final bool pani;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _FoodPainter(pani: pani)),
  );
}

class FacePhoneIllustration extends StatelessWidget {
  const FacePhoneIllustration({super.key, this.size = 150});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size * 1.35,
    height: size,
    child: CustomPaint(painter: _FacePhonePainter()),
  );
}

class _FoodPainter extends CustomPainter {
  const _FoodPainter({required this.pani});
  final bool pani;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 + 4);
    final r = size.shortestSide * .34;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFE2A34F));
    canvas.drawCircle(
      c.translate(-r * .2, -r * .22),
      r * .78,
      Paint()..color = const Color(0xFFF3C46B),
    );
    canvas.drawCircle(
      c.translate(-r * .2, -r * .22),
      r * .78,
      Paint()
        ..color = const Color(0xFFB96D2F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, -r * .62),
        width: r * .5,
        height: r * .3,
      ),
      Paint()..color = const Color(0xFF5B351E),
    );
    final filling =
        Paint()
          ..color = pani ? const Color(0xFF4B9B70) : const Color(0xFF6EA34C);
    canvas.drawCircle(c.translate(-r * .1, -r * .45), r * .13, filling);
    canvas.drawCircle(c.translate(r * .12, -r * .49), r * .1, filling);
    canvas.drawCircle(c.translate(-r * .25, -r * .55), r * .07, filling);
    canvas.drawCircle(
      c.translate(-r * .3, -r * .5),
      r * .08,
      Paint()..color = Colors.white.withValues(alpha: .45),
    );
  }

  @override
  bool shouldRepaint(covariant _FoodPainter oldDelegate) =>
      oldDelegate.pani != pani;
}

class _FacePhonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final phone = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .46,
        size.height * .08,
        size.width * .38,
        size.height * .84,
      ),
      Radius.circular(size.width * .06),
    );
    canvas.save();
    canvas.translate(size.width * .1, size.height * .1);
    canvas.rotate(-.08);
    canvas.drawRRect(phone, Paint()..color = const Color(0xFF6B6A72));
    canvas.drawRRect(
      phone.deflate(4),
      Paint()..color = const Color(0xFF202235),
    );
    canvas.restore();
    final arm =
        Paint()
          ..color = const Color(0xFFF28B28)
          ..strokeWidth = size.width * .12
          ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .12, size.height * .72),
      Offset(size.width * .56, size.height * .62),
      arm,
    );
    canvas.drawCircle(
      Offset(size.width * .55, size.height * .6),
      size.width * .1,
      Paint()..color = const Color(0xFFFFB52E),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
