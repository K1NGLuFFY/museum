import 'package:flutter/cupertino.dart';

abstract final class MuseumColors {
  static const background = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF8F7F4),
    darkColor: Color(0xFF111111),
  );
  static const surface = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF1C1C1E),
  );
  static const ink = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF191919),
    darkColor: Color(0xFFF5F4F1),
  );
  static const secondary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF77736F),
    darkColor: Color(0xFFA6A4A1),
  );
  static const accent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF783F45),
    darkColor: Color(0xFFC48D93),
  );
  static const divider = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE7E3DD),
    darkColor: Color(0xFF353437),
  );

  static Color resolve(Color color, BuildContext context) =>
      CupertinoDynamicColor.resolve(color, context);
}

CupertinoThemeData museumTheme(Brightness? brightness) => CupertinoThemeData(
  brightness: brightness,
  primaryColor: MuseumColors.accent,
  scaffoldBackgroundColor: MuseumColors.background,
  barBackgroundColor: MuseumColors.background,
  textTheme: const CupertinoTextThemeData(
    primaryColor: MuseumColors.accent,
    textStyle: TextStyle(
      color: MuseumColors.ink,
      fontSize: 16,
      height: 1.45,
      fontFamilyFallback: ['Roboto', 'Arial'],
    ),
    navTitleTextStyle: TextStyle(
      color: MuseumColors.ink,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
    navLargeTitleTextStyle: TextStyle(
      color: MuseumColors.ink,
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
    ),
  ),
);
