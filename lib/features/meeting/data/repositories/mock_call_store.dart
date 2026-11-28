import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_exception.dart';
import '../models/meeting.dart';
import '../models/meeting_participant.dart';
import '../models/meeting_preview.dart';
import '../models/open_meeting.dart';
import '../models/scheduled_meeting.dart';

part 'mock_call_store.g.dart';

@immutable
class JoinRequestResult {
  const JoinRequestResult({
    required this.meeting,
    required this.participantStatus,
  });

  final Meeting meeting;
  final String participantStatus;

  bool get isAdmitted => participantStatus == 'admitted';
  bool get isWaiting => participantStatus == 'waiting';
}

class MockCallStore {
  MockCallStore() {
    _seed();
  }

  static const String _alphabet = 'abcdefghijkmnpqrstuvwxyz';
  final Random _random = Random();

  final Map<String, Meeting> _meetingsById = {};
  final Map<String, List<MeetingParticipant>> _participantsByMeeting = {};
  final Map<String, StreamController<List<MeetingParticipant>>>
      _participantControllers = {};
  final Map<String, StreamController<Meeting?>> _meetingControllers = {};

  void _seed() {
    final now = DateTime.now();
    final todayBase = DateTime(now.year, now.month, now.day, 14, 30);

    final seeded = [
      Meeting(
        id: 'm-1',
        title: 'Product Design Sync',
        code: 'abc-defg-hij',
        hostId: 'p-1',
        hostName: 'Alex Morgan',
        scheduledAt: todayBase,
        durationMinutes: 45,
        status: 'live',
        lastActivityAt: now,
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
        lastActivityAt: now,
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
        lastActivityAt: now,
      ),
    ];

    for (final meeting in seeded) {
      _meetingsById[meeting.id] = meeting;
    }

    _participantsByMeeting['m-1'] = [
      MeetingParticipant(
        meetingId: 'm-1',
        userId: 'p-1',
        status: 'admitted',
        displayName: 'Alex Morgan',
        email: 'alex.morgan@example.com',
        isHost: true,
        isSpeaking: true,
        joinedAt: now.subtract(const Duration(minutes: 5)),
      ),
      MeetingParticipant(
        meetingId: 'm-1',
        userId: 'p-2',
        status: 'admitted',
        displayName: 'Sam Rivera',
        email: 'sam.rivera@example.com',
        isMuted: true,
        joinedAt: now.subtract(const Duration(minutes: 4)),
      ),
      MeetingParticipant(
        meetingId: 'm-1',
        userId: 'p-3',
        status: 'admitted',
        displayName: 'Jordan Lee',
        email: 'jordan.lee@example.com',
        isCameraOff: true,
        handRaised: true,
        joinedAt: now.subtract(const Duration(minutes: 3)),
      ),
      MeetingParticipant(
        meetingId: 'm-1',
        userId: 'p-4',
        status: 'admitted',
        displayName: 'Taylor Kim',
        email: 'taylor.kim@example.com',
        joinedAt: now.subtract(const Duration(minutes: 2)),
      ),
    ];
  }

  Meeting? _findByCode(String code) {
    final normalized = code.trim().toLowerCase();
    for (final m in _meetingsById.values) {
      if (m.code == normalized) {
        return m;
      }
    }
    return null;
  }

  Meeting createInstantMeeting({
    required String hostId,
    required String hostName,
  }) {
    final code = '${_segment(3)}-${_segment(4)}-${_segment(3)}';
    final now = DateTime.now();
    final meeting = Meeting(
      id: 'm-${now.microsecondsSinceEpoch}',
      title: 'Instant meeting',
      code: code,
      hostId: hostId,
      hostName: hostName,
      isInstant: true,
      status: 'live',
      createdAt: now,
      lastActivityAt: now,
      durationMinutes: 60,
    );
    _meetingsById[meeting.id] = meeting;
    _notifyMeeting(meeting.id);
    return meeting;
  }

  Meeting scheduleMeeting(
    ScheduledMeeting request, {
    required String hostId,
    required String hostName,
  }) {
    final code = '${_segment(3)}-${_segment(4)}-${_segment(3)}';
    final now = DateTime.now();
    final meeting = Meeting(
      id: 'm-${now.microsecondsSinceEpoch}',
      title: request.title.trim(),
      code: code,
      hostId: hostId,
      hostName: hostName,
      scheduledAt: request.startTime,
      durationMinutes: request.durationMinutes,
      status: 'scheduled',
      createdAt: now,
      lastActivityAt: now,
      notes: request.notes,
    );
    _meetingsById[meeting.id] = meeting;
    _notifyMeeting(meeting.id);
    return meeting;
  }

  MeetingPreview getPreview(String code, {required String currentUserId}) {
    final existing = _findByCode(code);
    if (existing == null) {
      throw const ServerException(
        message: 'Meeting not found. Check the code and try again.',
        statusCode: 404,
      );
    }
    if (existing.isEnded) {
      throw const ValidationException(message: 'This meeting has ended.');
    }
    final list = _participantsByMeeting[existing.id] ?? const [];
    final hostInCall = list.any(
      (p) => p.userId == existing.hostId && p.isAdmitted && p.leftAt == null,
    );
    final activeRemote = list
        .where((p) => p.isAdmitted && p.leftAt == null && p.userId != currentUserId)
        .map(
          (p) => MeetingPreviewParticipant(
            displayName: p.name,
            avatarUrl: p.avatarUrl,
          ),
        )
        .toList();

    return MeetingPreview(
      id: existing.id,
      code: existing.code,
      title: existing.title,
      status: existing.status,
      hostId: existing.hostId,
      hostName: existing.hostName,
      hostInCall: hostInCall,
      isInstant: existing.isInstant,
      scheduledAt: existing.scheduledAt,
      createdAt: existing.createdAt,
      previewParticipants: activeRemote,
    );
  }

  JoinRequestResult requestJoin(
    String code, {
    required String userId,
    required String displayName,
    required String email,
  }) {
    var meeting = _findByCode(code);
    if (meeting == null) {
      throw const ServerException(
        message: 'Meeting not found. Check the code and try again.',
        statusCode: 404,
      );
    }
    if (meeting.isEnded) {
      throw const ValidationException(message: 'This meeting has ended.');
    }

    final list = _participantsByMeeting.putIfAbsent(meeting.id, () => []);
    final existingIndex = list.indexWhere((p) => p.userId == userId);
    final existing = existingIndex >= 0 ? list[existingIndex] : null;
    final now = DateTime.now();

    if (meeting.hostId == userId) {
      final row = MeetingParticipant(
        meetingId: meeting.id,
        userId: userId,
        status: 'admitted',
        joinedAt: now,
        lastSeenAt: now,
        displayName: displayName,
        email: email,
        isHost: true,
        isSelf: true,
      );
      if (existingIndex >= 0) {
        list[existingIndex] = row;
      } else {
        list.add(row);
      }
      meeting = meeting.copyWith(status: 'live', lastActivityAt: now);
      _meetingsById[meeting.id] = meeting;
      _notifyMeeting(meeting.id);
      _notifyParticipants(meeting.id);
      return JoinRequestResult(
        meeting: meeting.copyWith(participants: admittedFor(meeting.id, userId)),
        participantStatus: 'admitted',
      );
    }

    if (existing != null && existing.isAdmitted && existing.leftAt == null) {
      list[existingIndex] = existing.copyWith(lastSeenAt: now);
      meeting = meeting.copyWith(
        status: meeting.status == 'scheduled' ? 'live' : meeting.status,
        lastActivityAt: now,
      );
      _meetingsById[meeting.id] = meeting;
      _notifyMeeting(meeting.id);
      _notifyParticipants(meeting.id);
      return JoinRequestResult(
        meeting: meeting.copyWith(participants: admittedFor(meeting.id, userId)),
        participantStatus: 'admitted',
      );
    }

    final admittedOthers = list
        .where((p) => p.isAdmitted && p.leftAt == null && p.userId != userId)
        .length;
    if (admittedOthers >= 5) {
      throw const ValidationException(
        message: 'This meeting is full (maximum 5 participants).',
      );
    }

    final waitingRow = MeetingParticipant(
      meetingId: meeting.id,
      userId: userId,
      status: 'waiting',
      joinedAt: now,
      lastSeenAt: now,
      displayName: displayName,
      email: email,
      isSelf: true,
    );
    if (existingIndex >= 0) {
      list[existingIndex] = waitingRow;
    } else {
      list.add(waitingRow);
    }
    meeting = meeting.copyWith(lastActivityAt: now);
    _meetingsById[meeting.id] = meeting;
    _notifyParticipants(meeting.id);
    return JoinRequestResult(
      meeting: meeting,
      participantStatus: 'waiting',
    );
  }

  void cancelJoinRequest(String meetingId, String userId) {
    final list = _participantsByMeeting[meetingId];
    if (list == null) {
      return;
    }
    list.removeWhere((p) => p.userId == userId && p.isWaiting);
    _notifyParticipants(meetingId);
  }

  void admit(String meetingId, String userId, {String? callerUserId}) {
    final meeting = _meetingsById[meetingId];
    if (meeting != null &&
        callerUserId != null &&
        meeting.hostId != callerUserId) {
      throw const UnauthorizedException(
        message: 'Only the host can do that.',
        statusCode: 403,
      );
    }
    final list = _participantsByMeeting[meetingId];
    if (list == null) {
      return;
    }
    final activeCount = list
        .where((p) => p.isAdmitted && p.leftAt == null && p.userId != userId)
        .length;
    if (activeCount >= 5) {
      throw const ValidationException(
        message: 'This meeting is full (maximum 5 participants).',
      );
    }
    final idx = list.indexWhere((p) => p.userId == userId);
    if (idx < 0) {
      return;
    }
    final now = DateTime.now();
    list[idx] = list[idx].copyWith(
      status: 'admitted',
      leftAt: null,
      joinedAt: now,
      lastSeenAt: now,
    );
    if (meeting != null) {
      _meetingsById[meetingId] = meeting.copyWith(
        status: meeting.status == 'scheduled' ? 'live' : meeting.status,
        lastActivityAt: now,
      );
      _notifyMeeting(meetingId);
    }
    _notifyParticipants(meetingId);
  }

  void deny(String meetingId, String userId, {String? callerUserId}) {
    final meeting = _meetingsById[meetingId];
    if (meeting != null &&
        callerUserId != null &&
        meeting.hostId != callerUserId) {
      throw const UnauthorizedException(
        message: 'Only the host can do that.',
        statusCode: 403,
      );
    }
    final list = _participantsByMeeting[meetingId];
    if (list == null) {
      return;
    }
    final idx = list.indexWhere((p) => p.userId == userId);
    if (idx < 0) {
      return;
    }
    list[idx] = list[idx].copyWith(status: 'denied');
    _notifyParticipants(meetingId);
  }

  void admitAll(String meetingId, {String? callerUserId}) {
    final meeting = _meetingsById[meetingId];
    if (meeting != null &&
        callerUserId != null &&
        meeting.hostId != callerUserId) {
      throw const UnauthorizedException(
        message: 'Only the host can do that.',
        statusCode: 403,
      );
    }
    final list = _participantsByMeeting[meetingId];
    if (list == null) {
      return;
    }
    var activeCount = list.where((p) => p.isAdmitted && p.leftAt == null).length;
    final now = DateTime.now();
    for (var i = 0; i < list.length && activeCount < 5; i++) {
      if (list[i].isWaiting && list[i].leftAt == null) {
        list[i] = list[i].copyWith(
          status: 'admitted',
          leftAt: null,
          joinedAt: now,
          lastSeenAt: now,
        );
        activeCount++;
      }
    }
    if (meeting != null) {
      _meetingsById[meetingId] = meeting.copyWith(
        status: meeting.status == 'scheduled' ? 'live' : meeting.status,
        lastActivityAt: now,
      );
      _notifyMeeting(meetingId);
    }
    _notifyParticipants(meetingId);
  }

  void hostMute(
    String meetingId,
    String targetUserId, {
    required String callerUserId,
  }) {
    final meeting = _meetingsById[meetingId];
    if (meeting != null && meeting.hostId != callerUserId) {
      throw const UnauthorizedException(
        message: 'Only the host can do that.',
        statusCode: 403,
      );
    }
    final list = _participantsByMeeting[meetingId];
    if (list == null) {
      return;
    }
    final idx = list.indexWhere(
      (p) =>
          p.userId == targetUserId &&
          p.userId != callerUserId &&
          p.isAdmitted &&
          p.leftAt == null,
    );
    if (idx < 0) {
      return;
    }
    list[idx] = list[idx].copyWith(isMuted: true, isSpeaking: false);
    _notifyParticipants(meetingId);
  }

  void removeParticipant(
    String meetingId,
    String targetUserId, {
    required String callerUserId,
  }) {
    final meeting = _meetingsById[meetingId];
    if (meeting != null && meeting.hostId != callerUserId) {
      throw const UnauthorizedException(
        message: 'Only the host can do that.',
        statusCode: 403,
      );
    }
    final list = _participantsByMeeting[meetingId];
    if (list == null) {
      return;
    }
    final idx = list.indexWhere(
      (p) =>
          p.userId == targetUserId &&
          p.userId != callerUserId &&
          p.isAdmitted &&
          p.leftAt == null,
    );
    if (idx < 0) {
      return;
    }
    list[idx] = list[idx].copyWith(
      status: 'denied',
      leftAt: DateTime.now(),
    );
    _notifyParticipants(meetingId);
  }

  void leaveMeeting(String meetingId, String userId) {
    final list = _participantsByMeeting[meetingId];
    final now = DateTime.now();
    if (list != null) {
      final idx = list.indexWhere(
        (p) => p.userId == userId && p.isAdmitted && p.leftAt == null,
      );
      if (idx >= 0) {
        list[idx] = list[idx].copyWith(leftAt: now);
      }
    }
    final meeting = _meetingsById[meetingId];
    if (meeting != null) {
      _meetingsById[meetingId] = meeting.copyWith(lastActivityAt: now);
    }
    _notifyParticipants(meetingId);
  }

  void endMeeting(String meetingId) {
    final now = DateTime.now();
    final meeting = _meetingsById[meetingId];
    if (meeting != null) {
      _meetingsById[meetingId] = meeting.copyWith(
        status: 'ended',
        endedAt: now,
        lastActivityAt: now,
      );
      _notifyMeeting(meetingId);
    }
    final list = _participantsByMeeting[meetingId];
    if (list != null) {
      list.removeWhere((p) => p.isWaiting);
      for (var i = 0; i < list.length; i++) {
        if (list[i].isAdmitted && list[i].leftAt == null) {
          list[i] = list[i].copyWith(leftAt: now);
        }
      }
      _notifyParticipants(meetingId);
    }
  }

  void heartbeat(String meetingId, String userId) {
    final now = DateTime.now();
    final list = _participantsByMeeting[meetingId];
    if (list != null) {
      final idx = list.indexWhere((p) => p.userId == userId);
      if (idx >= 0) {
        list[idx] = list[idx].copyWith(lastSeenAt: now);
      }
    }
    final meeting = _meetingsById[meetingId];
    if (meeting != null) {
      _meetingsById[meetingId] = meeting.copyWith(lastActivityAt: now);
    }
  }

  void updateMyState(
    String meetingId,
    String userId, {
    bool? isMuted,
    bool? isCameraOff,
    bool? handRaised,
  }) {
    final list = _participantsByMeeting[meetingId];
    if (list == null) {
      return;
    }
    final idx = list.indexWhere((p) => p.userId == userId);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(
        isMuted: isMuted ?? list[idx].isMuted,
        isCameraOff: isCameraOff ?? list[idx].isCameraOff,
        handRaised: handRaised ?? list[idx].handRaised,
        lastSeenAt: DateTime.now(),
      );
      _notifyParticipants(meetingId);
    }
  }

  List<Meeting> listUpcoming() {
    final active = _meetingsById.values
        .where((m) => m.status == 'scheduled' || m.status == 'live')
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return active;
  }

  List<OpenMeeting> listOpenMeetings({required String currentUserId}) {
    final items = <OpenMeeting>[];
    for (final m in _meetingsById.values) {
      if (m.status != 'live' && m.status != 'scheduled') {
        continue;
      }
      final participants = _participantsByMeeting[m.id] ?? const [];
      final hostInCall = participants.any(
        (p) => p.userId == m.hostId && p.isAdmitted && p.leftAt == null,
      );
      final activeCount = participants
          .where((p) => p.isAdmitted && p.leftAt == null)
          .length;
      final amIHost = m.hostId == currentUserId;
      final amIAdmitted = participants.any(
        (p) => p.userId == currentUserId && p.isAdmitted,
      );
      if (!amIHost && !amIAdmitted && m.id != 'm-1' && m.id != 'm-2' && m.id != 'm-3') {
        continue;
      }
      items.add(
        OpenMeeting(
          id: m.id,
          code: m.code,
          title: m.title,
          status: m.status,
          isInstant: m.isInstant,
          scheduledAt: m.scheduledAt,
          createdAt: m.createdAt,
          lastActivityAt: m.lastActivityAt,
          hostId: m.hostId,
          hostName: m.hostName,
          hostInCall: hostInCall,
          activeParticipantCount: activeCount,
          amIHost: amIHost,
          durationMinutes: m.durationMinutes,
        ),
      );
    }
    items.sort((a, b) => a.startTime.compareTo(b.startTime));
    return items;
  }

  List<MeetingParticipant> admittedFor(String meetingId, String currentUserId) {
    return (_participantsByMeeting[meetingId] ?? const [])
        .where((p) => p.isAdmitted && p.leftAt == null)
        .map((p) => p.copyWith(isSelf: p.userId == currentUserId))
        .toList();
  }

  List<MeetingParticipant> waitingFor(String meetingId) {
    return (_participantsByMeeting[meetingId] ?? const [])
        .where((p) => p.isWaiting && p.leftAt == null)
        .toList();
  }

  MeetingParticipant? myRowFor(String meetingId, String currentUserId) {
    return (_participantsByMeeting[meetingId] ?? const [])
        .where((p) => p.userId == currentUserId)
        .firstOrNull;
  }

  Stream<List<MeetingParticipant>> watchAdmitted(
    String meetingId,
    String currentUserId,
  ) async* {
    yield admittedFor(meetingId, currentUserId);
    yield* _participantController(meetingId).stream.map(
      (_) => admittedFor(meetingId, currentUserId),
    );
  }

  Stream<List<MeetingParticipant>> watchWaiting(String meetingId) async* {
    yield waitingFor(meetingId);
    yield* _participantController(meetingId).stream.map(
      (_) => waitingFor(meetingId),
    );
  }

  Stream<MeetingParticipant?> watchMyRow(
    String meetingId,
    String currentUserId,
  ) async* {
    yield myRowFor(meetingId, currentUserId);
    yield* _participantController(meetingId).stream.map(
      (_) => myRowFor(meetingId, currentUserId),
    );
  }

  Stream<Meeting?> watchMeeting(String meetingId) async* {
    yield _meetingsById[meetingId];
    yield* _meetingController(meetingId).stream;
  }

  StreamController<List<MeetingParticipant>> _participantController(
    String meetingId,
  ) {
    return _participantControllers.putIfAbsent(
      meetingId,
      () => StreamController<List<MeetingParticipant>>.broadcast(),
    );
  }

  StreamController<Meeting?> _meetingController(String meetingId) {
    return _meetingControllers.putIfAbsent(
      meetingId,
      () => StreamController<Meeting?>.broadcast(),
    );
  }

  void _notifyParticipants(String meetingId) {
    final controller = _participantControllers[meetingId];
    if (controller != null && !controller.isClosed) {
      controller.add(_participantsByMeeting[meetingId] ?? const []);
    }
  }

  void _notifyMeeting(String meetingId) {
    final controller = _meetingControllers[meetingId];
    if (controller != null && !controller.isClosed) {
      controller.add(_meetingsById[meetingId]);
    }
  }

  void dispose() {
    for (final c in _participantControllers.values) {
      c.close();
    }
    for (final c in _meetingControllers.values) {
      c.close();
    }
    _participantControllers.clear();
    _meetingControllers.clear();
  }

  String _segment(int length) {
    return List.generate(
      length,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    ).join();
  }
}

@Riverpod(keepAlive: true)
MockCallStore mockCallStore(Ref ref) {
  final store = MockCallStore();
  ref.onDispose(store.dispose);
  return store;
}
