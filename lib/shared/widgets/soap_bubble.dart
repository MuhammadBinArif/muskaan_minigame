// soap_bubbles.dart
import 'package:flutter/material.dart';

// ============================================================
// SoapBubbles — drop-in replacement for Text('🫧', fontSize: X)
// Draws the full 4-bubble cluster, no font dependency.
// ============================================================
class SoapBubbles extends StatelessWidget {
  final double width;
  final double height;
  final Color bubbleColor;
  final Color highlightColor;
  final double strokeWidth;

  const SoapBubbles({
    super.key,
    required this.width,
    required this.height,
    this.bubbleColor = const Color(0x80B7E4FF),
    this.highlightColor = const Color(0xE6FFFFFF),
    this.strokeWidth = 0.035,
  });

  /// Convenience constructor: square canvas.
  const SoapBubbles.square({
    super.key,
    required double size,
    this.bubbleColor = const Color(0x80B7E4FF),
    this.highlightColor = const Color(0xE6FFFFFF),
    this.strokeWidth = 0.035,
  }) : width = size,
       height = size;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(width, height),
        painter: SoapBubblesPainter(
          width: width,
          height: height,
          bubbleColor: bubbleColor,
          highlightColor: highlightColor,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

// ============================================================
// SoapBubblesPainter — unchanged from your file
// ============================================================
class SoapBubblesPainter extends CustomPainter {
  SoapBubblesPainter({
    required this.width,
    required this.height,
    this.bubbleColor = const Color(0x80B7E4FF),
    this.highlightColor = const Color(0xE6FFFFFF),
    this.strokeWidth = 0.035,
  });

  final double width;
  final double height;
  final Color bubbleColor;
  final Color highlightColor;
  final double strokeWidth;

  static final Paint _fillPaint =
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.fill;

  static final Paint _strokePaint =
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

  /// Normalized coordinates inside a 0..1 box.
  /// This lets us scale with canvas.transform without recalculating paths.
  static const List<_BubbleSpec> _bubbles = <_BubbleSpec>[
    _BubbleSpec(
      center: Offset(0.62, 0.58),
      radius: 0.30,
      highlightRect: Rect.fromLTRB(0.37, 0.33, 0.63, 0.59),
      startAngle: 3.55,
      sweepAngle: 1.05,
    ),
    _BubbleSpec(
      center: Offset(0.28, 0.30),
      radius: 0.16,
      highlightRect: Rect.fromLTRB(0.15, 0.17, 0.29, 0.31),
      startAngle: 3.55,
      sweepAngle: 0.95,
    ),
    _BubbleSpec(
      center: Offset(0.48, 0.16),
      radius: 0.09,
      highlightRect: Rect.fromLTRB(0.40, 0.09, 0.48, 0.17),
      startAngle: 3.55,
      sweepAngle: 0.85,
    ),
    _BubbleSpec(
      center: Offset(0.18, 0.64),
      radius: 0.07,
      highlightRect: Rect.fromLTRB(0.12, 0.58, 0.18, 0.64),
      startAngle: 3.55,
      sweepAngle: 0.80,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    canvas.save();

    // Stretch unit space to requested width/height.
    canvas.scale(size.width, size.height);

    _fillPaint.color = bubbleColor;
    _strokePaint.color = highlightColor;
    _strokePaint.strokeWidth = strokeWidth;

    for (final _BubbleSpec b in _bubbles) {
      canvas.drawCircle(b.center, b.radius, _fillPaint);
      canvas.drawArc(
        b.highlightRect,
        b.startAngle,
        b.sweepAngle,
        false,
        _strokePaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SoapBubblesPainter oldDelegate) {
    return oldDelegate.width != width ||
        oldDelegate.height != height ||
        oldDelegate.bubbleColor != bubbleColor ||
        oldDelegate.highlightColor != highlightColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _BubbleSpec {
  const _BubbleSpec({
    required this.center,
    required this.radius,
    required this.highlightRect,
    required this.startAngle,
    required this.sweepAngle,
  });

  final Offset center;
  final double radius;
  final Rect highlightRect;
  final double startAngle;
  final double sweepAngle;
}
