import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff1c6d00),
      surfaceTint: Color(0xff1c6d00),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff40d107),
      onPrimaryContainer: Color(0xff135300),
      secondary: Color(0xff226d08),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffa3f483),
      onSecondaryContainer: Color(0xff27710e),
      tertiary: Color(0xff006b58),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff00cdab),
      onTertiaryContainer: Color(0xff005142),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff93000a),
      surface: Color(0xfff3fde8),
      onSurface: Color(0xff161e12),
      onSurfaceVariant: Color(0xff3e4a37),
      outline: Color(0xff6d7b65),
      outlineVariant: Color(0xffbccbb1),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2a3326),
      inversePrimary: Color(0xff53e325),
      primaryFixed: Color(0xff7bff51),
      onPrimaryFixed: Color(0xff042100),
      primaryFixedDim: Color(0xff53e325),
      onPrimaryFixedVariant: Color(0xff135200),
      secondaryFixed: Color(0xffa5f786),
      onSecondaryFixed: Color(0xff042100),
      secondaryFixedDim: Color(0xff8ada6d),
      onSecondaryFixedVariant: Color(0xff135200),
      tertiaryFixed: Color(0xff5cfbd7),
      onTertiaryFixed: Color(0xff002019),
      tertiaryFixedDim: Color(0xff33debb),
      onTertiaryFixedVariant: Color(0xff005142),
      surfaceDim: Color(0xffd4ddca),
      surfaceBright: Color(0xfff3fde8),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffedf7e3),
      surfaceContainer: Color(0xffe7f1dd),
      surfaceContainerHigh: Color(0xffe2ebd8),
      surfaceContainerHighest: Color(0xffdce6d2),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff0d4000),
      surfaceTint: Color(0xff1c6d00),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff227e00),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff0d4000),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff327c1a),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff003e32),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff007c66),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff740006),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffcf2c27),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfff3fde8),
      onSurface: Color(0xff0b1308),
      onSurfaceVariant: Color(0xff2d3a27),
      outline: Color(0xff495642),
      outlineVariant: Color(0xff63715b),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2a3326),
      inversePrimary: Color(0xff53e325),
      primaryFixed: Color(0xff227e00),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff196200),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff327c1a),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff196200),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff007c66),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff00604f),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffc0cab7),
      surfaceBright: Color(0xfff3fde8),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffedf7e3),
      surfaceContainer: Color(0xffe2ebd8),
      surfaceContainerHigh: Color(0xffd6e0cd),
      surfaceContainerHighest: Color(0xffcbd5c2),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme());
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff093400),
      surfaceTint: Color(0xff1c6d00),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff145500),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff093400),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff145500),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff003329),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff005344),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff600004),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff98000a),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfff3fde8),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff000000),
      outline: Color(0xff232f1e),
      outlineVariant: Color(0xff404d39),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2a3326),
      inversePrimary: Color(0xff53e325),
      primaryFixed: Color(0xff145500),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff0b3c00),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff145500),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff0b3c00),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff005344),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff003a2f),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffb2bca9),
      surfaceBright: Color(0xfff3fde8),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffeaf4e0),
      surfaceContainer: Color(0xffdce6d2),
      surfaceContainerHigh: Color(0xffced8c4),
      surfaceContainerHighest: Color(0xffc0cab7),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xff5fee32),
      surfaceTint: Color(0xff53e325),
      onPrimary: Color(0xff0b3900),
      primaryContainer: Color(0xff40d107),
      onPrimaryContainer: Color(0xff135300),
      secondary: Color(0xff8ada6d),
      onSecondary: Color(0xff0b3900),
      secondaryContainer: Color(0xff1c6802),
      onSecondaryContainer: Color(0xff95e576),
      tertiary: Color(0xff44eac6),
      onTertiary: Color(0xff00382d),
      tertiaryContainer: Color(0xff00cdab),
      onTertiaryContainer: Color(0xff005142),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff0e150a),
      onSurface: Color(0xffdce6d2),
      onSurfaceVariant: Color(0xffbccbb1),
      outline: Color(0xff87957d),
      outlineVariant: Color(0xff3e4a37),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffdce6d2),
      inversePrimary: Color(0xff1c6d00),
      primaryFixed: Color(0xff7bff51),
      onPrimaryFixed: Color(0xff042100),
      primaryFixedDim: Color(0xff53e325),
      onPrimaryFixedVariant: Color(0xff135200),
      secondaryFixed: Color(0xffa5f786),
      onSecondaryFixed: Color(0xff042100),
      secondaryFixedDim: Color(0xff8ada6d),
      onSecondaryFixedVariant: Color(0xff135200),
      tertiaryFixed: Color(0xff5cfbd7),
      onTertiaryFixed: Color(0xff002019),
      tertiaryFixedDim: Color(0xff33debb),
      onTertiaryFixedVariant: Color(0xff005142),
      surfaceDim: Color(0xff0e150a),
      surfaceBright: Color(0xff333c2e),
      surfaceContainerLowest: Color(0xff091006),
      surfaceContainerLow: Color(0xff161e12),
      surfaceContainer: Color(0xff1a2216),
      surfaceContainerHigh: Color(0xff242c1f),
      surfaceContainerHighest: Color(0xff2f372a),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xff6bfa3e),
      surfaceTint: Color(0xff53e325),
      onPrimary: Color(0xff072d00),
      primaryContainer: Color(0xff40d107),
      onPrimaryContainer: Color(0xff083200),
      secondary: Color(0xff9ff180),
      onSecondary: Color(0xff072d00),
      secondaryContainer: Color(0xff56a23c),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xff54f5d1),
      onTertiary: Color(0xff002c23),
      tertiaryContainer: Color(0xff00cdab),
      onTertiaryContainer: Color(0xff003027),
      error: Color(0xffffd2cc),
      onError: Color(0xff540003),
      errorContainer: Color(0xffff5449),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff0e150a),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffd2e1c6),
      outline: Color(0xffa8b69d),
      outlineVariant: Color(0xff86957d),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffdce6d2),
      inversePrimary: Color(0xff145400),
      primaryFixed: Color(0xff7bff51),
      onPrimaryFixed: Color(0xff021500),
      primaryFixedDim: Color(0xff53e325),
      onPrimaryFixedVariant: Color(0xff0d4000),
      secondaryFixed: Color(0xffa5f786),
      onSecondaryFixed: Color(0xff021500),
      secondaryFixedDim: Color(0xff8ada6d),
      onSecondaryFixedVariant: Color(0xff0d4000),
      tertiaryFixed: Color(0xff5cfbd7),
      onTertiaryFixed: Color(0xff00150f),
      tertiaryFixedDim: Color(0xff33debb),
      onTertiaryFixedVariant: Color(0xff003e32),
      surfaceDim: Color(0xff0e150a),
      surfaceBright: Color(0xff3e4739),
      surfaceContainerLowest: Color(0xff030902),
      surfaceContainerLow: Color(0xff182014),
      surfaceContainer: Color(0xff222a1d),
      surfaceContainerHigh: Color(0xff2c3528),
      surfaceContainerHighest: Color(0xff374032),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme());
  }

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffc9ffaf),
      surfaceTint: Color(0xff53e325),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xff4fde20),
      onPrimaryContainer: Color(0xff010f00),
      secondary: Color(0xffc9ffaf),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xff87d669),
      onSecondaryContainer: Color(0xff010f00),
      tertiary: Color(0xffb3ffe8),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xff2bdab8),
      onTertiaryContainer: Color(0xff000e0a),
      error: Color(0xffffece9),
      onError: Color(0xff000000),
      errorContainer: Color(0xffffaea4),
      onErrorContainer: Color(0xff220001),
      surface: Color(0xff0e150a),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffffffff),
      outline: Color(0xffe6f5d9),
      outlineVariant: Color(0xffb8c7ae),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffdce6d2),
      inversePrimary: Color(0xff145400),
      primaryFixed: Color(0xff7bff51),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xff53e325),
      onPrimaryFixedVariant: Color(0xff021500),
      secondaryFixed: Color(0xffa5f786),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xff8ada6d),
      onSecondaryFixedVariant: Color(0xff021500),
      tertiaryFixed: Color(0xff5cfbd7),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xff33debb),
      onTertiaryFixedVariant: Color(0xff00150f),
      surfaceDim: Color(0xff0e150a),
      surfaceBright: Color(0xff4a5344),
      surfaceContainerLowest: Color(0xff000000),
      surfaceContainerLow: Color(0xff1a2216),
      surfaceContainer: Color(0xff2a3326),
      surfaceContainerHigh: Color(0xff353e30),
      surfaceContainerHighest: Color(0xff41493b),
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
     scaffoldBackgroundColor: colorScheme.background,
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
