import 'package:flutter/material.dart';

import '../utils/extensions.dart';
import '../utils/formatters.dart';

class AppUserAvatar extends StatelessWidget {
  const AppUserAvatar({
    super.key,
    required this.nameOrEmail,
    this.radius = 18,
    this.onTap,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String nameOrEmail;
  final double radius;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final textStyles = context.textStyles;
    final initials = Formatters.initialsFromName(nameOrEmail);

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? colorScheme.primaryContainer,
      foregroundColor: foregroundColor ?? colorScheme.onPrimaryContainer,
      child: Text(
        initials,
        style: textStyles.labelMedium.copyWith(
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w600,
          color: foregroundColor ?? colorScheme.onPrimaryContainer,
        ),
      ),
    );

    if (onTap == null) {
      return avatar;
    }

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: avatar,
    );
  }
}
