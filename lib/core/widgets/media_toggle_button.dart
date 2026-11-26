import 'package:flutter/material.dart';

import '../utils/extensions.dart';

class MediaToggleButton extends StatelessWidget {
  const MediaToggleButton({
    super.key,
    required this.isActive,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.tooltip,
    required this.onPressed,
    this.size = 48,
    this.activeBackgroundColor,
    this.inactiveBackgroundColor,
    this.activeForegroundColor,
    this.inactiveForegroundColor,
  });

  final bool isActive;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final Color? activeBackgroundColor;
  final Color? inactiveBackgroundColor;
  final Color? activeForegroundColor;
  final Color? inactiveForegroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colorScheme = context.colorScheme;

    final backgroundColor = isActive
        ? (activeBackgroundColor ?? colorScheme.surfaceContainerHigh)
        : (inactiveBackgroundColor ?? colors.endCallRed);
    final foregroundColor = isActive
        ? (activeForegroundColor ?? colors.onSurface)
        : (inactiveForegroundColor ?? colorScheme.onError);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              isActive ? activeIcon : inactiveIcon,
              color: foregroundColor,
              size: size * 0.46,
            ),
          ),
        ),
      ),
    );
  }
}
