import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/network/supabase_provider.dart';
import '../../../auth/data/models/profile.dart';
import '../models/chat_message.dart';

part 'chat_repository.g.dart';

abstract interface class ChatRepository {
  Stream<List<ChatMessage>> watchMessages(String meetingId);

  Future<Result<ChatMessage>> send(String meetingId, String body);
}

class MockChatRepository implements ChatRepository {
  final Map<String, List<ChatMessage>> _store = {};
  final Map<String, StreamController<List<ChatMessage>>> _controllers = {};

  List<ChatMessage> _ensureMessages(String meetingId) {
    return _store.putIfAbsent(meetingId, () {
      final now = DateTime.now();
      return [
        ChatMessage(
          id: 'c-1',
          meetingId: meetingId,
          userId: 'p-1',
          senderName: 'Alex Morgan',
          body: 'Welcome everyone! Let us kick off once everyone has joined.',
          createdAt: now.subtract(const Duration(minutes: 2)),
        ),
        ChatMessage(
          id: 'c-2',
          meetingId: meetingId,
          userId: 'p-2',
          senderName: 'Sam Rivera',
          body: 'Sharing the updated wireframes in a moment.',
          createdAt: now.subtract(const Duration(minutes: 1)),
        ),
      ];
    });
  }

  StreamController<List<ChatMessage>> _controllerFor(String meetingId) {
    return _controllers.putIfAbsent(
      meetingId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String meetingId) async* {
    yield List<ChatMessage>.unmodifiable(_ensureMessages(meetingId));
    yield* _controllerFor(meetingId).stream;
  }

  @override
  Future<Result<ChatMessage>> send(String meetingId, String body) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final now = DateTime.now();
    final message = ChatMessage(
      id: 'c-${now.microsecondsSinceEpoch}',
      meetingId: meetingId,
      userId: 'u-mock',
      senderName: 'You',
      body: body.trim(),
      createdAt: now,
      isSelf: true,
    );
    final updated = [..._ensureMessages(meetingId), message];
    _store[meetingId] = updated;
    _controllerFor(meetingId).add(List<ChatMessage>.unmodifiable(updated));
    return Success(message);
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
}

class SupabaseChatRepository extends BaseRepository implements ChatRepository {
  SupabaseChatRepository(this._client);

  final SupabaseClient _client;
  final Map<String, Profile> _profileCache = {};

  @override
  Stream<List<ChatMessage>> watchMessages(String meetingId) {
    final stream = _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('meeting_id', meetingId)
        .order('created_at', ascending: true);

    return stream.asyncMap((rows) async {
      final missingIds = rows
          .map((r) => r['user_id'] as String?)
          .whereType<String>()
          .where((id) => !_profileCache.containsKey(id))
          .toSet()
          .toList();

      if (missingIds.isNotEmpty) {
        final profiles = await _client
            .from('profiles')
            .select()
            .inFilter('id', missingIds);
        for (final row in profiles) {
          final profile = Profile.fromJson(row);
          _profileCache[profile.id] = profile;
        }
      }

      final currentUid = _client.auth.currentUser?.id;
      return rows.map((row) {
        final message = ChatMessage.fromJson(row);
        final isSelf = message.userId == currentUid;
        final profile = _profileCache[message.userId];
        return message.copyWith(
          senderName: isSelf ? 'You' : (profile?.displayName ?? 'Participant'),
          isSelf: isSelf,
        );
      }).toList();
    });
  }

  @override
  Future<Result<ChatMessage>> send(String meetingId, String body) {
    return guard(() async {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        throw const UnauthorizedException();
      }
      final row = await _client
          .from('chat_messages')
          .insert({
            'meeting_id': meetingId,
            'user_id': uid,
            'body': body.trim(),
          })
          .select()
          .single();

      return ChatMessage.fromJson(row).copyWith(
        senderName: 'You',
        isSelf: true,
      );
    });
  }
}

@Riverpod(keepAlive: true)
ChatRepository chatRepository(Ref ref) {
  final useMock = ref.watch(useMockApiProvider);
  if (useMock) {
    final repo = MockChatRepository();
    ref.onDispose(repo.dispose);
    return repo;
  }
  return SupabaseChatRepository(ref.watch(supabaseClientProvider));
}
