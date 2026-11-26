import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../data/models/chat_message_model.dart';
import '../../providers/meeting_chat_provider.dart';

class InCallChatSheet extends ConsumerStatefulWidget {
  const InCallChatSheet({
    super.key,
    required this.code,
  });

  final String code;

  static Future<void> show(
    BuildContext context, {
    required String code,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Theme(
        data: AppTheme.callTheme,
        child: InCallChatSheet(code: code),
      ),
    );
  }

  @override
  ConsumerState<InCallChatSheet> createState() => _InCallChatSheetState();
}

class _InCallChatSheetState extends ConsumerState<InCallChatSheet> {
  // region: CONTROLLERS & STATE
  final TextEditingController _messageController = TextEditingController();
  ScrollController? _listController;
  bool _isSending = false;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }
  // endregion

  // region: ACTIONS
  void _onTextChanged() {
    setState(() {
      if (_sendError != null) {
        _sendError = null;
      }
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
      _sendError = null;
    });

    final error = await ref
        .read(meetingChatProvider(widget.code).notifier)
        .sendMessage(text);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSending = false;
      _sendError = error;
    });

    if (error == null) {
      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = _listController;
        if (controller != null && controller.hasClients) {
          controller.jumpTo(controller.position.maxScrollExtent);
        }
      });
    }
  }
  // endregion

  // region: BUILD
  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(meetingChatProvider(widget.code));
    final colors = context.colors;
    final textStyles = context.textStyles;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final canSend = _messageController.text.trim().isNotEmpty && !_isSending;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          _listController = scrollController;
          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'In-call messages',
                        style: textStyles.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.callControlSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Messages are visible only to people in this call.',
                          style: textStyles.caption,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: chatAsync.when(
                    loading: () => const AppLoadingIndicator(
                      message: 'Loading messages...',
                    ),
                    error: (error, _) {
                      final message = error is ApiException
                          ? error.message
                          : 'Unable to load messages.';
                      return AppErrorState(
                        message: message,
                        onRetry: () => ref
                            .read(meetingChatProvider(widget.code).notifier)
                            .refresh(),
                      );
                    },
                    data: (messages) {
                      if (messages.isEmpty) {
                        return const AppEmptyState(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'No messages yet',
                          subtitle: 'Send a message to everyone in the call.',
                        );
                      }
                      return ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        itemCount: messages.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _ChatBubble(message: messages[index]);
                        },
                      );
                    },
                  ),
                ),
                if (_sendError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: AppErrorBanner(message: _sendError!),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 12, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          enabled: !_isSending,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Send a message to everyone',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: canSend ? _send : null,
                        tooltip: 'Send',
                        icon: _isSending
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  // endregion
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colorScheme = context.colorScheme;
    final textStyles = context.textStyles;
    final isSelf = message.isSelf;

    final bubbleColor = isSelf
        ? colorScheme.primaryContainer
        : colors.tileSurface;
    final textColor = isSelf
        ? colorScheme.onPrimaryContainer
        : colors.onSurface;

    return Align(
      alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isSelf ? 16 : 4),
              bottomRight: Radius.circular(isSelf ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.senderName,
                    style: textStyles.labelMedium.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Formatters.formatTime(message.sentAt),
                    style: textStyles.caption.copyWith(
                      color: textColor.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                message.text,
                style: textStyles.bodyMedium.copyWith(color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
