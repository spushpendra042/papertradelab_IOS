import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Rolling spot sparkline with a soft gradient fill.
class SpotSparkline extends StatelessWidget {
  final List<double> values;
  const SpotSparkline({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      width: double.infinity,
      child: values.length < 2
          ? Center(child: Text('Collecting live ticks…', style: T.body(11, color: C.dim)))
          : CustomPaint(painter: _SparkPainter(List<double>.of(values))),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> v;
  _SparkPainter(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 5.0;
    final lo = v.reduce(math.min), hi = v.reduce(math.max);
    final range = math.max(1.0, hi - lo);
    final up = v.last >= v.first;
    final color = up ? C.green : C.red;
    double x(int i) => pad + (size.width - pad * 2) * i / (v.length - 1);
    double y(double p) => size.height - pad - (p - lo) / range * (size.height - pad * 2);

    final line = Path()..moveTo(x(0), y(v[0]));
    for (var i = 1; i < v.length; i++) {
      line.lineTo(x(i), y(v[i]));
    }
    final area = Path.from(line)
      ..lineTo(x(v.length - 1), size.height)
      ..lineTo(x(0), size.height)
      ..close();
    canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withAlpha(72), color.withAlpha(0)],
          ).createShader(Offset.zero & size));
    canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(Offset(x(v.length - 1), y(v.last)), 2.8, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => true;
}

/// Single-leg long option P&L at expiry.
class PayoffChart extends StatelessWidget {
  final double strike, premium, spot;
  final int qty;
  final bool isCall;
  const PayoffChart(
      {super.key, required this.strike, required this.premium, required this.spot, required this.qty, required this.isCall});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      width: double.infinity,
      child: CustomPaint(painter: _PayoffPainter(strike, premium, spot, qty, isCall)),
    );
  }
}

class _PayoffPainter extends CustomPainter {
  final double k, premium, spot;
  final int qty;
  final bool isCall;
  _PayoffPainter(this.k, this.premium, this.spot, this.qty, this.isCall);

  double _pl(double s) => ((isCall ? math.max(0.0, s - k) : math.max(0.0, k - s)) - premium) * qty;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 10.0;
    final span = math.max(300.0, premium * 6);
    final lo = k - span, hi = k + span;
    const steps = 48;
    final pts = [for (var i = 0; i <= steps; i++) lo + (hi - lo) * i / steps];
    final pls = pts.map(_pl).toList();
    final minPl = pls.reduce(math.min), maxPl = pls.reduce(math.max);
    final range = math.max(1.0, maxPl - minPl);
    double x(double s) => pad + (s - lo) / (hi - lo) * (size.width - pad * 2);
    double y(double pl) => size.height - pad - (pl - minPl) / range * (size.height - pad * 2);

    final dash = Paint()
      ..color = C.border
      ..strokeWidth = 1;
    _dashed(canvas, Offset(pad, y(0)), Offset(size.width - pad, y(0)), dash);
    final sx = x(spot.clamp(lo, hi).toDouble());
    _dashed(canvas, Offset(sx, pad), Offset(sx, size.height - pad), Paint()..color = C.gold..strokeWidth = 1);

    // loss part red, profit part green
    for (var i = 1; i < pts.length; i++) {
      final mid = (pls[i] + pls[i - 1]) / 2;
      canvas.drawLine(
          Offset(x(pts[i - 1]), y(pls[i - 1])),
          Offset(x(pts[i]), y(pls[i])),
          Paint()
            ..color = mid >= 0 ? C.green : C.red
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round);
    }
    canvas.drawCircle(Offset(sx, y(_pl(spot.clamp(lo, hi).toDouble()))), 3.2, Paint()..color = C.gold);

    _label(canvas, '+₹${maxPl.toStringAsFixed(0)}', const Offset(pad, 2));
    _label(canvas, '−₹${(premium * qty).toStringAsFixed(0)}', Offset(pad, size.height - 12));
  }

  void _dashed(Canvas c, Offset a, Offset b, Paint p) {
    const dash = 3.0, gap = 3.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    for (var d = 0.0; d < total; d += dash + gap) {
      c.drawLine(a + dir * d, a + dir * math.min(d + dash, total), p);
    }
  }

  void _label(Canvas c, String s, Offset at) {
    final tp = TextPainter(text: TextSpan(text: s, style: T.mono(8.5, w: FontWeight.w400, color: C.muted)), textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, at);
  }

  @override
  bool shouldRepaint(covariant _PayoffPainter o) =>
      o.k != k || o.premium != premium || o.spot != spot || o.qty != qty || o.isCall != isCall;
}
