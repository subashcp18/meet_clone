import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../utils/extensions.dart';

class AppBrandMark extends StatelessWidget {
  const AppBrandMark({
    super.key,
    this.iconSize = 72,
    this.showLabel = true,
  });

  final double iconSize;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colorScheme = context.colorScheme;
    final textStyles = context.textStyles;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(iconSize * 0.28),
            border: Border.all(
              color: colors.outline.withValues(alpha: 0.4),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.videocam_rounded,
                size: iconSize * 0.54,
                color: colors.primary,
              ),
              Positioned(
                right: iconSize * 0.14,
                top: iconSize * 0.14,
                child: Container(
                  width: iconSize * 0.14,
                  height: iconSize * 0.14,
                  decoration: BoxDecoration(
                    color: colors.joinGreen,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 16),
          Text(
            AppConstants.appName,
            style: textStyles.headlineSmall.copyWith(
              color: colors.onSurface,
            ),
          ),
        ],
      ],
    );
  }
}
