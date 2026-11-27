import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/app_brand_mark.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authControllerProvider);
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Center(
              child: AppBrandMark(iconSize: 80),
            ),
            const SizedBox(height: 32),
            if (authAsync.hasError)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ApiException.friendlyMessage(authAsync.error!),
                    style: textStyles.bodyMedium.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref
                        .read(authControllerProvider.notifier)
                        .retrySessionRestore(),
                    child: const Text('Retry'),
                  ),
                ],
              )
            else
              const AppLoadingIndicator(size: 24),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                'Video meetings for everyone',
                style: textStyles.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
