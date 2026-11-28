import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../meeting/providers/meeting_session_provider.dart';

class JoinWithCodeScreen extends ConsumerStatefulWidget {
  const JoinWithCodeScreen({super.key});

  @override
  ConsumerState<JoinWithCodeScreen> createState() => _JoinWithCodeScreenState();
}

class _JoinWithCodeScreenState extends ConsumerState<JoinWithCodeScreen> {
  // region: CONTROLLERS & STATE
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _codeController
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }
  // endregion

  // region: ACTIONS
  void _onTextChanged() {
    setState(() {
      if (_errorMessage != null) {
        _errorMessage = null;
      }
    });
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final code = Validators.extractMeetingCode(_codeController.text);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      ref.invalidate(meetingPreviewProvider(code));
      final preview = await ref.read(meetingPreviewProvider(code).future);
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      context.pushReplacement(RouteNames.lobbyLocation(preview.code));
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = ApiException.friendlyMessage(error);
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }
  // endregion

  // region: BUILD
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final hasInput = _codeController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join with a code'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: hasInput && !_isLoading ? _submit : null,
              child: const Text('Join'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Enter the code provided by the meeting organizer',
                      style: textStyles.bodyMedium.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _codeController,
                      autofocus: true,
                      enabled: !_isLoading,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      validator: Validators.meetingCode,
                      onFieldSubmitted: (_) => _submit(),
                      style: textStyles.meetingCode,
                      decoration: InputDecoration(
                        labelText: 'Meeting code or link',
                        hintText: 'Example: abc-defg-hij',
                        prefixIcon: const Icon(Icons.keyboard_rounded),
                        suffixIcon: hasInput
                            ? IconButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => _codeController.clear(),
                                tooltip: 'Clear',
                                icon: const Icon(Icons.close_rounded),
                              )
                            : null,
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      AppErrorBanner(message: _errorMessage!),
                    ],
                    const SizedBox(height: 24),
                    AppPrimaryButton(
                      label: 'Join meeting',
                      isLoading: _isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'You can also paste a full Meet link such as https://meet.clone/abc-defg-hij.',
                      style: textStyles.caption,
                    ),
                  ],
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
