import 'package:flutter/material.dart';

import 'app_theme.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: palette.pageGradient),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: palette.primaryGlow.withValues(alpha: 0.18),
                      width: 5,
                    ),
                  ),
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

class FrostPanel extends StatelessWidget {
  const FrostPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 22,
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

    final content = DecoratedBox(
      decoration: BoxDecoration(
        gradient: palette.panelGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: palette.border),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
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
        : const Color(0xff1f1712);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.primaryGlow,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(
          color: palette.secondaryGlow.withValues(alpha: 0.32),
          width: 1.4,
        ),
      ),
      child: Center(
        child: Text(
          'P',
          style: TextStyle(
            color: foreground,
            fontSize: size * 0.46,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),
      ),
    );
  }
}

class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.palette.primaryGlow,
        letterSpacing: 1.45,
      ),
    );
  }
}

class SoftPill extends StatelessWidget {
  const SoftPill({required this.label, this.icon, this.color, super.key});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.palette.primaryGlow;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: accent),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: 0.45,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: palette.primaryGlow),
            const SizedBox(height: 12),
          ],
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
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
