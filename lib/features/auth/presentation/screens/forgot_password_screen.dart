import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_brand_mark.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/auth_primary_button.dart';
import '../../../../core/widgets/auth_text_field.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
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

    final succeeded = await ref
        .read(forgotPasswordControllerProvider.notifier)
        .submit(email: _emailController.text);

    if (!mounted || succeeded) {
      return;
    }

    final error = ref.read(forgotPasswordControllerProvider).errorMessage;
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }
  // endregion

  // region: BUILD
  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(forgotPasswordControllerProvider);
    final colors = context.colors;
    final colorScheme = context.colorScheme;
    final textStyles = context.textStyles;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Reset password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                            iconSize: 48,
                            showLabel: false,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Forgot your password?',
                          style: textStyles.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your email address and we will send you a password reset link.',
                          style: textStyles.bodyMedium.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        AuthTextField(
                          controller: _emailController,
                          enabled: !formState.isLoading,
                          label: 'Email',
                          hintText: 'name@example.com',
                          prefixIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.email],
                          validator: Validators.email,
                          onChanged: (_) => ref
                              .read(forgotPasswordControllerProvider.notifier)
                              .clearFeedback(),
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (formState.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          AppErrorBanner(message: formState.errorMessage!),
                        ],
                        if (formState.isSubmitted) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 18,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Reset link sent to ${_emailController.text.trim()}. Check your inbox.',
                                    style: textStyles.bodySmall.copyWith(
                                      color: colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        AuthPrimaryButton(
                          label: 'Send reset link',
                          isLoading: formState.isLoading,
                          onPressed: _submit,
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
