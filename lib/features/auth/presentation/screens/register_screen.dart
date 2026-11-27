import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_brand_mark.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/auth_primary_button.dart';
import '../../../../core/widgets/auth_text_field.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  // region: CONTROLLERS
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  // endregion

  // region: ACTIONS
  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final outcome = await ref
        .read(registerControllerProvider.notifier)
        .submit(
          fullName: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    switch (outcome) {
      case RegisterOutcome.signedIn:
        return;
      case RegisterOutcome.confirmationRequired:
        await _showConfirmationDialog();
        if (mounted) {
          context.pop();
        }
      case RegisterOutcome.failed:
        final error = ref.read(registerControllerProvider).errorMessage;
        if (error != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error)));
        }
    }
  }

  Future<void> _showConfirmationDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Check your email'),
        content: Text(
          'We sent a confirmation link to ${_emailController.text.trim()}. '
          'Verify your email address, then sign in.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  // endregion

  // region: BUILD
  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(registerControllerProvider);
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Create account'),
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
                  child: AutofillGroup(
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
                            'Create your account',
                            style: textStyles.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start hosting and joining video meetings in seconds',
                            style: textStyles.bodyMedium.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          AuthTextField(
                            controller: _nameController,
                            enabled: !formState.isLoading,
                            label: 'Full name',
                            hintText: 'Alex Morgan',
                            prefixIcon: Icons.person_outline_rounded,
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: Validators.fullName,
                            onChanged: (_) => ref
                                .read(registerControllerProvider.notifier)
                                .clearError(),
                          ),
                          const SizedBox(height: 16),
                          AuthTextField(
                            controller: _emailController,
                            enabled: !formState.isLoading,
                            label: 'Email',
                            hintText: 'name@example.com',
                            prefixIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: Validators.email,
                            onChanged: (_) => ref
                                .read(registerControllerProvider.notifier)
                                .clearError(),
                          ),
                          const SizedBox(height: 16),
                          AuthTextField(
                            controller: _passwordController,
                            enabled: !formState.isLoading,
                            label: 'Password',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: true,
                            enableObscureToggle: true,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: Validators.password,
                            onChanged: (_) => ref
                                .read(registerControllerProvider.notifier)
                                .clearError(),
                          ),
                          const SizedBox(height: 16),
                          AuthTextField(
                            controller: _confirmPasswordController,
                            enabled: !formState.isLoading,
                            label: 'Confirm password',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: true,
                            enableObscureToggle: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (value) => Validators.confirmPassword(
                              value,
                              _passwordController.text,
                            ),
                            onChanged: (_) => ref
                                .read(registerControllerProvider.notifier)
                                .clearError(),
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          if (formState.errorMessage != null) ...[
                            const SizedBox(height: 16),
                            AppErrorBanner(message: formState.errorMessage!),
                          ],
                          const SizedBox(height: 24),
                          AuthPrimaryButton(
                            label: 'Create account',
                            isLoading: formState.isLoading,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Already have an account?',
                                style: textStyles.bodyMedium.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              TextButton(
                                onPressed: formState.isLoading
                                    ? null
                                    : () => context.pop(),
                                child: const Text('Sign in'),
                              ),
                            ],
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
      ),
    );
  }
  // endregion
}
