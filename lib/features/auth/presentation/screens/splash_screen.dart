import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/app_brand_mark.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  // region: STATE
  bool _hasError = false;
  // endregion

  // region: LIFECYCLE
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSession();
    });
  }
  // endregion

  // region: ACTIONS
  Future<void> _initializeSession() async {
    if (_hasError) {
      setState(() => _hasError = false);
    }
    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) {
        return;
      }
      await ref.read(authProvider.notifier).checkSession();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _hasError = true);
    }
  }
  // endregion

  // region: BUILD
  @override
  Widget build(BuildContext context) {
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
            if (_hasError)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Unable to restore your session',
                    style: textStyles.bodyMedium.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _initializeSession,
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
  // endregion
}
