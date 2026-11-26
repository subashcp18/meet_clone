import 'package:flutter/material.dart';

abstract final class AppColors {
  // region: BRAND & STATUS
  static const Color primaryBlue = Color(0xFF1A73E8);
  static const Color primaryBlueDark = Color(0xFF8AB4F8);
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color onPrimaryDark = Color(0xFF062E6F);
  static const Color primaryContainerLight = Color(0xFFD3E3FD);
  static const Color primaryContainerDark = Color(0xFF0842A0);
  static const Color onPrimaryContainerLight = Color(0xFF041E49);
  static const Color onPrimaryContainerDark = Color(0xFFD3E3FD);

  static const Color joinGreen = Color(0xFF1E8E3E);
  static const Color joinGreenDark = Color(0xFF81C995);
  static const Color endCallRed = Color(0xFFD93025);
  static const Color endCallRedDark = Color(0xFFF28B82);
  static const Color warningAmber = Color(0xFFF9AB00);
  // endregion

  // region: NEUTRALS & CALL SURFACES
  static const Color callBackground = Color(0xFF202124);
  static const Color tileSurface = Color(0xFF3C4043);
  static const Color callControlSurface = Color(0xFF2D2E30);

  static const Color white = Color(0xFFFFFFFF);
  static const Color grey50 = Color(0xFFF8F9FA);
  static const Color grey100 = Color(0xFFF1F3F4);
  static const Color grey200 = Color(0xFFE8EAED);
  static const Color grey300 = Color(0xFFDADCE0);
  static const Color grey400 = Color(0xFFBDC1C6);
  static const Color grey500 = Color(0xFF9AA0A6);
  static const Color grey600 = Color(0xFF80868B);
  static const Color grey700 = Color(0xFF5F6368);
  static const Color grey800 = Color(0xFF3C4043);
  static const Color grey900 = Color(0xFF202124);

  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLow = Color(0xFFF8F9FA);
  static const Color lightSurfaceContainer = Color(0xFFF1F3F4);
  static const Color lightSurfaceHigh = Color(0xFFE8EAED);
  static const Color lightOnSurface = Color(0xFF202124);
  static const Color lightOnSurfaceVariant = Color(0xFF5F6368);
  static const Color lightOutline = Color(0xFFDADCE0);
  static const Color lightOutlineVariant = Color(0xFFE8EAED);

  static const Color darkSurface = Color(0xFF202124);
  static const Color darkSurfaceLow = Color(0xFF28292C);
  static const Color darkSurfaceContainer = Color(0xFF303134);
  static const Color darkSurfaceHigh = Color(0xFF3C4043);
  static const Color darkOnSurface = Color(0xFFE8EAED);
  static const Color darkOnSurfaceVariant = Color(0xFF9AA0A6);
  static const Color darkOutline = Color(0xFF5F6368);
  static const Color darkOutlineVariant = Color(0xFF3C4043);
  // endregion
}

@immutable
class AppColorPalette extends ThemeExtension<AppColorPalette> {
  const AppColorPalette({
    required this.primary,
    required this.joinGreen,
    required this.endCallRed,
    required this.warningAmber,
    required this.callBackground,
    required this.tileSurface,
    required this.callControlSurface,
    required this.surface,
    required this.surfaceVariant,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
  });

  final Color primary;
  final Color joinGreen;
  final Color endCallRed;
  final Color warningAmber;
  final Color callBackground;
  final Color tileSurface;
  final Color callControlSurface;
  final Color surface;
  final Color surfaceVariant;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;

  static const AppColorPalette light = AppColorPalette(
    primary: AppColors.primaryBlue,
    joinGreen: AppColors.joinGreen,
    endCallRed: AppColors.endCallRed,
    warningAmber: AppColors.warningAmber,
    callBackground: AppColors.callBackground,
    tileSurface: AppColors.tileSurface,
    callControlSurface: AppColors.callControlSurface,
    surface: AppColors.lightSurface,
    surfaceVariant: AppColors.lightSurfaceContainer,
    onSurface: AppColors.lightOnSurface,
    onSurfaceVariant: AppColors.lightOnSurfaceVariant,
    outline: AppColors.lightOutline,
  );

  static const AppColorPalette dark = AppColorPalette(
    primary: AppColors.primaryBlueDark,
    joinGreen: AppColors.joinGreenDark,
    endCallRed: AppColors.endCallRedDark,
    warningAmber: AppColors.warningAmber,
    callBackground: AppColors.callBackground,
    tileSurface: AppColors.tileSurface,
    callControlSurface: AppColors.callControlSurface,
    surface: AppColors.darkSurface,
    surfaceVariant: AppColors.darkSurfaceContainer,
    onSurface: AppColors.darkOnSurface,
    onSurfaceVariant: AppColors.darkOnSurfaceVariant,
    outline: AppColors.darkOutline,
  );

  @override
  AppColorPalette copyWith({
    Color? primary,
    Color? joinGreen,
    Color? endCallRed,
    Color? warningAmber,
    Color? callBackground,
    Color? tileSurface,
    Color? callControlSurface,
    Color? surface,
    Color? surfaceVariant,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? outline,
  }) {
    return AppColorPalette(
      primary: primary ?? this.primary,
      joinGreen: joinGreen ?? this.joinGreen,
      endCallRed: endCallRed ?? this.endCallRed,
      warningAmber: warningAmber ?? this.warningAmber,
      callBackground: callBackground ?? this.callBackground,
      tileSurface: tileSurface ?? this.tileSurface,
      callControlSurface: callControlSurface ?? this.callControlSurface,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      outline: outline ?? this.outline,
    );
  }

  @override
  AppColorPalette lerp(ThemeExtension<AppColorPalette>? other, double t) {
    if (other is! AppColorPalette) {
      return this;
    }
    return AppColorPalette(
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      joinGreen: Color.lerp(joinGreen, other.joinGreen, t) ?? joinGreen,
      endCallRed: Color.lerp(endCallRed, other.endCallRed, t) ?? endCallRed,
      warningAmber: Color.lerp(warningAmber, other.warningAmber, t) ?? warningAmber,
      callBackground:
          Color.lerp(callBackground, other.callBackground, t) ?? callBackground,
      tileSurface: Color.lerp(tileSurface, other.tileSurface, t) ?? tileSurface,
      callControlSurface:
          Color.lerp(callControlSurface, other.callControlSurface, t) ??
              callControlSurface,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceVariant:
          Color.lerp(surfaceVariant, other.surfaceVariant, t) ?? surfaceVariant,
      onSurface: Color.lerp(onSurface, other.onSurface, t) ?? onSurface,
      onSurfaceVariant:
          Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t) ??
              onSurfaceVariant,
      outline: Color.lerp(outline, other.outline, t) ?? outline,
    );
  }
}
