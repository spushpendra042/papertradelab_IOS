import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? C.border),
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text.toUpperCase(), style: T.disp(12, w: FontWeight.w600, color: C.muted, spacing: 1)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Pill(this.text, {super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(110)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(text, style: T.body(10.5, w: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final String? hint;
  const StatTile({super.key, required this.label, required this.value, this.valueColor, this.hint});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: C.muted, fontSize: 12)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: T.mono(20, w: FontWeight.w700, color: valueColor ?? C.text)),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!, style: const TextStyle(color: C.muted, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

/// Responsive grid of stat tiles: 2 columns on phones, 3–4 on wider screens.
class StatGrid extends StatelessWidget {
  final List<Widget> children;
  const StatGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 560 ? 3 : 2);
      const gap = 10.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

class KeyValue extends StatelessWidget {
  final String k;
  final String v;
  final Color? color;
  const KeyValue(this.k, this.v, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(color: C.muted, fontSize: 11)),
        const SizedBox(height: 3),
        Text(v, style: T.mono(14, color: color ?? C.text)),
      ],
    );
  }
}

class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: C.muted, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: C.muted)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// SL ←—— entry ——→ target progress bar for the open trade.
class TradeProgressBar extends StatelessWidget {
  final double movePts;
  final double slPts; // distance of the CURRENT stop below entry (15, or 0 once at entry)
  final double targetPts;
  const TradeProgressBar({super.key, required this.movePts, required this.slPts, required this.targetPts});

  @override
  Widget build(BuildContext context) {
    const floor = 15.0; // always draw the original risk zone so the bar doesn't jump
    final span = floor + targetPts;
    final pos = ((movePts + floor) / span).clamp(0.0, 1.0);
    final entryAt = floor / span;
    final color = movePts >= 0 ? C.green : C.red;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      return SizedBox(
        height: 26,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0, right: 0, top: 10,
              child: Container(
                height: 6,
                decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Positioned(
              left: math.min(entryAt, pos) * w,
              width: (pos - entryAt).abs() * w,
              top: 10,
              child: Container(
                height: 6,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Positioned(left: entryAt * w - 1, top: 5, child: Container(width: 2, height: 16, color: C.muted)),
            Positioned(
              left: (pos * w - 7).clamp(0.0, math.max(0.0, w - 14)),
              top: 6,
              child: Container(
                width: 14, height: 14,
                decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle, border: Border.all(color: C.bg, width: 2)),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Dependency-free equity curve.
class EquityChart extends StatelessWidget {
  final List<double> values;
  const EquityChart({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('The equity curve appears after the second closed trade.',
              textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 13)),
        ),
      );
    }
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: CustomPaint(painter: _EquityPainter(values)),
    );
  }
}

class _EquityPainter extends CustomPainter {
  final List<double> v;
  _EquityPainter(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    final pts = <double>[0, ...v];
    var lo = pts.reduce(math.min);
    var hi = pts.reduce(math.max);
    if (hi - lo < 1) {
      hi += 1;
      lo -= 1;
    }
    const padT = 8.0, padB = 8.0;
    final h = size.height - padT - padB;
    double x(int i) => size.width * i / (pts.length - 1);
    double y(double val) => padT + h * (1 - (val - lo) / (hi - lo));

    final zero = Paint()
      ..color = C.border
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), zero);

    final up = pts.last >= 0;
    final color = up ? C.green : C.red;
    final line = Path()..moveTo(x(0), y(pts[0]));
    for (var i = 1; i < pts.length; i++) {
      line.lineTo(x(i), y(pts[i]));
    }
    final fill = Path.from(line)
      ..lineTo(size.width, y(0))
      ..lineTo(0, y(0))
      ..close();
    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withAlpha(70), color.withAlpha(5)],
          ).createShader(Offset.zero & size));
    canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(Offset(x(pts.length - 1), y(pts.last)), 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _EquityPainter old) => old.v != v;
}

class Disclaimer extends StatelessWidget {
  final String text;
  const Disclaimer(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 24),
      child: Text(text, style: const TextStyle(color: C.muted, fontSize: 11, height: 1.4)),
    );
  }
}

/// Centers content and caps its width so tablets don't get stretched layouts.
class PageBody extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function() onRefresh;
  final ScrollController? controller;
  const PageBody({super.key, required this.children, required this.onRefresh, this.controller});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: C.gold,
      backgroundColor: C.panel,
      onRefresh: onRefresh,
      child: LayoutBuilder(builder: (context, c) {
        final side = c.maxWidth > 560 ? (c.maxWidth - 532) / 2 : 14.0;
        return ListView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(side, 14, side, 20),
          children: children,
        );
      }),
    );
  }
}

/// Gold segmented control.
class SegTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const SegTabs({super.key, required this.labels, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: C.panelHi, borderRadius: BorderRadius.circular(11), border: Border.all(color: C.border)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: i == index ? C.gold : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Text(labels[i],
                    style: T.disp(12.5, w: FontWeight.w600, color: i == index ? C.onGold : C.muted)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Small labelled number box (the ".stat" block of the web app).
class Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool mono;
  final double size;
  const Stat(this.label, this.value, {super.key, this.color, this.mono = true, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: C.panelHi, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: T.label(C.muted)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: mono
                  ? T.mono(size, color: color ?? C.text)
                  : T.disp(size - 1, w: FontWeight.w600, color: color ?? C.text)),
        ),
      ]),
    );
  }
}

/// Two equal columns with a 10px gutter.
class Grid2 extends StatelessWidget {
  final List<Widget> children;
  const Grid2({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: children[i]),
          const SizedBox(width: 10),
          Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
        ]),
      ));
    }
    return Column(children: rows);
  }
}

/// Shown in place of a Pro section for free users. The data itself never
/// reaches the phone for them, so there is nothing to blur.
class LockCard extends StatelessWidget {
  final String title;
  final String text;
  final VoidCallback? onUpgrade;
  const LockCard({super.key, required this.title, required this.text, this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: C.goldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.gold.withAlpha(90))),
          child: const Icon(Icons.lock_rounded, color: C.gold, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.disp(14)),
            const SizedBox(height: 2),
            Text(text, style: T.body(12, color: C.muted, height: 1.4)),
          ]),
        ),
        if (onUpgrade != null) ...[
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
            onPressed: onUpgrade,
            child: Text('Go Pro', style: T.disp(12.5, color: C.onGold)),
          ),
        ],
      ]),
    );
  }
}

/// Thin gold/green strength bar.
class StrengthBar extends StatelessWidget {
  final String label;
  final double pct; // 0–100
  const StrengthBar({super.key, required this.label, required this.pct});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: T.label(C.muted)),
        Text('${pct.round()}%', style: T.mono(10.5, color: C.muted)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(children: [
          Container(height: 8, color: C.panelHi),
          FractionallySizedBox(
            widthFactor: (pct / 100).clamp(0.0, 1.0),
            child: Container(
              height: 8,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [C.goldDim, C.gold])),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class Tag extends StatelessWidget {
  final String text;
  final bool on;
  const Tag(this.text, {super.key, this.on = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: on ? C.goldBg : C.panelHi,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: on ? C.gold.withAlpha(90) : C.border),
      ),
      child: Text(text, style: T.body(10.5, w: FontWeight.w600, color: on ? C.gold : C.muted)),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 10),
      child: Column(children: [
        Icon(icon, color: C.dim, size: 28),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center, style: T.body(13, color: C.muted)),
      ]),
    );
  }
}
