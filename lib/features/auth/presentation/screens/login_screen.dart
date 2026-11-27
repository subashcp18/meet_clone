import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/supabase_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_brand_mark.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/auth_primary_button.dart';
import '../../../../core/widgets/auth_text_field.dart';
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
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
        .read(loginControllerProvider.notifier)
        .submit(
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (!mounted || succeeded) {
      return;
    }
    final error = ref.read(loginControllerProvider).errorMessage;
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
    final formState = ref.watch(loginControllerProvider);
    final useMockApi = ref.watch(useMockApiProvider);
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Scaffold(
      backgroundColor: colors.surface,
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
                          const SizedBox(height: 24),
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
                                .read(loginControllerProvider.notifier)
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
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            validator: Validators.password,
                            onChanged: (_) => ref
                                .read(loginControllerProvider.notifier)
                                .clearError(),
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: formState.isLoading
                                  ? null
                                  : () => context.pushNamed(
                                        RouteNames.forgotPassword,
                                      ),
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          if (formState.errorMessage != null) ...[
                            const SizedBox(height: 8),
                            AppErrorBanner(message: formState.errorMessage!),
                          ],
                          const SizedBox(height: 16),
                          AuthPrimaryButton(
                            label: 'Sign in',
                            isLoading: formState.isLoading,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'New here?',
                                style: textStyles.bodyMedium.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              TextButton(
                                onPressed: formState.isLoading
                                    ? null
                                    : () => context.pushNamed(
                                          RouteNames.register,
                                        ),
                                child: const Text('Create account'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            useMockApi
                                ? 'Mock authentication is active.'
                                : 'Connected to Supabase.',
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
      ),
    );
  }
  // endregion
}
