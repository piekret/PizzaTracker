import 'package:flutter/material.dart';

import 'app_theme.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ColoredBox(
      color: palette.backgroundBottom,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CheckerStripePainter(
                  primary: palette.primaryGlow,
                  paper: palette.surface,
                  ink: palette.border,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _CheckerStripePainter extends CustomPainter {
  _CheckerStripePainter({
    required this.primary,
    required this.paper,
    required this.ink,
  });

  final Color primary;
  final Color paper;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    const stripeHeight = 18.0;
    const tile = 18.0;
    final paintRed = Paint()..color = primary;
    final paintPaper = Paint()..color = paper;
    final paintInk = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, stripeHeight), paintPaper);

    var x = 0.0;
    var i = 0;
    while (x < size.width) {
      if (i.isEven) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, tile, stripeHeight),
          paintRed,
        );
      }
      x += tile;
      i += 1;
    }

    canvas.drawLine(
      Offset(0, stripeHeight),
      Offset(size.width, stripeHeight),
      paintInk,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckerStripePainter old) {
    return old.primary != primary || old.paper != paper || old.ink != ink;
  }
}

class FrostPanel extends StatelessWidget {
  const FrostPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 6,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final borderRadius = BorderRadius.circular(radius);

    final content = Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: borderRadius,
        border: Border.all(color: palette.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: palette.border,
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 54, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground =
        ThemeData.estimateBrightnessForColor(palette.primaryGlow) ==
            Brightness.dark
        ? Colors.white
        : const Color(0xfffff5dd);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.primaryGlow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.border, width: 2.4),
        boxShadow: [
          BoxShadow(
            color: palette.border,
            offset: const Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Text(
          'P',
          style: TextStyle(
            fontFamily: 'serif',
            color: foreground,
            fontSize: size * 0.5,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -1.2,
          ),
        ),
      ),
    );
  }
}

class Kicker extends StatelessWidget {
  const Kicker(this.text, {this.overflow, super.key});

  final String text;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: palette.primaryGlow,
            border: Border.all(color: palette.border, width: 1.4),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '» ${text.toUpperCase()}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontFamily: 'monospace',
              color: palette.border,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w900,
            ),
            overflow: overflow,
          ),
        ),
      ],
    );
  }
}

class SoftPill extends StatelessWidget {
  const SoftPill({
    required this.label,
    this.icon,
    this.color,
    this.overflow,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = color ?? palette.primaryGlow;
    final foreground =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
        ? const Color(0xfffff5dd)
        : palette.border;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.border, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            overflow: overflow,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontFamily: 'monospace',
              color: foreground,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.label,
    required this.value,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: palette.primaryGlow),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const DashedDivider(),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class DashedDivider extends StatelessWidget {
  const DashedDivider({this.height = 1.4, this.dash = 4, this.gap = 3, super.key});

  final double height;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final color = context.palette.border;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (!width.isFinite || width <= 0) {
            return const SizedBox.shrink();
          }
          final segment = dash + gap;
          final count = (width / segment).floor();
          return Row(
            children: List.generate(count, (i) {
              return Padding(
                padding: EdgeInsets.only(right: i == count - 1 ? 0 : gap),
                child: Container(width: dash, height: height, color: color),
              );
            }),
          );
        },
      ),
    );
  }
}

class AppSheetFrame extends StatelessWidget {
  const AppSheetFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.only(
      left: 14,
      right: 14,
      top: 14,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 14,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = (constraints.maxHeight - padding.vertical)
            .clamp(0.0, double.infinity)
            .toDouble();

        return Padding(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: FrostPanel(
                radius: 24,
                padding: const EdgeInsets.all(20),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
