import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff006d39),
      surfaceTint: Color(0xff006d39),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff14ff8e),
      onPrimaryContainer: Color(0xff00713b),
      secondary: Color(0xff066d39),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff9df6b4),
      onSecondaryContainer: Color(0xff13733f),
      tertiary: Color(0xff006973),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff7eefff),
      onTertiaryContainer: Color(0xff006d77),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff93000a),
      surface: Color(0xfff1fcef),
      onSurface: Color(0xff141e16),
      onSurfaceVariant: Color(0xff3b4b3d),
      outline: Color(0xff6a7b6c),
      outlineVariant: Color(0xffb9cbba),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff29332a),
      inversePrimary: Color(0xff00e37d),
      primaryFixed: Color(0xff5eff9c),
      onPrimaryFixed: Color(0xff00210d),
      primaryFixedDim: Color(0xff00e37d),
      onPrimaryFixedVariant: Color(0xff005229),
      secondaryFixed: Color(0xff9df6b4),
      onSecondaryFixed: Color(0xff00210d),
      secondaryFixedDim: Color(0xff81d99a),
      onSecondaryFixedVariant: Color(0xff005229),
      tertiaryFixed: Color(0xff92f1ff),
      onTertiaryFixed: Color(0xff001f23),
      tertiaryFixedDim: Color(0xff62d6e6),
      onTertiaryFixedVariant: Color(0xff004f57),
      surfaceDim: Color(0xffd2ddd1),
      surfaceBright: Color(0xfff1fcef),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffecf7ea),
      surfaceContainer: Color(0xffe6f1e4),
      surfaceContainerHigh: Color(0xffe0ebdf),
      surfaceContainerHighest: Color(0xffdae6d9),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff003f1f),
      surfaceTint: Color(0xff006d39),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff007e42),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff003f1f),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff217c47),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff003d43),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff007984),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff740006),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffcf2c27),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfff1fcef),
      onSurface: Color(0xff0a130c),
      onSurfaceVariant: Color(0xff2a3a2d),
      outline: Color(0xff465649),
      outlineVariant: Color(0xff617163),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff29332a),
      inversePrimary: Color(0xff00e37d),
      primaryFixed: Color(0xff007e42),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff006233),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff217c47),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff006233),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff007984),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff005e68),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffbec9bd),
      surfaceBright: Color(0xfff1fcef),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffecf7ea),
      surfaceContainer: Color(0xffe0ebdf),
      surfaceContainerHigh: Color(0xffd5e0d3),
      surfaceContainerHighest: Color(0xffc9d5c8),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme());
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff003418),
      surfaceTint: Color(0xff006d39),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff00552b),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff003418),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff00552b),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff003237),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff00515a),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff600004),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff98000a),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfff1fcef),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff000000),
      outline: Color(0xff203024),
      outlineVariant: Color(0xff3d4d40),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff29332a),
      inversePrimary: Color(0xff00e37d),
      primaryFixed: Color(0xff00552b),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff003b1c),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff00552b),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff003b1c),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff00515a),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff00393f),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffb1bcb0),
      surfaceBright: Color(0xfff1fcef),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffe9f4e7),
      surfaceContainer: Color(0xffdae6d9),
      surfaceContainerHigh: Color(0xffccd7cb),
      surfaceContainerHighest: Color(0xffbec9bd),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xfff2fff1),
      surfaceTint: Color(0xff00e37d),
      onPrimary: Color(0xff00391b),
      primaryContainer: Color(0xff14ff8e),
      onPrimaryContainer: Color(0xff00713b),
      secondary: Color(0xff81d99a),
      onSecondary: Color(0xff00391b),
      secondaryContainer: Color(0xff006a37),
      onSecondaryContainer: Color(0xff8fe8a7),
      tertiary: Color(0xfff2fdff),
      onTertiary: Color(0xff00363c),
      tertiaryContainer: Color(0xff7eefff),
      onTertiaryContainer: Color(0xff006d77),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff0c150e),
      onSurface: Color(0xffdae6d9),
      onSurfaceVariant: Color(0xffb9cbba),
      outline: Color(0xff849585),
      outlineVariant: Color(0xff3b4b3d),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffdae6d9),
      inversePrimary: Color(0xff006d39),
      primaryFixed: Color(0xff5eff9c),
      onPrimaryFixed: Color(0xff00210d),
      primaryFixedDim: Color(0xff00e37d),
      onPrimaryFixedVariant: Color(0xff005229),
      secondaryFixed: Color(0xff9df6b4),
      onSecondaryFixed: Color(0xff00210d),
      secondaryFixedDim: Color(0xff81d99a),
      onSecondaryFixedVariant: Color(0xff005229),
      tertiaryFixed: Color(0xff92f1ff),
      onTertiaryFixed: Color(0xff001f23),
      tertiaryFixedDim: Color(0xff62d6e6),
      onTertiaryFixedVariant: Color(0xff004f57),
      surfaceDim: Color(0xff0c150e),
      surfaceBright: Color(0xff323c33),
      surfaceContainerLowest: Color(0xff071009),
      surfaceContainerLow: Color(0xff141e16),
      surfaceContainer: Color(0xff18221a),
      surfaceContainerHigh: Color(0xff232c24),
      surfaceContainerHighest: Color(0xff2d372f),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xfff2fff1),
      surfaceTint: Color(0xff00e37d),
      onPrimary: Color(0xff00391b),
      primaryContainer: Color(0xff14ff8e),
      onPrimaryContainer: Color(0xff005129),
      secondary: Color(0xff97f0af),
      onSecondary: Color(0xff002d14),
      secondaryContainer: Color(0xff4ba168),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xfff2fdff),
      onTertiary: Color(0xff00363c),
      tertiaryContainer: Color(0xff7eefff),
      onTertiaryContainer: Color(0xff004e56),
      error: Color(0xffffd2cc),
      onError: Color(0xff540003),
      errorContainer: Color(0xffff5449),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff0c150e),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffcfe1cf),
      outline: Color(0xffa5b6a6),
      outlineVariant: Color(0xff839585),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffdae6d9),
      inversePrimary: Color(0xff00542a),
      primaryFixed: Color(0xff5eff9c),
      onPrimaryFixed: Color(0xff001507),
      primaryFixedDim: Color(0xff00e37d),
      onPrimaryFixedVariant: Color(0xff003f1f),
      secondaryFixed: Color(0xff9df6b4),
      onSecondaryFixed: Color(0xff001507),
      secondaryFixedDim: Color(0xff81d99a),
      onSecondaryFixedVariant: Color(0xff003f1f),
      tertiaryFixed: Color(0xff92f1ff),
      onTertiaryFixed: Color(0xff001417),
      tertiaryFixedDim: Color(0xff62d6e6),
      onTertiaryFixedVariant: Color(0xff003d43),
      surfaceDim: Color(0xff0c150e),
      surfaceBright: Color(0xff3d473e),
      surfaceContainerLowest: Color(0xff030904),
      surfaceContainerLow: Color(0xff162018),
      surfaceContainer: Color(0xff202a22),
      surfaceContainerHigh: Color(0xff2b352c),
      surfaceContainerHighest: Color(0xff364037),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme());
  }

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xfff2fff1),
      surfaceTint: Color(0xff00e37d),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xff14ff8e),
      onPrimaryContainer: Color(0xff002f15),
      secondary: Color(0xffbfffcc),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xff7dd596),
      onSecondaryContainer: Color(0xff000f04),
      tertiary: Color(0xfff2fdff),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xff7eefff),
      onTertiaryContainer: Color(0xff002c31),
      error: Color(0xffffece9),
      onError: Color(0xff000000),
      errorContainer: Color(0xffffaea4),
      onErrorContainer: Color(0xff220001),
      surface: Color(0xff0c150e),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffffffff),
      outline: Color(0xffe3f5e3),
      outlineVariant: Color(0xffb5c7b6),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffdae6d9),
      inversePrimary: Color(0xff00542a),
      primaryFixed: Color(0xff5eff9c),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xff00e37d),
      onPrimaryFixedVariant: Color(0xff001507),
      secondaryFixed: Color(0xff9df6b4),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xff81d99a),
      onSecondaryFixedVariant: Color(0xff001507),
      tertiaryFixed: Color(0xff92f1ff),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xff62d6e6),
      onTertiaryFixedVariant: Color(0xff001417),
      surfaceDim: Color(0xff0c150e),
      surfaceBright: Color(0xff485349),
      surfaceContainerLowest: Color(0xff000000),
      surfaceContainerLow: Color(0xff18221a),
      surfaceContainer: Color(0xff29332a),
      surfaceContainerHigh: Color(0xff343e35),
      surfaceContainerHighest: Color(0xff3f4940),
    );
  }

  ThemeData darkHighContrast() {
    return theme(darkHighContrastScheme());
  }


  ThemeData theme(ColorScheme colorScheme) => ThemeData(
     useMaterial3: true,
     brightness: colorScheme.brightness,
     colorScheme: colorScheme,
     textTheme: textTheme.apply(
       bodyColor: colorScheme.onSurface,
       displayColor: colorScheme.onSurface,
     ),
     scaffoldBackgroundColor: colorScheme.surface,
     canvasColor: colorScheme.surface,
  );


  List<ExtendedColor> get extendedColors => [
  ];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
