import 'package:flutter/material.dart';

import '../utils/extensions.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.size = 28,
    this.message,
  });

  final double size;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: context.colors.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: context.textStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
