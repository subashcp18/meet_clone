import 'package:flutter/material.dart';

import '../utils/extensions.dart';

class AppSheetActionTile extends StatelessWidget {
  const AppSheetActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.isLoading = false,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isLoading;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colorScheme = context.colorScheme;
    final textStyles = context.textStyles;

    return ListTile(
      onTap: isLoading ? null : onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: iconColor ?? colors.onSurface,
        ),
      ),
      title: Text(
        title,
        style: textStyles.titleSmall,
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: textStyles.bodySmall,
            )
          : null,
      trailing: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            )
          : null,
    );
  }
}
