import 'package:flutter/material.dart';

/// Microcontroller chip logo.
/// [size] controls the bounding box; the chip scales proportionally.
/// Use [size] ≈ 160 for the login page hero, smaller values for inline icons.
class ChipLogo extends StatelessWidget {
  final double size;
  const ChipLogo({super.key, this.size = 160});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ChipPainter()),
    );
  }
}

class _ChipPainter extends CustomPainter {
  // Dark navy chip body — matches reference image
  static const _body = Color(0xFF1B2A4A);
  // Slightly darker for pins so they read against white background
  static const _pin  = Color(0xFF141E33);
  // Cyan traces (left / top)
  static const _cyan = Color(0xFF00CFD5);
  // Blue traces (right / bottom)
  static const _blue = Color(0xFF2979FF);

  @override
  void paint(Canvas canvas, Size size) {
    final s  = size.width;
    // Chip body occupies centre 76 % of canvas; 12 % reserved each side for pins
    final cl = s * 0.12;
    final ct = s * 0.12;
    final cr = s * 0.88;
    final cb = s * 0.88;
    final cw = cr - cl;
    final corner = Radius.circular(cw * 0.14); // very rounded, like reference

    // ── 1. Pin stubs (drawn first; chip body will cover their inner ends) ──
    _drawPins(canvas, s, cl, ct, cr, cb);

    // ── 2. Chip body (filled dark navy) ─────────────────────────────────────
    canvas.drawRRect(
      RRect.fromLTRBR(cl, ct, cr, cb, corner),
      Paint()..color = _body,
    );

    // ── 3. Circuit traces — clipped to chip interior ─────────────────────────
    canvas.save();
    canvas.clipRRect(RRect.fromLTRBR(cl, ct, cr, cb, corner));
    _drawTraces(canvas, s, cl, ct, cr, cb);
    canvas.restore();
  }

  // ── Pins ──────────────────────────────────────────────────────────────────
  void _drawPins(Canvas canvas, double s,
      double cl, double ct, double cr, double cb) {
    final paint = Paint()..color = _pin;
    const n     = 5;                   // pins per side
    final thick = s * 0.038;           // pin short dimension
    final len   = s * 0.10;            // how far pin sticks out from chip edge

    final vGap = (cb - ct) / (n + 1);
    final hGap = (cr - cl) / (n + 1);

    for (int i = 0; i < n; i++) {
      final vy = ct + vGap * (i + 1);
      final hx = cl + hGap * (i + 1);

      // Left
      canvas.drawRect(
          Rect.fromLTWH(cl - len, vy - thick / 2, len, thick), paint);
      // Right
      canvas.drawRect(
          Rect.fromLTWH(cr, vy - thick / 2, len, thick), paint);
      // Top
      canvas.drawRect(
          Rect.fromLTWH(hx - thick / 2, ct - len, thick, len), paint);
      // Bottom
      canvas.drawRect(
          Rect.fromLTWH(hx - thick / 2, cb, thick, len), paint);
    }
  }

  // ── Circuit traces ─────────────────────────────────────────────────────────
  void _drawTraces(Canvas canvas, double s,
      double cl, double ct, double cr, double cb) {
    final sw   = s * 0.038;   // stroke width
    final viaR = s * 0.030;   // via (junction) circle radius

    // Trace stroke paint
    Paint mk(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Via (hollow junction circle) paint
    Paint vp(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 0.65;

    // Draw a polyline
    void line(Color c, List<Offset> pts) {
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length; i++) { path.lineTo(pts[i].dx, pts[i].dy); }
      canvas.drawPath(path, mk(c));
    }

    // Draw a via circle
    void via(Color c, double x, double y) =>
        canvas.drawCircle(Offset(x, y), viaR, vp(c));

    // ── CYAN traces — enter from left edge & top edge ──────────────────────

    // C1: left pin → right → down
    line(_cyan, [
      Offset(cl,           ct + s * .25),
      Offset(cl + s * .18, ct + s * .25),
      Offset(cl + s * .18, ct + s * .42),
    ]);
    via(_cyan, cl + s * .18, ct + s * .25);
    via(_cyan, cl + s * .18, ct + s * .42);

    // C2: left pin → right → down → right (branch)
    line(_cyan, [
      Offset(cl,           ct + s * .38),
      Offset(cl + s * .10, ct + s * .38),
      Offset(cl + s * .10, ct + s * .54),
      Offset(cl + s * .28, ct + s * .54),
    ]);
    via(_cyan, cl + s * .10, ct + s * .38);
    via(_cyan, cl + s * .28, ct + s * .54);

    // C3: top pin → down → right
    line(_cyan, [
      Offset(cl + s * .22, ct),
      Offset(cl + s * .22, ct + s * .20),
      Offset(cl + s * .40, ct + s * .20),
    ]);
    via(_cyan, cl + s * .22, ct + s * .20);
    via(_cyan, cl + s * .40, ct + s * .20);

    // C4: top pin → short stub down
    line(_cyan, [
      Offset(cl + s * .38, ct),
      Offset(cl + s * .38, ct + s * .10),
    ]);
    via(_cyan, cl + s * .38, ct + s * .10);

    // ── BLUE traces — enter from right edge & bottom edge ─────────────────

    // B1: right pin → left → down
    line(_blue, [
      Offset(cr,           ct + s * .25),
      Offset(cr - s * .18, ct + s * .25),
      Offset(cr - s * .18, ct + s * .44),
    ]);
    via(_blue, cr - s * .18, ct + s * .25);
    via(_blue, cr - s * .18, ct + s * .44);

    // B2: right pin → left → down → left (branch)
    line(_blue, [
      Offset(cr,           ct + s * .38),
      Offset(cr - s * .10, ct + s * .38),
      Offset(cr - s * .10, ct + s * .58),
      Offset(cr - s * .30, ct + s * .58),
    ]);
    via(_blue, cr - s * .10, ct + s * .38);
    via(_blue, cr - s * .30, ct + s * .58);

    // B3: right pin → short stub left
    line(_blue, [
      Offset(cr,           ct + s * .52),
      Offset(cr - s * .26, ct + s * .52),
    ]);
    via(_blue, cr - s * .26, ct + s * .52);

    // B4: bottom pin → up → left
    line(_blue, [
      Offset(cr - s * .22, cb),
      Offset(cr - s * .22, cb - s * .18),
      Offset(cr - s * .42, cb - s * .18),
    ]);
    via(_blue, cr - s * .42, cb - s * .18);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
