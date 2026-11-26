import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_brand_mark.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // region: CONTROLLERS
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
  // endregion

  // region: ACTIONS
  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    await ref.read(authProvider.notifier).signIn(_emailController.text);
  }
  // endregion

  // region: BUILD
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: AppBrandMark(
                            iconSize: 56,
                            showLabel: false,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Sign in',
                          style: textStyles.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use your account to join and host video meetings',
                          style: textStyles.bodyMedium.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _emailController,
                          enabled: !authState.isBusy,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.email],
                          validator: Validators.email,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'name@example.com',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                        ),
                        if (authState.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          AppErrorBanner(message: authState.errorMessage!),
                        ],
                        const SizedBox(height: 24),
                        AppPrimaryButton(
                          label: 'Continue',
                          isLoading: authState.isBusy,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Mock authentication is active for Phase 1.',
                          style: textStyles.caption,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  // endregion
}
