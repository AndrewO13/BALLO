import 'package:flutter/material.dart';

/// Material 3 corner-radius scale.
///
/// Google sizes the radius with the component: a corner should stay a similar
/// share of the surface, so larger containers take a larger step. Nested
/// shapes use a smaller step so the corners stay concentric (inner radius is
/// about the outer radius minus the gap). Fully rounded controls use [full].
///
/// https://m3.material.io/styles/shape/corner-radius-scale
/// https://m3.material.io/styles/shape
abstract final class AppShape {
  static const double none = 0;
  static const double extraSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double largeIncreased = 20;
  static const double extraLarge = 28;
  static const double extraLargeIncreased = 32;
  static const double extraExtraLarge = 48;

  /// Pill. Replaces "50% of the component" with one full-radius token.
  static const double full = 1000;

  static const BorderRadius extraSmallRadius = BorderRadius.all(
    Radius.circular(extraSmall),
  );
  static const BorderRadius smallRadius = BorderRadius.all(
    Radius.circular(small),
  );
  static const BorderRadius mediumRadius = BorderRadius.all(
    Radius.circular(medium),
  );
  static const BorderRadius largeRadius = BorderRadius.all(
    Radius.circular(large),
  );
  static const BorderRadius largeIncreasedRadius = BorderRadius.all(
    Radius.circular(largeIncreased),
  );
  static const BorderRadius extraLargeRadius = BorderRadius.all(
    Radius.circular(extraLarge),
  );
  static const BorderRadius extraLargeIncreasedRadius = BorderRadius.all(
    Radius.circular(extraLargeIncreased),
  );
  static const BorderRadius extraExtraLargeRadius = BorderRadius.all(
    Radius.circular(extraExtraLarge),
  );
  static const BorderRadius fullRadius = BorderRadius.all(
    Radius.circular(full),
  );

  /// Cards and list containers (medium).
  static const BorderRadius card = mediumRadius;

  /// Dialogs (extra large).
  static const BorderRadius dialog = extraLargeRadius;

  /// Bottom sheets, top corners only (extra large).
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(extraLarge),
  );

  /// Standard FAB (large).
  static const BorderRadius fab = largeRadius;

  /// Menus (small).
  static const BorderRadius menu = smallRadius;

  /// Snackbars (extra small).
  static const BorderRadius snack = extraSmallRadius;

  /// Buttons and other fully rounded controls.
  static const StadiumBorder button = StadiumBorder();
}
