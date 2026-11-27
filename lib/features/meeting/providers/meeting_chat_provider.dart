import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/chat_message.dart';
import '../data/repositories/chat_repository.dart';

part 'meeting_chat_provider.g.dart';

@riverpod
Stream<List<ChatMessage>> meetingChat(Ref ref, String meetingId) {
  return ref.watch(chatRepositoryProvider).watchMessages(meetingId);
}
