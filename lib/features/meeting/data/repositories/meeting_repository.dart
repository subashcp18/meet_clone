import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/network/supabase_provider.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../models/meeting.dart';
import '../models/meeting_preview.dart';
import '../models/open_meeting.dart';
import '../models/scheduled_meeting.dart';
import 'mock_call_store.dart';

part 'meeting_repository.g.dart';

abstract interface class MeetingRepository {
  Future<Result<Meeting>> createInstantMeeting();
  Future<Result<Meeting>> scheduleMeeting(ScheduledMeeting request);
  Future<Result<MeetingPreview>> getPreview(String code);
  Future<Result<JoinRequestResult>> requestJoin(String code);
  Future<Result<void>> cancelJoinRequest(String meetingId);
  Future<Result<void>> leaveMeeting(String meetingId);
  Future<Result<void>> endMeeting(String meetingId);
  Future<Result<List<Meeting>>> listUpcoming();
  Future<Result<List<OpenMeeting>>> listOpenMeetings();
}

class MockMeetingRepository extends BaseRepository
    implements MeetingRepository {
  MockMeetingRepository(this._store, this._authRepository);

  final MockCallStore _store;
  final AuthRepository _authRepository;

  String get _userId => _authRepository.currentUser?.id ?? 'u-mock';
  String get _userName => _authRepository.currentUser?.displayName ?? 'You';
  String get _userEmail =>
      _authRepository.currentUser?.email ?? 'you@example.com';

  @override
  Future<Result<Meeting>> createInstantMeeting() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return Success(
      _store.createInstantMeeting(hostId: _userId, hostName: _userName),
    );
  }

  @override
  Future<Result<Meeting>> scheduleMeeting(ScheduledMeeting request) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return Success(
      _store.scheduleMeeting(request, hostId: _userId, hostName: _userName),
    );
  }

  @override
  Future<Result<MeetingPreview>> getPreview(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return guard(() async {
      final preview = _store.getPreview(code, currentUserId: _userId);
      if (kDebugMode) {
        debugPrint(
          'MeetingPreview code=${preview.code} status=${preview.status}',
        );
      }
      return preview;
    });
  }

  @override
  Future<Result<JoinRequestResult>> requestJoin(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return guard(
      () async => _store.requestJoin(
        code,
        userId: _userId,
        displayName: _userName,
        email: _userEmail,
      ),
    );
  }

  @override
  Future<Result<void>> cancelJoinRequest(String meetingId) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _store.cancelJoinRequest(meetingId, _userId);
    return const Success(null);
  }

  @override
  Future<Result<void>> leaveMeeting(String meetingId) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _store.leaveMeeting(meetingId, _userId);
    return const Success(null);
  }

  @override
  Future<Result<void>> endMeeting(String meetingId) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _store.endMeeting(meetingId);
    return const Success(null);
  }

  @override
  Future<Result<List<Meeting>>> listUpcoming() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return Success(_store.listUpcoming());
  }

  @override
  Future<Result<List<OpenMeeting>>> listOpenMeetings() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return Success(_store.listOpenMeetings(currentUserId: _userId));
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
  Future<Result<MeetingPreview>> getPreview(String code) {
    return guard(() async {
      final normalized = code.trim().toLowerCase();
      final result = await _client.rpc<dynamic>(
        'get_meeting_preview',
        params: {'p_code': normalized},
      );
      final preview = MeetingPreview.fromJson(_extractMap(result));
      if (kDebugMode) {
        debugPrint(
          'MeetingPreview code=${preview.code} status=${preview.status}',
        );
      }
      return preview;
    });
  }

  @override
  Future<Result<JoinRequestResult>> requestJoin(String code) {
    return guard(() async {
      final normalized = code.trim().toLowerCase();
      final result = await _client.rpc<dynamic>(
        'request_join',
        params: {'p_code': normalized},
      );
      final map = _extractMap(result);
      final participantStatus =
          map['participant_status'] as String? ?? 'waiting';
      final meetingMap = map['meeting'];
      if (meetingMap is! Map<String, dynamic>) {
        throw const ServerException();
      }
      final meeting = Meeting.fromJson(meetingMap);
      return JoinRequestResult(
        meeting: meeting,
        participantStatus: participantStatus,
      );
    });
  }

  @override
  Future<Result<void>> cancelJoinRequest(String meetingId) {
    return guard(() async {
      await _client.rpc<void>(
        'cancel_join_request',
        params: {'p_meeting_id': meetingId},
      );
    });
  }

  @override
  Future<Result<void>> leaveMeeting(String meetingId) {
    return guard(() async {
      await _client.rpc<void>(
        'leave_meeting',
        params: {'p_meeting_id': meetingId},
      );
    });
  }

  @override
  Future<Result<void>> endMeeting(String meetingId) {
    return guard(() async {
      await _client.rpc<void>(
        'end_meeting',
        params: {'p_meeting_id': meetingId},
      );
    });
  }

  @override
  Future<Result<List<Meeting>>> listUpcoming() {
    return guard(() async {
      final rows = await _client
          .from('meetings')
          .select('*, host:profiles!host_id(display_name)')
          .inFilter('status', ['scheduled', 'live'])
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
  Future<Result<List<OpenMeeting>>> listOpenMeetings() {
    return guard(() async {
      final result = await _client.rpc<dynamic>('my_open_meetings');
      if (result is! List) {
        return const <OpenMeeting>[];
      }
      return result
          .whereType<Map<String, dynamic>>()
          .map(OpenMeeting.fromJson)
          .toList();
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
    return MockMeetingRepository(
      ref.watch(mockCallStoreProvider),
      ref.watch(authRepositoryProvider),
    );
  }
  return SupabaseMeetingRepository(ref.watch(supabaseClientProvider));
}
