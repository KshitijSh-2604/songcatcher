import 'package:flutter/material.dart';

/// Breakpoints
class Breakpoints {
  static const double mobile  = 600;
  static const double tablet  = 900;
  static const double desktop = 1200;
}

/// Quick helpers — use anywhere with context
extension ResponsiveContext on BuildContext {
  double get screenWidth  => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  bool get isMobile  => screenWidth <  Breakpoints.mobile;
  bool get isTablet  => screenWidth >= Breakpoints.mobile  && screenWidth < Breakpoints.desktop;
  bool get isDesktop => screenWidth >= Breakpoints.desktop;

  /// Responsive value — pick based on screen size
  T responsive<T>({required T mobile, T? tablet, required T desktop}) {
    if (isDesktop) return desktop;
    if (isTablet)  return tablet ?? desktop;
    return mobile;
  }

  /// Padding that scales with screen size
  EdgeInsets get pagePadding => responsive(
    mobile:  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    tablet:  const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
    desktop: const EdgeInsets.symmetric(horizontal: 80, vertical: 32),
  );

  /// Max content width (prevents content stretching too wide on large screens)
  double get contentMaxWidth => responsive(
    mobile:  double.infinity,
    tablet:  680,
    desktop: 960,
  );

  /// Font scale
  double get fontScale => responsive(mobile: 1.0, tablet: 1.05, desktop: 1.1);
}

/// Responsive layout widget — builds different UIs per breakpoint
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isDesktop) return desktop;
    if (context.isTablet)  return tablet ?? desktop;
    return mobile;
  }
}

/// Wraps content in a centred, max-width constrained box
/// Use this on every screen's body
class PageBody extends StatelessWidget {
  final Widget child;
  final bool scrollable;
  final EdgeInsets? padding;

  const PageBody({
    super.key,
    required this.child,
    this.scrollable = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
        child: Padding(
          padding: padding ?? context.pagePadding,
          child: child,
        ),
      ),
    );

    return scrollable
        ? SingleChildScrollView(child: content)
        : content;
  }
}

/// Two-column layout for desktop, stacked for mobile
class ResponsiveRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double spacing;
  final double mobileSpacing;

  const ResponsiveRow({
    super.key,
    required this.left,
    required this.right,
    this.spacing = 24,
    this.mobileSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, SizedBox(height: mobileSpacing), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        SizedBox(width: spacing),
        Expanded(child: right),
      ],
    );
  }
}

/// Grid that adapts columns to screen width
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double itemMinWidth;
  final double spacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.itemMinWidth = 280,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final width = context.screenWidth;
    final cols  = (width / itemMinWidth).floor().clamp(1, 4);

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: children.map((child) {
        final itemWidth =
            (width - context.pagePadding.horizontal - spacing * (cols - 1)) /
                cols;
        return SizedBox(width: itemWidth, child: child);
      }).toList(),
    );
  }
}

/// Responsive font size helper
double rFont(BuildContext context, double baseSize) {
  return baseSize * context.fontScale;
}