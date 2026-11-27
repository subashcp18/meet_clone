import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/network/supabase_provider.dart';
import '../models/meeting.dart';
import '../models/meeting_participant.dart';
import '../models/scheduled_meeting.dart';

part 'meeting_repository.g.dart';

abstract interface class MeetingRepository {
  Future<Result<Meeting>> createInstantMeeting();
  Future<Result<Meeting>> scheduleMeeting(ScheduledMeeting request);
  Future<Result<Meeting>> joinByCode(String code);
  Future<Result<void>> leaveMeeting(String meetingId);
  Future<Result<List<Meeting>>> listUpcoming();
  Future<Result<void>> endMeeting(String meetingId);
}

class MockMeetingRepository implements MeetingRepository {
  static const String _alphabet = 'abcdefghijkmnpqrstuvwxyz';
  final Random _random = Random();

  static List<MeetingParticipant> _mockParticipantsFor(String meetingId) => [
    MeetingParticipant(
      meetingId: meetingId,
      userId: 'p-1',
      displayName: 'Alex Morgan',
      email: 'alex.morgan@example.com',
      isHost: true,
      isSpeaking: true,
    ),
    MeetingParticipant(
      meetingId: meetingId,
      userId: 'p-2',
      displayName: 'Sam Rivera',
      email: 'sam.rivera@example.com',
      isMuted: true,
    ),
    MeetingParticipant(
      meetingId: meetingId,
      userId: 'p-3',
      displayName: 'Jordan Lee',
      email: 'jordan.lee@example.com',
      isCameraOff: true,
      handRaised: true,
    ),
    MeetingParticipant(
      meetingId: meetingId,
      userId: 'p-4',
      displayName: 'Taylor Kim',
      email: 'taylor.kim@example.com',
    ),
  ];

  List<Meeting> _mockUpcoming() {
    final now = DateTime.now();
    final todayBase = DateTime(now.year, now.month, now.day, 14, 30);

    return [
      Meeting(
        id: 'm-1',
        title: 'Product Design Sync',
        code: 'abc-defg-hij',
        hostId: 'p-1',
        hostName: 'Alex Morgan',
        scheduledAt: todayBase,
        durationMinutes: 45,
        status: 'live',
        participants: _mockParticipantsFor('m-1'),
      ),
      Meeting(
        id: 'm-2',
        title: 'Flutter Architecture Review',
        code: 'kmn-pqrs-tuv',
        hostId: 'p-2',
        hostName: 'Sam Rivera',
        scheduledAt: todayBase.add(const Duration(hours: 2)),
        durationMinutes: 30,
        status: 'scheduled',
        participants: _mockParticipantsFor('m-2'),
      ),
      Meeting(
        id: 'm-3',
        title: 'Weekly Sprint Planning',
        code: 'wxy-zabc-def',
        hostId: 'p-3',
        hostName: 'Jordan Lee',
        scheduledAt: todayBase.add(const Duration(days: 1, hours: -4)),
        durationMinutes: 60,
        status: 'scheduled',
        participants: _mockParticipantsFor('m-3'),
      ),
    ];
  }

  @override
  Future<Result<Meeting>> createInstantMeeting() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final code = '${_segment(3)}-${_segment(4)}-${_segment(3)}';
    final now = DateTime.now();
    return Success(
      Meeting(
        id: 'm-${now.millisecondsSinceEpoch}',
        title: 'Instant meeting',
        code: code,
        hostId: 'u-mock',
        hostName: 'You',
        isInstant: true,
        status: 'live',
        createdAt: now,
        durationMinutes: 60,
      ),
    );
  }

  @override
  Future<Result<Meeting>> scheduleMeeting(ScheduledMeeting request) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final code = '${_segment(3)}-${_segment(4)}-${_segment(3)}';
    return Success(
      Meeting(
        id: 'm-${DateTime.now().millisecondsSinceEpoch}',
        title: request.title.trim(),
        code: code,
        hostId: 'u-mock',
        hostName: 'You',
        scheduledAt: request.startTime,
        durationMinutes: request.durationMinutes,
        status: 'scheduled',
        notes: request.notes,
      ),
    );
  }

  @override
  Future<Result<Meeting>> joinByCode(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final existing = _mockUpcoming().where((m) => m.code == code).firstOrNull;
    final meetingId = existing?.id ?? 'm-$code';
    return Success(
      Meeting(
        id: meetingId,
        title: existing?.title ?? 'Meeting ($code)',
        code: code,
        hostId: existing?.hostId ?? 'p-1',
        hostName: existing?.hostName ?? 'Host',
        scheduledAt: existing?.scheduledAt ?? DateTime.now(),
        durationMinutes: existing?.durationMinutes ?? 60,
        status: 'live',
        participants: existing?.participants ?? _mockParticipantsFor(meetingId),
      ),
    );
  }

  @override
  Future<Result<void>> leaveMeeting(String meetingId) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return const Success(null);
  }

  @override
  Future<Result<List<Meeting>>> listUpcoming() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return Success(_mockUpcoming());
  }

  @override
  Future<Result<void>> endMeeting(String meetingId) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return const Success(null);
  }

  String _segment(int length) {
    return List.generate(
      length,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    ).join();
  }
}

class SupabaseMeetingRepository extends BaseRepository
    implements MeetingRepository {
  const SupabaseMeetingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<Meeting>> createInstantMeeting() {
    return guard(() async {
      final result = await _client.rpc<dynamic>(
        'create_meeting',
        params: {
          'title': 'Instant meeting',
          'is_instant': true,
          'scheduled_at': null,
        },
      );
      return Meeting.fromJson(_extractMap(result)).copyWith(hostName: 'You');
    });
  }

  @override
  Future<Result<Meeting>> scheduleMeeting(ScheduledMeeting request) {
    return guard(() async {
      final result = await _client.rpc<dynamic>(
        'create_meeting',
        params: {
          'title': request.title.trim(),
          'is_instant': false,
          'scheduled_at': request.startTime.toUtc().toIso8601String(),
        },
      );
      return Meeting.fromJson(_extractMap(result)).copyWith(
        hostName: 'You',
        durationMinutes: request.durationMinutes,
        notes: request.notes,
      );
    });
  }

  @override
  Future<Result<Meeting>> joinByCode(String code) {
    return guard(() async {
      final normalized = code.trim().toLowerCase();
      final result = await _client.rpc<dynamic>(
        'join_meeting',
        params: {'code': normalized},
      );
      final meeting = Meeting.fromJson(_extractMap(result));
      final hostProfile = await _client
          .from('profiles')
          .select('display_name')
          .eq('id', meeting.hostId)
          .maybeSingle();
      final hostName = hostProfile?['display_name'] as String? ?? 'Host';

      final participantRows = await _client
          .from('meeting_participants')
          .select('*, profile:profiles(display_name, avatar_url)')
          .eq('meeting_id', meeting.id)
          .isFilter('left_at', null);

      final currentUid = _client.auth.currentUser?.id;
      final participants = participantRows.map((row) {
        final profileData = row['profile'];
        final displayName = profileData is Map<String, dynamic>
            ? (profileData['display_name'] as String? ?? 'Participant')
            : 'Participant';
        final avatarUrl = profileData is Map<String, dynamic>
            ? profileData['avatar_url'] as String?
            : null;
        final cleaned = Map<String, dynamic>.from(row)..remove('profile');
        final participant = MeetingParticipant.fromJson(cleaned);
        return participant.copyWith(
          displayName: displayName,
          avatarUrl: avatarUrl,
          isHost: participant.userId == meeting.hostId,
          isSelf: participant.userId == currentUid,
        );
      }).toList();

      return meeting.copyWith(
        hostName: hostName,
        participants: participants,
      );
    });
  }

  @override
  Future<Result<void>> leaveMeeting(String meetingId) {
    return guard(() async {
      await _client.rpc<void>(
        'leave_meeting',
        params: {'meeting_id': meetingId},
      );
    });
  }

  @override
  Future<Result<List<Meeting>>> listUpcoming() {
    return guard(() async {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final rows = await _client
          .from('meetings')
          .select('*, host:profiles!host_id(display_name)')
          .or('status.eq.live,and(status.eq.scheduled,scheduled_at.gte.$nowIso)')
          .order('scheduled_at', ascending: true, nullsFirst: false)
          .order('created_at', ascending: false);

      if (rows.isEmpty) {
        return const <Meeting>[];
      }

      return rows.map((row) {
        final hostData = row['host'];
        final hostName = hostData is Map<String, dynamic>
            ? (hostData['display_name'] as String? ?? 'Host')
            : 'Host';
        final cleaned = Map<String, dynamic>.from(row)..remove('host');
        return Meeting.fromJson(cleaned).copyWith(hostName: hostName);
      }).toList();
    });
  }

  @override
  Future<Result<void>> endMeeting(String meetingId) {
    return guard(() async {
      await _client
          .from('meetings')
          .update({'status': 'ended'})
          .eq('id', meetingId);
    });
  }

  Map<String, dynamic> _extractMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
      return data.first as Map<String, dynamic>;
    }
    throw const ServerException();
  }
}

@Riverpod(keepAlive: true)
MeetingRepository meetingRepository(Ref ref) {
  final useMock = ref.watch(useMockApiProvider);
  if (useMock) {
    return MockMeetingRepository();
  }
  return SupabaseMeetingRepository(ref.watch(supabaseClientProvider));
}
