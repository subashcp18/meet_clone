import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class AppTextStyles {
  const AppTextStyles._({
    required this.textTheme,
    required this.meetingCode,
    required this.participantName,
    required this.callTimer,
    required this.buttonLabel,
    required this.caption,
  });

  factory AppTextStyles.of(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final scale = responsiveScale(context);
    final scaledTheme = buildTextTheme(colorScheme, scale: scale);

    return AppTextStyles._(
      textTheme: scaledTheme,
      meetingCode: TextStyle(
        fontFamily: AppConstants.fontFamily,
        fontSize: 16 * scale,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        height: 1.35,
        color: colorScheme.onSurface,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      participantName: TextStyle(
        fontFamily: AppConstants.fontFamily,
        fontSize: 13 * scale,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        height: 1.3,
        color: colorScheme.onSurface,
      ),
      callTimer: TextStyle(
        fontFamily: AppConstants.fontFamily,
        fontSize: 13 * scale,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        height: 1.3,
        color: colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      buttonLabel: TextStyle(
        fontFamily: AppConstants.fontFamily,
        fontSize: 14 * scale,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.4,
        color: colorScheme.onPrimary,
      ),
      caption: TextStyle(
        fontFamily: AppConstants.fontFamily,
        fontSize: 12 * scale,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.3,
        height: 1.35,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  // region: FIELDS
  final TextTheme textTheme;
  final TextStyle meetingCode;
  final TextStyle participantName;
  final TextStyle callTimer;
  final TextStyle buttonLabel;
  final TextStyle caption;
  // endregion

  // region: MATERIAL TEXT THEME GETTERS
  TextStyle get displayLarge => textTheme.displayLarge!;
  TextStyle get displayMedium => textTheme.displayMedium!;
  TextStyle get displaySmall => textTheme.displaySmall!;
  TextStyle get headlineLarge => textTheme.headlineLarge!;
  TextStyle get headlineMedium => textTheme.headlineMedium!;
  TextStyle get headlineSmall => textTheme.headlineSmall!;
  TextStyle get titleLarge => textTheme.titleLarge!;
  TextStyle get titleMedium => textTheme.titleMedium!;
  TextStyle get titleSmall => textTheme.titleSmall!;
  TextStyle get bodyLarge => textTheme.bodyLarge!;
  TextStyle get bodyMedium => textTheme.bodyMedium!;
  TextStyle get bodySmall => textTheme.bodySmall!;
  TextStyle get labelLarge => textTheme.labelLarge!;
  TextStyle get labelMedium => textTheme.labelMedium!;
  TextStyle get labelSmall => textTheme.labelSmall!;
  // endregion

  // region: RESPONSIVE HELPERS
  static double responsiveScale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) {
      return 0.92;
    }
    if (width >= 600) {
      return 1.08;
    }
    return 1.0;
  }

  static double scaled(BuildContext context, double baseSize) {
    return baseSize * responsiveScale(context);
  }
  // endregion

  // region: TEXT THEME BUILDER
  static TextTheme buildTextTheme(
    ColorScheme colorScheme, {
    double scale = 1.0,
  }) {
    TextStyle style({
      required double size,
      required FontWeight weight,
      required double height,
      double letterSpacing = 0,
      Color? color,
    }) {
      return TextStyle(
        fontFamily: AppConstants.fontFamily,
        fontSize: size * scale,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        color: color ?? colorScheme.onSurface,
      );
    }

    return TextTheme(
      displayLarge: style(
        size: 57,
        weight: FontWeight.w400,
        height: 1.12,
        letterSpacing: -0.25,
      ),
      displayMedium: style(
        size: 45,
        weight: FontWeight.w400,
        height: 1.16,
      ),
      displaySmall: style(
        size: 36,
        weight: FontWeight.w400,
        height: 1.22,
      ),
      headlineLarge: style(
        size: 32,
        weight: FontWeight.w600,
        height: 1.25,
      ),
      headlineMedium: style(
        size: 28,
        weight: FontWeight.w600,
        height: 1.29,
      ),
      headlineSmall: style(
        size: 24,
        weight: FontWeight.w600,
        height: 1.33,
      ),
      titleLarge: style(
        size: 22,
        weight: FontWeight.w500,
        height: 1.27,
      ),
      titleMedium: style(
        size: 16,
        weight: FontWeight.w600,
        height: 1.5,
        letterSpacing: 0.15,
      ),
      titleSmall: style(
        size: 14,
        weight: FontWeight.w600,
        height: 1.43,
        letterSpacing: 0.1,
      ),
      bodyLarge: style(
        size: 16,
        weight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.2,
      ),
      bodyMedium: style(
        size: 14,
        weight: FontWeight.w400,
        height: 1.43,
        letterSpacing: 0.2,
      ),
      bodySmall: style(
        size: 12,
        weight: FontWeight.w400,
        height: 1.33,
        letterSpacing: 0.3,
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: style(
        size: 14,
        weight: FontWeight.w600,
        height: 1.43,
        letterSpacing: 0.1,
      ),
      labelMedium: style(
        size: 12,
        weight: FontWeight.w500,
        height: 1.33,
        letterSpacing: 0.4,
      ),
      labelSmall: style(
        size: 11,
        weight: FontWeight.w500,
        height: 1.45,
        letterSpacing: 0.4,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
  // endregion
}
