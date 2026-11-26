import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/chat_message_model.dart';
import '../data/repositories/meeting_repository.dart';

part 'meeting_chat_provider.g.dart';

@Riverpod(keepAlive: true)
class MeetingChatNotifier extends _$MeetingChatNotifier {
  // region: BUILD
  @override
  Future<List<ChatMessageModel>> build(String code) async {
    return _fetchMessages(code);
  }
  // endregion

  // region: ACTIONS
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchMessages(code));
  }

  Future<String?> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final result = await ref
        .read(meetingRepositoryProvider)
        .sendChatMessage(code, trimmed);

    return result.when(
      success: (message) {
        final current = state.asData?.value ?? const <ChatMessageModel>[];
        state = AsyncData([...current, message]);
        return null;
      },
      failure: (exception) => exception.message,
    );
  }

  Future<List<ChatMessageModel>> _fetchMessages(String code) async {
    final result = await ref
        .read(meetingRepositoryProvider)
        .getChatMessages(code);
    return result.when(
      success: (messages) => messages,
      failure: (exception) => throw exception,
    );
  }
  // endregion
}
