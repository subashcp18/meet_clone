import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

extension BuildContextThemeX on BuildContext {
  AppTextStyles get textStyles => AppTextStyles.of(this);

  AppColorPalette get colors {
    final extension = Theme.of(this).extension<AppColorPalette>();
    if (extension != null) {
      return extension;
    }
    return Theme.of(this).brightness == Brightness.dark
        ? AppColorPalette.dark
        : AppColorPalette.light;
  }

  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}
