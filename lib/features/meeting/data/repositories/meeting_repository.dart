import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/network/dio_client.dart';
import '../models/chat_message_model.dart';
import '../models/meeting_lobby_info.dart';
import '../models/participant_model.dart';

part 'meeting_repository.g.dart';

abstract interface class MeetingRepository {
  Future<Result<MeetingLobbyInfo>> getLobbyInfo(String code);
  Future<Result<List<ParticipantModel>>> joinMeeting(
    String code, {
    required bool micOn,
    required bool cameraOn,
  });
  Future<Result<void>> leaveMeeting(String code);
  Future<Result<void>> muteParticipant(String code, String participantId);
  Future<Result<void>> removeParticipant(String code, String participantId);
  Future<Result<List<ChatMessageModel>>> getChatMessages(String code);
  Future<Result<ChatMessageModel>> sendChatMessage(String code, String text);
}

class MockMeetingRepository implements MeetingRepository {
  static const List<ParticipantModel> _defaultParticipants = [
    ParticipantModel(
      id: 'p-1',
      name: 'Alex Morgan',
      email: 'alex.morgan@example.com',
      isHost: true,
      isSpeaking: true,
    ),
    ParticipantModel(
      id: 'p-2',
      name: 'Sam Rivera',
      email: 'sam.rivera@example.com',
      isMuted: true,
    ),
    ParticipantModel(
      id: 'p-3',
      name: 'Jordan Lee',
      email: 'jordan.lee@example.com',
      isVideoOn: false,
      isHandRaised: true,
    ),
    ParticipantModel(
      id: 'p-4',
      name: 'Taylor Kim',
      email: 'taylor.kim@example.com',
    ),
  ];

  @override
  Future<Result<MeetingLobbyInfo>> getLobbyInfo(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final title = switch (code) {
      'abc-defg-hij' => 'Product Design Sync',
      'kmn-pqrs-tuv' => 'Flutter Architecture Review',
      'wxy-zabc-def' => 'Weekly Sprint Planning',
      _ => 'Meeting ($code)',
    };
    return Success(
      MeetingLobbyInfo(
        code: code,
        title: title,
        waitingParticipants: _defaultParticipants,
      ),
    );
  }

  @override
  Future<Result<List<ParticipantModel>>> joinMeeting(
    String code, {
    required bool micOn,
    required bool cameraOn,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return Success([
      ParticipantModel(
        id: 'p-self',
        name: 'You',
        email: 'you@example.com',
        isSelf: true,
        isMuted: !micOn,
        isVideoOn: cameraOn,
      ),
      ..._defaultParticipants,
    ]);
  }

  @override
  Future<Result<void>> leaveMeeting(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return const Success(null);
  }

  @override
  Future<Result<void>> muteParticipant(String code, String participantId) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return const Success(null);
  }

  @override
  Future<Result<void>> removeParticipant(
    String code,
    String participantId,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return const Success(null);
  }

  @override
  Future<Result<List<ChatMessageModel>>> getChatMessages(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final now = DateTime.now();
    return Success([
      ChatMessageModel(
        id: 'c-1',
        senderId: 'p-1',
        senderName: 'Alex Morgan',
        text: 'Welcome everyone! Let us kick off once everyone has joined.',
        sentAt: now.subtract(const Duration(minutes: 2)),
      ),
      ChatMessageModel(
        id: 'c-2',
        senderId: 'p-2',
        senderName: 'Sam Rivera',
        text: 'Sharing the updated wireframes in a moment.',
        sentAt: now.subtract(const Duration(minutes: 1)),
      ),
    ]);
  }

  @override
  Future<Result<ChatMessageModel>> sendChatMessage(
    String code,
    String text,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final now = DateTime.now();
    return Success(
      ChatMessageModel(
        id: 'c-${now.microsecondsSinceEpoch}',
        senderId: 'p-self',
        senderName: 'You',
        text: text.trim(),
        sentAt: now,
        isSelf: true,
      ),
    );
  }
}

class RemoteMeetingRepository extends BaseRepository implements MeetingRepository {
  const RemoteMeetingRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<MeetingLobbyInfo>> getLobbyInfo(String code) {
    return guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.meetingByCode(code),
      );
      return MeetingLobbyInfo.fromJson(
        response.data ?? const <String, dynamic>{},
      );
    });
  }

  @override
  Future<Result<List<ParticipantModel>>> joinMeeting(
    String code, {
    required bool micOn,
    required bool cameraOn,
  }) {
    return guard(() async {
      final response = await _dio.post<List<dynamic>>(
        ApiEndpoints.joinMeeting(code),
        data: {
          'mic_on': micOn,
          'camera_on': cameraOn,
        },
      );
      final items = response.data ?? const <dynamic>[];
      return items
          .whereType<Map<String, dynamic>>()
          .map(ParticipantModel.fromJson)
          .toList();
    });
  }

  @override
  Future<Result<void>> leaveMeeting(String code) {
    return guard(() async {
      await _dio.post<void>(ApiEndpoints.leaveMeeting(code));
    });
  }

  @override
  Future<Result<void>> muteParticipant(String code, String participantId) {
    return guard(() async {
      await _dio.post<void>(ApiEndpoints.muteParticipant(code, participantId));
    });
  }

  @override
  Future<Result<void>> removeParticipant(String code, String participantId) {
    return guard(() async {
      await _dio.delete<void>(
        ApiEndpoints.removeParticipant(code, participantId),
      );
    });
  }

  @override
  Future<Result<List<ChatMessageModel>>> getChatMessages(String code) {
    return guard(() async {
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.chatMessages(code),
      );
      final items = response.data ?? const <dynamic>[];
      return items
          .whereType<Map<String, dynamic>>()
          .map(ChatMessageModel.fromJson)
          .toList();
    });
  }

  @override
  Future<Result<ChatMessageModel>> sendChatMessage(String code, String text) {
    return guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.sendChatMessage(code),
        data: {'text': text.trim()},
      );
      return ChatMessageModel.fromJson(
        response.data ?? const <String, dynamic>{},
      );
    });
  }
}

@Riverpod(keepAlive: true)
MeetingRepository meetingRepository(Ref ref) {
  final useMock = ref.watch(useMockApiProvider);
  if (useMock) {
    return MockMeetingRepository();
  }
  return RemoteMeetingRepository(ref.watch(dioClientProvider));
}
