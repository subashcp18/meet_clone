import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/network/supabase_provider.dart';
import '../../../auth/data/models/profile.dart';
import '../models/meeting_participant.dart';

part 'participants_repository.g.dart';

abstract interface class ParticipantsRepository {
  Stream<List<MeetingParticipant>> watchParticipants(String meetingId);

  Future<Result<void>> updateMyState(
    String meetingId, {
    bool? isMuted,
    bool? isCameraOff,
    bool? handRaised,
  });
}

class MockParticipantsRepository implements ParticipantsRepository {
  final Map<String, List<MeetingParticipant>> _store = {};
  final Map<String, StreamController<List<MeetingParticipant>>> _controllers =
      {};

  List<MeetingParticipant> _ensureMeetingList(String meetingId) {
    return _store.putIfAbsent(meetingId, () {
      return [
        MeetingParticipant(
          meetingId: meetingId,
          userId: 'p-self',
          displayName: 'You',
          email: 'you@example.com',
          isSelf: true,
        ),
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
      ];
    });
  }

  StreamController<List<MeetingParticipant>> _controllerFor(String meetingId) {
    return _controllers.putIfAbsent(
      meetingId,
      () => StreamController<List<MeetingParticipant>>.broadcast(),
    );
  }

  @override
  Stream<List<MeetingParticipant>> watchParticipants(String meetingId) async* {
    yield List<MeetingParticipant>.unmodifiable(_ensureMeetingList(meetingId));
    yield* _controllerFor(meetingId).stream;
  }

  @override
  Future<Result<void>> updateMyState(
    String meetingId, {
    bool? isMuted,
    bool? isCameraOff,
    bool? handRaised,
  }) async {
    final list = _ensureMeetingList(meetingId);
    final updated = list
        .map(
          (p) => p.isSelf
              ? p.copyWith(
                  isMuted: isMuted ?? p.isMuted,
                  isCameraOff: isCameraOff ?? p.isCameraOff,
                  handRaised: handRaised ?? p.handRaised,
                )
              : p,
        )
        .toList();
    _store[meetingId] = updated;
    _controllerFor(meetingId).add(List<MeetingParticipant>.unmodifiable(updated));
    return const Success(null);
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
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
      final activeRows = rows.where((r) => r['left_at'] == null).toList();
      final hostId = await _resolveHostId(meetingId);
      final missingIds = activeRows
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
      return activeRows.map((row) {
        final participant = MeetingParticipant.fromJson(row);
        final profile = _profileCache[participant.userId];
        final isSelf = participant.userId == currentUid;
        return participant.copyWith(
          displayName: profile?.displayName ?? 'Participant',
          avatarUrl: profile?.avatarUrl,
          isHost: participant.userId == hostId,
          isSelf: isSelf,
        );
      }).toList();
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
      };
      if (updates.isEmpty) {
        return;
      }
      await _client
          .from('meeting_participants')
          .update(updates)
          .eq('meeting_id', meetingId)
          .eq('user_id', uid);
    });
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
}

@Riverpod(keepAlive: true)
ParticipantsRepository participantsRepository(Ref ref) {
  final useMock = ref.watch(useMockApiProvider);
  if (useMock) {
    final repo = MockParticipantsRepository();
    ref.onDispose(repo.dispose);
    return repo;
  }
  return SupabaseParticipantsRepository(ref.watch(supabaseClientProvider));
}
