import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/network/supabase_provider.dart';
import '../../../auth/data/models/profile.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../models/meeting.dart';
import '../models/meeting_participant.dart';
import 'mock_call_store.dart';

part 'participants_repository.g.dart';

abstract interface class ParticipantsRepository {
  Stream<List<MeetingParticipant>> watchParticipants(String meetingId);
  Stream<MeetingParticipant?> watchMyParticipantRow(String meetingId);
  Stream<List<MeetingParticipant>> watchWaitingRequests(String meetingId);
  Stream<Meeting?> watchMeeting(String meetingId);

  Future<Result<void>> admit(String meetingId, String userId);
  Future<Result<void>> deny(String meetingId, String userId);
  Future<Result<void>> admitAll(String meetingId);
  Future<Result<void>> hostMute(String meetingId, String userId);
  Future<Result<void>> removeParticipant(String meetingId, String userId);
  Future<Result<void>> heartbeat(String meetingId);
  Future<Result<void>> updateMyState(
    String meetingId, {
    bool? isMuted,
    bool? isCameraOff,
    bool? handRaised,
  });
}

class MockParticipantsRepository extends BaseRepository
    implements ParticipantsRepository {
  const MockParticipantsRepository(this._store, this._authRepository);

  final MockCallStore _store;
  final AuthRepository _authRepository;

  String get _userId => _authRepository.currentUser?.id ?? 'u-mock';

  @override
  Stream<List<MeetingParticipant>> watchParticipants(String meetingId) {
    return _store.watchAdmitted(meetingId, _userId);
  }

  @override
  Stream<MeetingParticipant?> watchMyParticipantRow(String meetingId) {
    return _store.watchMyRow(meetingId, _userId);
  }

  @override
  Stream<List<MeetingParticipant>> watchWaitingRequests(String meetingId) {
    return _store.watchWaiting(meetingId);
  }

  @override
  Stream<Meeting?> watchMeeting(String meetingId) {
    return _store.watchMeeting(meetingId);
  }

  @override
  Future<Result<void>> admit(String meetingId, String userId) async {
    return guard(() async {
      _store.admit(meetingId, userId, callerUserId: _userId);
    });
  }

  @override
  Future<Result<void>> deny(String meetingId, String userId) async {
    return guard(() async {
      _store.deny(meetingId, userId, callerUserId: _userId);
    });
  }

  @override
  Future<Result<void>> admitAll(String meetingId) async {
    return guard(() async {
      _store.admitAll(meetingId, callerUserId: _userId);
    });
  }

  @override
  Future<Result<void>> hostMute(String meetingId, String userId) async {
    return guard(() async {
      _store.hostMute(meetingId, userId, callerUserId: _userId);
    });
  }

  @override
  Future<Result<void>> removeParticipant(String meetingId, String userId) async {
    return guard(() async {
      _store.removeParticipant(meetingId, userId, callerUserId: _userId);
    });
  }

  @override
  Future<Result<void>> heartbeat(String meetingId) async {
    _store.heartbeat(meetingId, _userId);
    return const Success(null);
  }

  @override
  Future<Result<void>> updateMyState(
    String meetingId, {
    bool? isMuted,
    bool? isCameraOff,
    bool? handRaised,
  }) async {
    _store.updateMyState(
      meetingId,
      _userId,
      isMuted: isMuted,
      isCameraOff: isCameraOff,
      handRaised: handRaised,
    );
    return const Success(null);
  }
}

class SupabaseParticipantsRepository extends BaseRepository
    implements ParticipantsRepository {
  SupabaseParticipantsRepository(this._client);

  final SupabaseClient _client;
  final Map<String, Profile> _profileCache = {};
  final Map<String, String> _hostIdCache = {};

  @override
  Stream<List<MeetingParticipant>> watchParticipants(String meetingId) {
    final stream = _client
        .from('meeting_participants')
        .stream(primaryKey: ['meeting_id', 'user_id'])
        .eq('meeting_id', meetingId)
        .order('joined_at', ascending: true);

    return stream.asyncMap((rows) async {
      final admittedRows = rows
          .where((r) => r['status'] == 'admitted' && r['left_at'] == null)
          .toList();
      return _hydrateRows(meetingId, admittedRows);
    }).handleError(_rethrowMappedError);
  }

  @override
  Stream<MeetingParticipant?> watchMyParticipantRow(String meetingId) {
    final stream = _client
        .from('meeting_participants')
        .stream(primaryKey: ['meeting_id', 'user_id'])
        .eq('meeting_id', meetingId);

    return stream.asyncMap((rows) async {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        return null;
      }
      final mine = rows.where((r) => r['user_id'] == uid).toList();
      if (mine.isEmpty) {
        return null;
      }
      final hydrated = await _hydrateRows(meetingId, mine);
      return hydrated.firstOrNull;
    }).handleError(_rethrowMappedError);
  }

  @override
  Stream<List<MeetingParticipant>> watchWaitingRequests(String meetingId) {
    final stream = _client
        .from('meeting_participants')
        .stream(primaryKey: ['meeting_id', 'user_id'])
        .eq('meeting_id', meetingId)
        .order('joined_at', ascending: true);

    return stream.asyncMap((rows) async {
      final waitingRows = rows
          .where((r) => r['status'] == 'waiting' && r['left_at'] == null)
          .toList();
      return _hydrateRows(meetingId, waitingRows);
    }).handleError(_rethrowMappedError);
  }

  @override
  Stream<Meeting?> watchMeeting(String meetingId) {
    final stream = _client
        .from('meetings')
        .stream(primaryKey: ['id'])
        .eq('id', meetingId);

    return stream.map((rows) {
      if (rows.isEmpty) {
        return null;
      }
      return Meeting.fromJson(rows.first);
    }).handleError(_rethrowMappedError);
  }

  @override
  Future<Result<void>> admit(String meetingId, String userId) {
    return guard(() async {
      await _client.rpc<void>(
        'admit_participant',
        params: {
          'p_meeting_id': meetingId,
          'p_user_id': userId,
        },
      );
    });
  }

  @override
  Future<Result<void>> deny(String meetingId, String userId) {
    return guard(() async {
      await _client.rpc<void>(
        'deny_participant',
        params: {
          'p_meeting_id': meetingId,
          'p_user_id': userId,
        },
      );
    });
  }

  @override
  Future<Result<void>> admitAll(String meetingId) {
    return guard(() async {
      await _client.rpc<void>(
        'admit_all_waiting',
        params: {'p_meeting_id': meetingId},
      );
    });
  }

  @override
  Future<Result<void>> hostMute(String meetingId, String userId) {
    return guard(() async {
      await _client.rpc<void>(
        'host_mute_participant',
        params: {
          'p_meeting_id': meetingId,
          'p_user_id': userId,
        },
      );
    });
  }

  @override
  Future<Result<void>> removeParticipant(String meetingId, String userId) {
    return guard(() async {
      await _client.rpc<void>(
        'remove_participant',
        params: {
          'p_meeting_id': meetingId,
          'p_user_id': userId,
        },
      );
    });
  }

  @override
  Future<Result<void>> heartbeat(String meetingId) {
    return guard(() async {
      await _client.rpc<void>(
        'heartbeat',
        params: {'p_meeting_id': meetingId},
      );
    });
  }

  @override
  Future<Result<void>> updateMyState(
    String meetingId, {
    bool? isMuted,
    bool? isCameraOff,
    bool? handRaised,
  }) {
    return guard(() async {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        throw const UnauthorizedException();
      }
      final updates = <String, dynamic>{
        if (isMuted != null) 'is_muted': isMuted,
        if (isCameraOff != null) 'is_camera_off': isCameraOff,
        if (handRaised != null) 'hand_raised': handRaised,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      };
      await _client
          .from('meeting_participants')
          .update(updates)
          .eq('meeting_id', meetingId)
          .eq('user_id', uid);
    });
  }

  Future<List<MeetingParticipant>> _hydrateRows(
    String meetingId,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) {
      return const <MeetingParticipant>[];
    }
    final hostId = await _resolveHostId(meetingId);
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
      final participant = MeetingParticipant.fromJson(row);
      final profile = _profileCache[participant.userId];
      return participant.copyWith(
        displayName: profile?.displayName ?? 'Participant',
        avatarUrl: profile?.avatarUrl,
        isHost: participant.userId == hostId,
        isSelf: participant.userId == currentUid,
      );
    }).toList();
  }

  Future<String?> _resolveHostId(String meetingId) async {
    final cached = _hostIdCache[meetingId];
    if (cached != null) {
      return cached;
    }
    final row = await _client
        .from('meetings')
        .select('host_id')
        .eq('id', meetingId)
        .maybeSingle();
    final hostId = row?['host_id'] as String?;
    if (hostId != null) {
      _hostIdCache[meetingId] = hostId;
    }
    return hostId;
  }

  Never _rethrowMappedError(Object error, StackTrace stackTrace) {
    if (error is PostgrestException) {
      BaseRepository.logPostgrestException(error);
      throw ApiException.fromPostgrestException(error);
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}

@Riverpod(keepAlive: true)
ParticipantsRepository participantsRepository(Ref ref) {
  final useMock = ref.watch(useMockApiProvider);
  if (useMock) {
    return MockParticipantsRepository(
      ref.watch(mockCallStoreProvider),
      ref.watch(authRepositoryProvider),
    );
  }
  return SupabaseParticipantsRepository(ref.watch(supabaseClientProvider));
}
