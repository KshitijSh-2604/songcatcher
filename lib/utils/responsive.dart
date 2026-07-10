import 'package:flutter/material.dart';

// ── Fluid scale helpers ────────────────────────────────────────────────────
// Values interpolate smoothly between min screen (360px) and max (1400px).
// Nothing jumps — everything scales proportionally.

double _lerp(double t, double min, double max) => min + (max - min) * t;

double _t(double width) =>
    ((width - 360) / (1400 - 360)).clamp(0.0, 1.0);

/// Fluid font size — scales linearly with screen width.
/// Usage: Text('Hi', style: TextStyle(fontSize: context.ff(14, max: 20)))
extension FluidContext on BuildContext {
  double get _w => MediaQuery.sizeOf(this).width;
  double get _h => MediaQuery.sizeOf(this).height;

  /// Fluid font: min size at 360px screen, max size at 1400px screen
  double ff(double min, {double? max}) =>
      _lerp(_t(_w), min, max ?? min * 1.35);

  /// Fluid spacing/padding value
  double fs(double min, {double? max}) =>
      _lerp(_t(_w), min, max ?? min * 2.5);

  /// Fluid size (width/height of a widget)
  double fw(double min, {double? max}) =>
      _lerp(_t(_w), min, max ?? min * 1.8);

  double get screenWidth  => _w;
  double get screenHeight => _h;

  /// Horizontal page padding — 16px on phone, 80px on wide desktop
  double get hPad => fs(16, max: 80);

  /// Vertical page padding
  double get vPad => fs(12, max: 40);

  EdgeInsets get pagePadding =>
      EdgeInsets.symmetric(horizontal: hPad, vertical: vPad);

  /// Max content width — content never stretches beyond this
  double get maxContent => _w < 600 ? _w : (_w * 0.85).clamp(600, 1100);

  bool get isMobile  => _w < 600;
  bool get isTablet  => _w >= 600 && _w < 1000;
  bool get isDesktop => _w >= 1000;

  /// Two-column threshold — use side-by-side layout above this width
  bool get twoColumn => _w >= 900;
}

// ── PageShell ──────────────────────────────────────────────────────────────
/// Drop this as the body of any screen. Handles centering, max-width,
/// padding, and optional scrolling automatically.

class PageShell extends StatelessWidget {
  final Widget child;
  final bool scrollable;
  final EdgeInsets? padding;
  final double? maxWidth;
  final MainAxisAlignment mainAxisAlignment;

  const PageShell({
    super.key,
    required this.child,
    this.scrollable = true,
    this.padding,
    this.maxWidth,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? context.maxContent,
        ),
        child: Padding(
          padding: padding ?? context.pagePadding,
          child: child,
        ),
      ),
    );
    return scrollable
        ? SingleChildScrollView(child: inner)
        : inner;
  }
}

// ── FluidText ──────────────────────────────────────────────────────────────
/// Text that scales its font size with screen width.

class FluidText extends StatelessWidget {
  final String text;
  final double minSize;
  final double? maxSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;

  const FluidText(
      this.text, {
        super.key,
        required this.minSize,
        this.maxSize,
        this.fontWeight,
        this.color,
        this.textAlign,
        this.maxLines,
      });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      style: TextStyle(
        fontSize:   context.ff(minSize, max: maxSize),
        fontWeight: fontWeight,
        color:      color,
      ),
    );
  }
}

// ── AdaptiveRow ────────────────────────────────────────────────────────────
/// Automatically switches between Row (wide) and Column (narrow).
/// collapseBelow: screen width at which it switches to Column.

class AdaptiveRow extends StatelessWidget {
  final List<Widget> children;
  final double collapseBelow;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;

  const AdaptiveRow({
    super.key,
    required this.children,
    this.collapseBelow = 700,
    this.spacing = 16,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final useRow = constraints.maxWidth >= collapseBelow;
      if (useRow) {
        final List<Widget> spaced = [];
        for (var i = 0; i < children.length; i++) {
          if (i > 0) spaced.add(SizedBox(width: spacing));
          spaced.add(Expanded(child: children[i]));
        }
        return Row(
          crossAxisAlignment: crossAxisAlignment,
          mainAxisAlignment: mainAxisAlignment,
          children: spaced,
        );
      }
      final List<Widget> stacked = [];
      for (var i = 0; i < children.length; i++) {
        if (i > 0) stacked.add(SizedBox(height: spacing));
        stacked.add(children[i]);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: stacked,
      );
    });
  }
}

// ── FluidGrid ──────────────────────────────────────────────────────────────
/// Grid that computes column count from available width automatically.

class FluidGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  const FluidGrid({
    super.key,
    required this.children,
    this.minItemWidth = 200,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final cols =
      (constraints.maxWidth / (minItemWidth + spacing)).floor().clamp(1, 6);
      final itemW =
          (constraints.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: children
            .map((c) => SizedBox(width: itemW, child: c))
            .toList(),
      );
    });
  }
}

// ── FluidPadding ───────────────────────────────────────────────────────────

class FluidPadding extends StatelessWidget {
  final Widget child;
  final double minH;
  final double? maxH;
  final double minV;
  final double? maxV;

  const FluidPadding({
    super.key,
    required this.child,
    this.minH = 16,
    this.maxH,
    this.minV = 12,
    this.maxV,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.fs(minH, max: maxH),
        vertical:   context.fs(minV, max: maxV),
      ),
      child: child,
    );
  }
}

// ── gap helper ─────────────────────────────────────────────────────────────
/// Fluid gap that scales with screen size.
class Gap extends StatelessWidget {
  final double min;
  final double? max;
  final bool horizontal;

  const Gap(this.min, {super.key, this.max, this.horizontal = false});

  @override
  Widget build(BuildContext context) {
    final size = context.fs(min, max: max);
    return SizedBox(
      width:  horizontal ? size : null,
      height: horizontal ? null  : size,
    );
  }
}