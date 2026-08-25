import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/app_header.dart';
import '../widgets/app_sidebar.dart';

// ── Fluid scale helpers ────────────────────────────────────────────────────
double _lerp(double t, double min, double max) => min + (max - min) * t;
double _t(double width) => ((width - 360) / (1400 - 360)).clamp(0.0, 1.0);

extension FluidContext on BuildContext {
  double get _w => MediaQuery.sizeOf(this).width;
  double get _h => MediaQuery.sizeOf(this).height;
  double ff(double min, {double? max}) => _lerp(_t(_w), min, max ?? min * 1.35);
  double fs(double min, {double? max}) => _lerp(_t(_w), min, max ?? min * 2.5);
  double fw(double min, {double? max}) => _lerp(_t(_w), min, max ?? min * 1.8);
  double get screenWidth  => _w;
  double get screenHeight => _h;
  double get hPad => fs(16, max: 80);
  double get vPad => fs(12, max: 40);
  EdgeInsets get pagePadding => EdgeInsets.symmetric(horizontal: hPad, vertical: vPad);
  double get maxContent => _w < 600 ? _w : (_w * 0.9).clamp(600, 1400);
  bool get isMobile  => _w < 600;
  bool get isTablet  => _w >= 600 && _w < 1000;
  bool get isDesktop => _w >= 1000;
  bool get twoColumn => _w >= 900;
}

// ── PageShell ──────────────────────────────────────────────────────────────
class PageShell extends StatelessWidget {
  final Widget child;
  final bool scrollable;
  final EdgeInsets? padding;
  final double? maxWidth;
  final MainAxisAlignment mainAxisAlignment;
  final bool showSidebar;
  final bool showHeader;

  const PageShell({
    super.key,
    required this.child,
    this.scrollable = true,
    this.padding,
    this.maxWidth,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.showSidebar = false,
    this.showHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Center(
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

    if (scrollable) {
      content = SingleChildScrollView(child: content);
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor),
        child: Stack(
          children: [
            Positioned.fill(child: const GridBackground()),
            Column(
              children: [
                if (showHeader) const AppHeader().animate().fadeIn(duration: const Duration(milliseconds: 400)).slideY(begin: -0.1),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showSidebar && !context.isMobile) 
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 240),
                          child: const NeubrutalistSidebar().animate().fadeIn(duration: const Duration(milliseconds: 400)).slideX(begin: -0.1),
                        ),
                      if (showSidebar && !context.isMobile)
                        VerticalDivider(width: 3, thickness: 3, color: Theme.of(context).dividerColor),
                      Expanded(child: content.animate().fadeIn(duration: const Duration(milliseconds: 500), delay: const Duration(milliseconds: 100)).slideY(begin: 0.05)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      drawer: (showSidebar && context.isMobile) ? Drawer(
        width: 280,
        child: const NeubrutalistSidebar(),
      ) : null,
    );
  }
}

// ── GridBackground ───────────────────────────────────────────────────────
class GridBackground extends StatelessWidget {
  const GridBackground({super.key});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter(Theme.of(context).brightness));
  }
}

class _GridPainter extends CustomPainter {
  final Brightness brightness;
  _GridPainter(this.brightness);

  @override
  void paint(Canvas canvas, Size size) {
    final gridColor = brightness == Brightness.dark 
        ? Colors.white.withOpacity(0.05) 
        : Colors.black.withOpacity(0.05);
    final paint = Paint()..color = gridColor..strokeWidth = 1.0;
    const spacing = 30.0;

    for (double i = 0; i <= size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double j = 0; j <= size.height; j += spacing) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), paint);
    }
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// ── NeubrutalistContainer ──────────────────────────────────────────────────
class NeubrutalistContainer extends StatelessWidget {
  final Widget child;
  final Color? color;
  final double borderWidth;
  final double shadowOffset;
  final double borderRadius;
  final EdgeInsets? padding;
  final bool useEntryAnimation;
  final double? width;
  final double? height;

  const NeubrutalistContainer({
    super.key,
    required this.child,
    this.color,
    this.borderWidth = 3,
    this.shadowOffset = 4,
    this.borderRadius = 4,
    this.padding,
    this.useEntryAnimation = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outlineColor = isDark ? Colors.white : Colors.black;
    final shadowColor = Colors.black;

    Widget container = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: outlineColor, width: borderWidth),
        boxShadow: shadowOffset == 0 ? null : [
          BoxShadow(
            color: shadowColor,
            offset: Offset(shadowOffset, shadowOffset),
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );

    if (useEntryAnimation) {
      return container.animate()
          .fadeIn(duration: const Duration(milliseconds: 400))
          .slideY(begin: 0.1, curve: Curves.easeOutQuad);
    }
    return container;
  }
}

// ── NeubrutalistButton ─────────────────────────────────────────────────────
class NeubrutalistButton extends StatefulWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final VoidCallback? onPressed;

  const NeubrutalistButton({
    super.key,
    required this.label,
    required this.color,
    this.textColor,
    this.onPressed,
  });

  @override
  State<NeubrutalistButton> createState() => _NeubrutalistButtonState();
}

class _NeubrutalistButtonState extends State<NeubrutalistButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // If background is very light (like white), use black text even in dark mode
    // Otherwise use white text in dark mode.
    final bool isLightBackground = widget.color.computeLuminance() > 0.5;
    final defaultTextColor = isLightBackground ? Colors.black : (isDark ? Colors.white : Colors.black);

    return MouseRegion(
      cursor: widget.onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
          transform: _isPressed ? Matrix4.translationValues(2, 2, 0) : Matrix4.identity(),
          child: NeubrutalistContainer(
            color: widget.color,
            shadowOffset: _isPressed ? 0 : 4,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Center(
              child: Text(
                widget.label,
                style: TextStyle(color: widget.textColor ?? defaultTextColor, fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── AdaptiveRow ────────────────────────────────────────────────────────────
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
    final width = MediaQuery.sizeOf(context).width;
    final useRow = width >= collapseBelow;

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
      mainAxisAlignment: MainAxisAlignment.start,
      children: stacked,
    );
  }
}


// ── Gap helper ─────────────────────────────────────────────────────────────
class Gap extends StatelessWidget {
  final double min;
  final double? max;
  final bool horizontal;
  const Gap(this.min, {super.key, this.max, this.horizontal = false});
  @override
  Widget build(BuildContext context) {
    final size = context.fs(min, max: max);
    return SizedBox(width: horizontal ? size : null, height: horizontal ? null : size);
  }
}
