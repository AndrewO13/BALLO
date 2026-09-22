import 'package:flutter/material.dart';

/// Mobile layout scale and breakpoints.
///
/// Values in this app were designed for a **412-wide** phone. This helper
/// scales those design dp values on other phone widths and keeps tablet /
/// desktop layouts unchanged (shortest side ≥ 600).
class AppResponsive {
  AppResponsive._();

  /// Design-time phone width (logical pixels).
  static const double designWidth = 412;

  /// Design-time phone height used to place full-screen artwork.
  static const double designHeight = 892;

  /// Narrow phones (e.g. iPhone SE class).
  static const double compactBreakpoint = 360;

  /// Shortest-side threshold for phones vs tablet/desktop.
  static const double tabletBreakpoint = 600;

  static bool isMobile(Size size) => size.shortestSide < tabletBreakpoint;

  static bool isCompact(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    return isMobile(size) && size.shortestSide < compactBreakpoint;
  }

  static bool isLandscapePhone(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    return isMobile(size) && size.width > size.height;
  }

  /// Typography / component scale from the shortest side so landscape
  /// does not enlarge type to match the long edge.
  static double layoutScaleOf(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    if (!isMobile(size)) return 1;
    return (size.shortestSide / designWidth).clamp(0.82, 1.12);
  }

  /// Horizontal scale from current width (1.0 at 412).
  static double widthScaleOf(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    if (!isMobile(size)) return 1;
    return size.width / designWidth;
  }

  static double heightScaleOf(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    if (!isMobile(size)) return 1;
    return size.height / designHeight;
  }

  static double scale(BuildContext context, double designDp) =>
      designDp * layoutScaleOf(context);

  /// Edge inset that is [design] dp on a 412-wide screen.
  static double edgeInsetForWidth(double width, {double design = 16}) {
    if (width >= tabletBreakpoint) return design;
    return design * (width / designWidth);
  }

  static double horizontalInset(
    BuildContext context, {
    double design = 16,
  }) {
    return edgeInsetForWidth(
      MediaQuery.sizeOf(context).width,
      design: design,
    );
  }
}

extension AppResponsiveContext on BuildContext {
  double get appScale => AppResponsive.layoutScaleOf(this);

  /// Design dp → scaled dp (identity at 412-wide portrait).
  double r(double designDp) => AppResponsive.scale(this, designDp);

  bool get isCompactPhone => AppResponsive.isCompact(this);

  bool get isLandscapePhone => AppResponsive.isLandscapePhone(this);
}

/// Applies mobile text and icon scaling under [MaterialApp.builder].
class MobileResponsiveScope extends StatelessWidget {
  const MobileResponsiveScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final double layoutScale = AppResponsive.layoutScaleOf(context);
    final double userFactor = mq.textScaler.scale(14) / 14.0;
    final IconThemeData iconTheme = IconTheme.of(context);

    return MediaQuery(
      data: mq.copyWith(
        textScaler: TextScaler.linear(userFactor * layoutScale),
      ),
      child: IconTheme(
        data: iconTheme.copyWith(
          size: (iconTheme.size ?? 24) * layoutScale,
        ),
        child: child,
      ),
    );
  }
}
