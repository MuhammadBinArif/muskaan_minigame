import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Fried crust color presets for [GolgappaIcon] and [FoodPainter].
enum GolgappaCrust {
  classic(
    label: 'Classic Sooji Fry',
    highlight: Color(0xFFFFF2C6),
    light: Color(0xFFFFE39E),
    mid: Color(0xFFF3BA58),
    deep: Color(0xFFD98B2B),
    dark: Color(0xFF9C5414),
    innerDough: Color(0xFFFBF0C9),
  ),
  lightCrisp(
    label: 'Light & Crisp',
    highlight: Color(0xFFFFF9E2),
    light: Color(0xFFFFECB8),
    mid: Color(0xFFF7CC76),
    deep: Color(0xFFE2A243),
    dark: Color(0xFFAE6E24),
    innerDough: Color(0xFFFFF6DC),
  ),
  deepGolden(
    label: 'Deep Kadhai Golden',
    highlight: Color(0xFFFFEBB4),
    light: Color(0xFFFFD584),
    mid: Color(0xFFEC9F34),
    deep: Color(0xFFC46E1B),
    dark: Color(0xFF823F0D),
    innerDough: Color(0xFFF7E4B4),
  ),
  attaWheat(
    label: 'Atta (Whole Wheat)',
    highlight: Color(0xFFF9E8C2),
    light: Color(0xFFEED39D),
    mid: Color(0xFFD49F54),
    deep: Color(0xFFB17530),
    dark: Color(0xFF744519),
    innerDough: Color(0xFFF1DFB8),
  );

  const GolgappaCrust({
    required this.label,
    required this.highlight,
    required this.light,
    required this.mid,
    required this.deep,
    required this.dark,
    required this.innerDough,
  });

  final String label;
  final Color highlight;
  final Color light;
  final Color mid;
  final Color deep;
  final Color dark;
  final Color innerDough;
}

/// Drop-in Golgappa / Pani Puri vector widget painted on a Flutter [Canvas].
///
/// Backwards-compatible with `GolgappaIcon(size: 72, pani: false)` while
/// exposing optional [crust], [texture], and [showShadow] controls.
class GolgappaIcon extends StatelessWidget {
  const GolgappaIcon({
    super.key,
    this.size = 72,
    this.pani = false,
    this.crust = GolgappaCrust.classic,
    this.texture = 1.0,
    this.showShadow = true,
  });

  final double size;
  final bool pani;
  final GolgappaCrust crust;
  final double texture;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: FoodPainter(
          pani: pani,
          crust: crust,
          texture: texture,
          showShadow: showShadow,
        ),
      ),
    );
  }
}

/// Deterministic cross-platform Lehmer RNG so Native, Web, and animations
/// produce identical blisters and crack vertices with zero repaint flicker.
class _Rng {
  _Rng(int seed) : _s = (seed % 2147483646).abs() + 1;
  int _s;

  double nextDouble() {
    _s = (_s * 48271) % 2147483647;
    return _s / 2147483647;
  }

  bool nextBool() => nextDouble() >= 0.5;
}

/// Procedural [CustomPainter] rendering a puffed, blistered, thumb-cracked
/// golgappa stuffed with either spiced aloo-chana masala or chilled mint pani.
class FoodPainter extends CustomPainter {
  const FoodPainter({
    required this.pani,
    this.crust = GolgappaCrust.classic,
    this.texture = 1.0,
    this.showShadow = true,
  });

  final bool pani;
  final GolgappaCrust crust;
  final double texture;
  final bool showShadow;

  @override
  void paint(Canvas canvas, Size size) {
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.shortestSide <= 0) {
      return;
    }

    final c = Offset(size.width / 2, size.height * .53);
    final r = size.shortestSide * .36;
    final shell = _buildShellPath(c, r);
    final holeC = c.translate(r * .04, -r * .44);

    if (showShadow) {
      _drawContactShadow(canvas, c, r);
    }
    _drawBody(canvas, c, r, shell);
    _drawBlisters(canvas, c, r, shell);
    _drawCrackAndFilling(canvas, c, holeC, r);
    _drawGlossAndCrumbs(canvas, c, holeC, r);
  }

  /// Smooth closed Catmull-Rom spline with subtle equatorial puff belt and
  /// resting base flatten so the puri reads as real fried dough, not a CAD oval.
  Path _buildShellPath(Offset c, double r) {
    const count = 24;
    final rng = _Rng(41);
    final pts = List<Offset>.generate(count, (i) {
      final t = (i / count) * math.pi * 2;
      final wobble = 1.0 + (rng.nextDouble() * 2 - 1) * 0.018;
      final s = math.sin(t);
      final dEq = s - 0.08;
      final eqBoost = math.exp(-dEq * dEq * 5.0) * 0.032;
      final baseFlat = s > 0.55 ? (s - 0.55) * 0.045 : 0.0;
      return Offset(
        c.dx + math.cos(t) * r * 1.07 * (wobble + eqBoost),
        c.dy + s * r * 0.98 * (wobble - baseFlat),
      );
    });

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < count; i++) {
      final p0 = pts[(i - 1 + count) % count];
      final p1 = pts[i];
      final p2 = pts[(i + 1) % count];
      final p3 = pts[(i + 2) % count];
      path.cubicTo(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
        p2.dx,
        p2.dy,
      );
    }
    return path..close();
  }

  void _drawContactShadow(Canvas canvas, Offset c, double r) {
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, r * 1.03),
        width: r * 1.82,
        height: r * .36,
      ),
      Paint()
        ..color = const Color(0x2E3B1D04)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(0.5, r * .13),
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, r * 1.0),
        width: r * 1.18,
        height: r * .19,
      ),
      Paint()
        ..color = const Color(0x38261000)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(0.5, r * .05),
        ),
    );
  }

  void _drawBody(Canvas canvas, Offset c, double r, Path shell) {
    // 5-stop off-center radial fry gradient from upper-left light source.
    canvas.drawPath(
      shell,
      Paint()
        ..shader = ui.Gradient.radial(
          c.translate(-r * .30, -r * .36),
          r * 1.88,
          [crust.highlight, crust.light, crust.mid, crust.deep, crust.dark],
          const [0.0, 0.22, 0.52, 0.80, 1.0],
        ),
    );

    canvas.save();
    canvas.clipPath(shell);

    // Paper-thin translucent upper dome warmth.
    final domeC = c.translate(-r * .08, -r * .34);
    canvas.drawOval(
      Rect.fromCenter(center: domeC, width: r * 1.55, height: r * .95),
      Paint()
        ..shader = ui.Gradient.radial(domeC, r * .78, const [
          Color(0x42FFF7DA),
          Color(0x00FFF7DA),
        ]),
    );

    // Classic equatorial puri puff-ridge where rolled dough split in hot oil.
    final seamHi =
        Path()
          ..moveTo(c.dx - r * 1.08, c.dy + r * .06)
          ..quadraticBezierTo(
            c.dx,
            c.dy + r * .28,
            c.dx + r * 1.08,
            c.dy + r * .04,
          );
    canvas.drawPath(
      seamHi,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .085
        ..color = const Color(0x2EFFEDBE)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(0.5, r * .035),
        ),
    );
    final seamLo =
        Path()
          ..moveTo(c.dx - r * 1.06, c.dy + r * .11)
          ..quadraticBezierTo(
            c.dx,
            c.dy + r * .34,
            c.dx + r * 1.06,
            c.dy + r * .09,
          );
    canvas.drawPath(
      seamLo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .045
        ..color = const Color(0x228C4810)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(0.5, r * .025),
        ),
    );

    // Deep kadhai-fried shading hugging the bottom-right belly.
    canvas.drawArc(
      Rect.fromCenter(center: c, width: r * 1.94, height: r * 1.78),
      0.22,
      1.65,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .24
        ..color = const Color(0x306E3306)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(0.5, r * .05),
        ),
    );

    // Warm bounce-light along the bottom edge so shadows stay appetizing.
    canvas.drawArc(
      Rect.fromCenter(center: c, width: r * 2.02, height: r * 1.86),
      0.95,
      1.22,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .05
        ..color = const Color(0x48FFD37E),
    );

    // Soft uneven dough swell patches.
    const swells = <List<double>>[
      [0.42, 0.16, 0.48, 0.38],
      [-0.48, 0.36, 0.42, 0.34],
      [0.08, 0.58, 0.52, 0.28],
    ];
    for (final s in swells) {
      final pc = c.translate(s[0] * r, s[1] * r);
      canvas.drawOval(
        Rect.fromCenter(center: pc, width: s[2] * r * 2, height: s[3] * r * 2),
        Paint()
          ..shader = ui.Gradient.radial(pc, s[2] * r, const [
            Color(0x33FFEAB4),
            Color(0x00FFEAB4),
          ]),
      );
    }

    canvas.restore();

    // Subtle crisp fried-edge outline that scales cleanly at any icon size.
    canvas.drawPath(
      shell,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, r * .022)
        ..color = const Color(0x4A7D3D0E),
    );
  }

  void _drawBlisters(Canvas canvas, Offset c, double r, Path shell) {
    if (texture <= 0.01) return;

    canvas.save();
    canvas.clipPath(shell);

    final rng = _Rng(7);
    final holeApprox = c.translate(r * .04, -r * .44);

    // 1. Semolina micro-grain foreshortened along sphere curvature.
    final density = texture.isFinite ? texture.clamp(0.0, 2.0) : 1.0;
    final grainCount = (48 * density).round();
    for (var i = 0; i < grainCount; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final u = math.sqrt(rng.nextDouble()) * 0.95;
      final p = c.translate(
        math.cos(a) * u * r * 1.02,
        math.sin(a) * u * r * 0.93,
      );
      final dark = rng.nextBool();
      final rad = r * (0.014 + rng.nextDouble() * 0.026);
      if ((p - holeApprox).distance < r * .40) continue;

      final foreshort = math.max(0.45, math.sqrt(1.0 - u * u * 0.75));
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a + math.pi / 2);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: rad * 2,
          height: rad * 2 * foreshort,
        ),
        Paint()
          ..color = dark ? const Color(0x308A4A10) : const Color(0x5CFFF3D1),
      );
      canvas.restore();

      if (dark) {
        canvas.drawCircle(
          p.translate(-rad * .32, -rad * .36),
          rad * .52,
          Paint()..color = const Color(0x4AFFF3D1),
        );
      }
    }

    // 2. Raised 3D fry-blisters with shadow, puffed dome, ring, and highlight.
    final bubbleCount = (9 * density).round();
    for (var i = 0; i < bubbleCount; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final u = 0.25 + rng.nextDouble() * 0.62;
      final p = c.translate(
        math.cos(a) * u * r * 1.0,
        math.sin(a) * u * r * 0.92,
      );
      final br = r * (0.042 + rng.nextDouble() * 0.032);
      if ((p - holeApprox).distance < r * .52) continue;

      final foreshort = math.max(0.55, math.sqrt(1.0 - u * u * 0.65));
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a + math.pi / 2);

      final bRect = Rect.fromCenter(
        center: Offset.zero,
        width: br * 2,
        height: br * 2 * foreshort,
      );
      canvas.drawOval(
        bRect.shift(Offset(br * .20, br * .24)),
        Paint()..color = const Color(0x296E3608),
      );
      canvas.drawOval(bRect, Paint()..color = const Color(0x52FFEEC2));
      canvas.drawOval(
        bRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * .013
          ..color = const Color(0x3B8A4A12),
      );
      canvas.restore();

      canvas.drawCircle(
        p.translate(-br * .28, -br * .28),
        br * .28,
        Paint()..color = const Color(0x66FFFDF2),
      );
    }

    // 3. Soft toasted oil-kissed patches.
    final spotCount = (4 * density).round();
    for (var i = 0; i < spotCount; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final d = math.sqrt(rng.nextDouble()) * r * .88;
      final p = c.translate(math.cos(a) * d, math.sin(a) * d * .92);
      canvas.drawCircle(
        p,
        r * .13,
        Paint()
          ..shader = ui.Gradient.radial(p, r * .13, const [
            Color(0x308F4910),
            Color(0x008F4910),
          ]),
      );
    }

    canvas.restore();
  }

  void _drawCrackAndFilling(Canvas canvas, Offset c, Offset holeC, double r) {
    const n = 20;
    final rng = _Rng(2026);
    final wobble = List<double>.generate(
      n,
      (i) =>
          1.0 + (rng.nextDouble() * 2 - 1) * 0.16 - (i % 3 == 0 ? 0.08 : 0.0),
    );

    Offset vertex(Offset center, double rx, double ry, int idx) {
      final t = (idx % n) / n * 2 * math.pi;
      final w = wobble[idx % n];
      return Offset(
        center.dx + math.cos(t) * rx * w,
        center.dy + math.sin(t) * ry * w,
      );
    }

    Path jagged(Offset center, double rx, double ry) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = vertex(center, rx, ry, i);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      return path..close();
    }

    // Radial hairline stress cracks on the brittle dome.
    for (final idx in const [2, 9, 15]) {
      final start = vertex(holeC, r * .57, r * .36, idx);
      final t = idx / n * 2 * math.pi;
      final mid = start.translate(
        math.cos(t + 0.14) * r * .08,
        math.sin(t + 0.14) * r * .07,
      );
      final end = mid.translate(
        math.cos(t - 0.10) * r * .07,
        math.sin(t - 0.10) * r * .06,
      );
      final crackLine =
          Path()
            ..moveTo(start.dx, start.dy)
            ..lineTo(mid.dx, mid.dy)
            ..lineTo(end.dx, end.dy);
      canvas.drawPath(
        crackLine,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(0.8, r * .014)
          ..color = const Color(0x527A3E10),
      );
    }

    // Toasted thin-crust halo around the thumb-cracked hole.
    canvas.drawPath(
      jagged(holeC.translate(0, r * .015), r * .68, r * .44),
      Paint()..color = const Color(0x2BA65816),
    );

    // Broken outer rim: exposed pale crisp inner dough.
    final rim = jagged(holeC, r * .58, r * .37);
    canvas.drawPath(rim, Paint()..color = crust.innerDough);
    canvas.drawPath(
      rim,
      Paint()
        ..shader = ui.Gradient.linear(
          holeC.translate(0, -r * .37),
          holeC.translate(0, r * .37),
          const [Color(0x66FFFFFF), Color(0x00FFFFFF), Color(0x528F5219)],
          const [0.0, 0.5, 1.0],
        ),
    );

    // Deep hollow interior falling into shadow + warm translucent lower glow.
    final hollowCenter = holeC.translate(0, r * .015);
    final hollow = jagged(hollowCenter, r * .48, r * .29);
    canvas.drawPath(
      hollow,
      Paint()
        ..shader = ui.Gradient.linear(
          hollowCenter.translate(0, -r * .29),
          hollowCenter.translate(0, r * .29),
          const [Color(0xFF593412), Color(0xFF241104), Color(0xFF140801)],
          const [0.0, 0.65, 1.0],
        ),
    );
    canvas.save();
    canvas.clipPath(hollow);
    canvas.drawOval(
      Rect.fromCenter(
        center: hollowCenter.translate(0, r * .20),
        width: r * .74,
        height: r * .30,
      ),
      Paint()..color = const Color(0x45C87D32),
    );
    canvas.restore();

    // 3D occlusion clip: stuffing sits INSIDE the lower front lip while heaped
    // garnish rises freely above the back rim.
    final stuffingClip =
        Path()
          ..addPath(hollow, Offset.zero)
          ..addRect(
            Rect.fromLTRB(
              holeC.dx - r * .56,
              holeC.dy - r * .85,
              holeC.dx + r * .56,
              holeC.dy + r * .03,
            ),
          );

    canvas.save();
    canvas.clipPath(stuffingClip);
    if (pani) {
      _paintPani(canvas, holeC, r, jagged);
    } else {
      _paintMasala(canvas, holeC, r);
    }
    canvas.restore();

    // Re-stroke the front broken lip OVER the base of the filling for true depth.
    final frontOuter = Path();
    final frontInner = Path();
    for (var i = 1; i <= 9; i++) {
      final po = vertex(holeC.translate(0, r * .02), r * .58, r * .37, i);
      final pi = vertex(holeC, r * .52, r * .32, i);
      if (i == 1) {
        frontOuter.moveTo(po.dx, po.dy);
        frontInner.moveTo(pi.dx, pi.dy);
      } else {
        frontOuter.lineTo(po.dx, po.dy);
        frontInner.lineTo(pi.dx, pi.dy);
      }
    }
    canvas.drawPath(
      frontOuter,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = r * .042
        ..color = crust.mid,
    );
    canvas.drawPath(
      frontInner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = r * .028
        ..color = crust.innerDough,
    );

    // Spillover detail in front of the broken lip.
    if (pani) {
      _drawPaniDrip(canvas, holeC, r);
    } else {
      _drawChutneyBead(canvas, holeC, r);
    }
  }

  void _paintPani(
    Canvas canvas,
    Offset holeC,
    double r,
    Path Function(Offset, double, double) jagged,
  ) {
    final water = jagged(holeC.translate(0, r * .02), r * .50, r * .31);
    canvas.drawPath(
      water,
      Paint()
        ..shader = ui.Gradient.linear(
          holeC.translate(0, -r * .30),
          holeC.translate(0, r * .32),
          const [Color(0xFF7CE070), Color(0xFF349243), Color(0xFF195425)],
          const [0.0, 0.58, 1.0],
        ),
    );

    // Pale lime liquid meniscus hugging the inner rim.
    canvas.drawPath(
      jagged(holeC.translate(0, r * .02), r * .46, r * .28),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .026
        ..color = const Color(0x55D9FFBF),
    );

    // Spiced potato & chickpea peeking half-submerged through the mint water.
    _potato(canvas, holeC.translate(r * .17, -r * .15), r * .17, -0.25);
    _chana(canvas, holeC.translate(-r * .20, -r * .12), r * .072);
    canvas.drawOval(
      Rect.fromCenter(
        center: holeC.translate(0, -r * .04),
        width: r * .72,
        height: r * .24,
      ),
      Paint()..color = const Color(0x40339142),
    );

    // Floating crispy boondi pearls with tiny water-tension rings.
    const boondis = <List<double>>[
      [-0.04, -0.01, 0.042],
      [0.25, 0.04, 0.036],
      [-0.26, 0.05, 0.034],
    ];
    for (final b in boondis) {
      final bp = holeC.translate(b[0] * r, b[1] * r);
      final br = b[2] * r;
      canvas.drawCircle(
        bp,
        br * 1.35,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * .01
          ..color = const Color(0x48DCFFCA),
      );
      canvas.drawCircle(bp, br, Paint()..color = const Color(0xFFE7A93C));
      canvas.drawCircle(
        bp.translate(-br * .28, -br * .28),
        br * .42,
        Paint()..color = const Color(0xFFFBE09C),
      );
    }

    // Crushed pudina flecks, roasted jeera, and red chili flake.
    final mint = Paint()..color = const Color(0xFF16471C);
    canvas.drawCircle(holeC.translate(r * .12, r * .08), r * .026, mint);
    canvas.drawCircle(holeC.translate(-r * .15, r * .09), r * .022, mint);
    canvas.drawCircle(holeC.translate(-r * .02, -r * .16), r * .020, mint);
    canvas.drawOval(
      Rect.fromCenter(
        center: holeC.translate(r * .05, r * .14),
        width: r * .045,
        height: r * .018,
      ),
      Paint()..color = const Color(0xFFB52B1D),
    );

    // Wet glassy surface sheen.
    canvas.drawOval(
      Rect.fromCenter(
        center: holeC.translate(-r * .11, -r * .13),
        width: r * .48,
        height: r * .13,
      ),
      Paint()..color = const Color(0x5CE0FFCC),
    );
  }

  void _drawPaniDrip(Canvas canvas, Offset holeC, double r) {
    // Subtle darkened wet trail on the crust underneath the droplet.
    canvas.drawOval(
      Rect.fromCenter(
        center: holeC.translate(r * .33, r * .37),
        width: r * .11,
        height: r * .36,
      ),
      Paint()..color = const Color(0x265E3208),
    );

    final dripPath =
        Path()
          ..moveTo(holeC.dx + r * .29, holeC.dy + r * .19)
          ..quadraticBezierTo(
            holeC.dx + r * .36,
            holeC.dy + r * .34,
            holeC.dx + r * .38,
            holeC.dy + r * .48,
          )
          ..arcToPoint(
            Offset(holeC.dx + r * .27, holeC.dy + r * .48),
            radius: Radius.circular(r * .058),
          )
          ..quadraticBezierTo(
            holeC.dx + r * .29,
            holeC.dy + r * .34,
            holeC.dx + r * .29,
            holeC.dy + r * .19,
          )
          ..close();

    canvas.drawPath(
      dripPath,
      Paint()
        ..shader = ui.Gradient.linear(
          holeC.translate(r * .32, r * .18),
          holeC.translate(r * .32, r * .54),
          const [Color(0xFF66C462), Color(0xFF2D7D36)],
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: holeC.translate(r * .315, r * .36),
        width: r * .024,
        height: r * .16,
      ),
      Paint()..color = const Color(0x8CE6FFDB),
    );
    canvas.drawCircle(
      holeC.translate(r * .31, r * .48),
      r * .018,
      Paint()..color = const Color(0xB3FFFFFF),
    );
  }

  void _paintMasala(Canvas canvas, Offset holeC, double r) {
    // Warm masala base inside the cavity so no empty gaps show between cubes.
    canvas.drawOval(
      Rect.fromCenter(
        center: holeC.translate(0, r * .02),
        width: r * .84,
        height: r * .44,
      ),
      Paint()..color = const Color(0xFF6E4318),
    );

    // Heaped spiced aloo cubes and boiled chana.
    _chana(canvas, holeC.translate(-r * .30, -r * .03), r * .078);
    _potato(canvas, holeC.translate(-r * .17, -r * .11), r * .19, 0.28);
    _potato(canvas, holeC.translate(r * .16, -r * .13), r * .21, -0.30);
    _potato(canvas, holeC.translate(-r * .01, -r * .24), r * .17, 0.42);
    _chana(canvas, holeC.translate(r * .30, -r * .02), r * .068);
    _chana(canvas, holeC.translate(r * .02, r * .05), r * .072);

    // Golden boondi pearls tucked into the stuffing.
    final boondi = Paint()..color = const Color(0xFFE5A438);
    canvas.drawCircle(holeC.translate(-r * .25, -r * .22), r * .034, boondi);
    canvas.drawCircle(holeC.translate(r * .24, -r * .26), r * .032, boondi);

    // Glossy tamarind-date (meethi imli) chutney glaze + green chutney accent.
    final chutney = Paint()..color = const Color(0xFF6B240E);
    canvas.drawOval(
      Rect.fromCenter(
        center: holeC.translate(-r * .16, r * .03),
        width: r * .22,
        height: r * .11,
      ),
      chutney,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: holeC.translate(r * .19, r * .04),
        width: r * .18,
        height: r * .09,
      ),
      chutney,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: holeC.translate(-r * .18, r * .01),
        width: r * .10,
        height: r * .03,
      ),
      Paint()..color = const Color(0x66FFD9C4),
    );
    canvas.drawCircle(
      holeC.translate(r * .10, -r * .02),
      r * .042,
      Paint()..color = const Color(0xFF39963A),
    );

    // Diced red-onion accent cube.
    canvas.save();
    canvas.translate(holeC.dx - r * .05, holeC.dy - r * .05);
    canvas.rotate(0.22);
    final onion = Rect.fromCenter(
      center: Offset.zero,
      width: r * .095,
      height: r * .08,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(onion, Radius.circular(r * .02)),
      Paint()..color = const Color(0xFFC45B84),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        onion.deflate(r * .018),
        Radius.circular(r * .012),
      ),
      Paint()..color = const Color(0xFFF3CFE0),
    );
    canvas.restore();

    // Crispy nylon sev strands crisscrossing over the mound.
    _sev(canvas, holeC.translate(-r * .02, -r * .33), r * .36, -0.22, r * .034);
    _sev(canvas, holeC.translate(r * .19, -r * .26), r * .28, 0.36, r * .030);
    _sev(canvas, holeC.translate(-r * .16, -r * .18), r * .24, 0.82, r * .028);
    _sev(canvas, holeC.translate(r * .06, -r * .14), r * .22, -0.68, r * .026);

    // Fresh 3-lobed coriander (dhaniya) leaf garnish on top.
    _coriander(canvas, holeC.translate(r * .05, -r * .38), r * .085, -0.35);
  }

  void _drawChutneyBead(Canvas canvas, Offset holeC, double r) {
    final beadC = holeC.translate(-r * .24, r * .23);
    canvas.drawOval(
      Rect.fromCenter(center: beadC, width: r * .085, height: r * .065),
      Paint()..color = const Color(0xFF6B240E),
    );
    canvas.drawCircle(
      beadC.translate(-r * .015, -r * .012),
      r * .016,
      Paint()..color = const Color(0x8CFFE2D1),
    );
  }

  void _potato(Canvas canvas, Offset p, double s, double angle) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);
    final rect = Rect.fromCenter(center: Offset.zero, width: s, height: s * .8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.shift(Offset(0, s * .06)),
        Radius.circular(s * .25),
      ),
      Paint()..color = const Color(0x40422106),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(s * .25)),
      Paint()..color = const Color(0xFFF3E5AE),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(s * .14), Radius.circular(s * .18)),
      Paint()..color = const Color(0xFFDDC785),
    );
    // Turmeric & red-chili masala specks.
    canvas.drawCircle(
      Offset(s * .15, -s * .05),
      s * .065,
      Paint()..color = const Color(0x99DC8C28),
    );
    canvas.drawCircle(
      Offset(-s * .16, s * .10),
      s * .045,
      Paint()..color = const Color(0xB3B8331E),
    );
    canvas.restore();
  }

  void _chana(Canvas canvas, Offset p, double rad) {
    canvas.drawCircle(
      p.translate(0, rad * .16),
      rad,
      Paint()..color = const Color(0x38381A04),
    );
    canvas.drawCircle(p, rad, Paint()..color = const Color(0xFFB57C42));
    canvas.drawCircle(
      p.translate(-rad * .25, -rad * .25),
      rad * .46,
      Paint()..color = const Color(0xFFD5A66A),
    );
    canvas.drawCircle(
      p.translate(rad * .55, rad * .10),
      rad * .22,
      Paint()..color = const Color(0xFF966230),
    );
  }

  void _sev(Canvas canvas, Offset p, double len, double angle, double w) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);
    final path =
        Path()
          ..moveTo(-len / 2, 0)
          ..quadraticBezierTo(-len * .2, -w * 1.6, 0, 0)
          ..quadraticBezierTo(len * .2, w * 1.6, len / 2, 0);
    canvas.drawPath(
      path.shift(Offset(0, w * .45)),
      Paint()
        ..color = const Color(0x384A2204)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFEC8D2C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path.shift(Offset(0, -w * .18)),
      Paint()
        ..color = const Color(0x66FFD28A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .38
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _coriander(Canvas canvas, Offset p, double s, double angle) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);
    final leaf = Paint()..color = const Color(0xFF338A36);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-s * .45, 0), width: s, height: s * .68),
      leaf,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s * .45, 0), width: s, height: s * .68),
      leaf,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, -s * .36),
        width: s * .92,
        height: s * .72,
      ),
      Paint()..color = const Color(0xFF43A446),
    );
    canvas.drawLine(
      Offset(0, s * .35),
      Offset(0, -s * .42),
      Paint()
        ..color = const Color(0x80A8E89C)
        ..strokeWidth = math.max(0.7, s * .12)
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _drawGlossAndCrumbs(Canvas canvas, Offset c, Offset holeC, double r) {
    final hc = c.translate(-r * .56, -r * .20);
    canvas.drawOval(
      Rect.fromCenter(center: hc, width: r * .58, height: r * .28),
      Paint()
        ..shader = ui.Gradient.radial(hc, r * .29, const [
          Color(0x6BFFFFFF),
          Color(0x00FFFFFF),
        ]),
    );
    canvas.drawArc(
      Rect.fromCenter(center: c, width: r * 1.90, height: r * 1.76),
      -2.76,
      1.02,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * .046
        ..color = const Color(0x4DFFFFFF),
    );

    // Crisp broken dough flakes on the shoulder + tiny crumbs by the base.
    _flake(canvas, holeC.translate(-r * .72, r * .12), r * .048, 0.5);
    _flake(canvas, holeC.translate(r * .68, r * .18), r * .044, -0.4);
    _flake(canvas, holeC.translate(r * .12, -r * .46), r * .038, 0.9);
    if (showShadow) {
      _flake(canvas, c.translate(-r * .50, r * 1.02), r * .036, 1.2);
      _flake(canvas, c.translate(r * .60, r * .99), r * .030, -0.8);
    }
  }

  void _flake(Canvas canvas, Offset p, double s, double angle) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);
    final tri =
        Path()
          ..moveTo(-s, 0)
          ..lineTo(s, 0)
          ..lineTo(0, -s * 1.6)
          ..close();
    canvas.drawPath(
      tri.shift(Offset(0, s * .35)),
      Paint()..color = const Color(0x2E4A2404),
    );
    canvas.drawPath(tri, Paint()..color = crust.innerDough);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FoodPainter oldDelegate) {
    return oldDelegate.pani != pani ||
        oldDelegate.crust != crust ||
        oldDelegate.texture != texture ||
        oldDelegate.showShadow != showShadow;
  }
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
