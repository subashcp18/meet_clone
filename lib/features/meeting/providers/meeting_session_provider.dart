import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/providers/auth_provider.dart';
import '../../home/providers/home_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../data/models/meeting.dart';
import '../data/models/meeting_participant.dart';
import '../data/models/meeting_preview.dart';
import '../data/repositories/meeting_repository.dart';
import '../data/repositories/participants_repository.dart';

part 'meeting_session_provider.g.dart';

enum AudioOutputDevice {
  speaker('Speaker'),
  earpiece('Phone earpiece'),
  bluetooth('Bluetooth headset');

  const AudioOutputDevice(this.label);

  final String label;
}

@immutable
class MeetingSessionState {
  const MeetingSessionState({
    this.meetingId = '',
    this.code = '',
    this.title = '',
    this.hostId = '',
    this.isHost = false,
    this.isMicOn = true,
    this.isCameraOn = true,
    this.isFrontCamera = true,
    this.isPresenting = false,
    this.isHandRaised = false,
    this.audioOutput = AudioOutputDevice.speaker,
    this.isJoining = false,
    this.errorMessage,
    this.participants = const <MeetingParticipant>[],
    this.waitingRequests = const <MeetingParticipant>[],
  });

  final String meetingId;
  final String code;
  final String title;
  final String hostId;
  final bool isHost;
  final bool isMicOn;
  final bool isCameraOn;
  final bool isFrontCamera;
  final bool isPresenting;
  final bool isHandRaised;
  final AudioOutputDevice audioOutput;
  final bool isJoining;
  final String? errorMessage;
  final List<MeetingParticipant> participants;
  final List<MeetingParticipant> waitingRequests;

  bool get hasOtherAdmitted => participants.any((p) => !p.isSelf);

  MeetingSessionState copyWith({
    String? meetingId,
    String? code,
    String? title,
    String? hostId,
    bool? isHost,
    bool? isMicOn,
    bool? isCameraOn,
    bool? isFrontCamera,
    bool? isPresenting,
    bool? isHandRaised,
    AudioOutputDevice? audioOutput,
    bool? isJoining,
    String? errorMessage,
    List<MeetingParticipant>? participants,
    List<MeetingParticipant>? waitingRequests,
  }) {
    return MeetingSessionState(
      meetingId: meetingId ?? this.meetingId,
      code: code ?? this.code,
      title: title ?? this.title,
      hostId: hostId ?? this.hostId,
      isHost: isHost ?? this.isHost,
      isMicOn: isMicOn ?? this.isMicOn,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isPresenting: isPresenting ?? this.isPresenting,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      audioOutput: audioOutput ?? this.audioOutput,
      isJoining: isJoining ?? this.isJoining,
      errorMessage: errorMessage,
      participants: participants ?? this.participants,
      waitingRequests: waitingRequests ?? this.waitingRequests,
    );
  }
}

@riverpod
Future<MeetingPreview> meetingPreview(Ref ref, String code) async {
  final result = await ref.read(meetingRepositoryProvider).getPreview(code);
  return result.when(
    success: (preview) => preview,
    failure: (exception) => throw exception,
  );
}

@riverpod
Stream<List<MeetingParticipant>> meetingParticipants(
  Ref ref,
  String meetingId,
) {
  return ref.watch(participantsRepositoryProvider).watchParticipants(meetingId);
}

@riverpod
Stream<List<MeetingParticipant>> waitingRequests(
  Ref ref,
  String meetingId,
) {
  return ref
      .watch(participantsRepositoryProvider)
      .watchWaitingRequests(meetingId);
}

@riverpod
Stream<MeetingParticipant?> myParticipantRow(
  Ref ref,
  String meetingId,
) {
  return ref
      .watch(participantsRepositoryProvider)
      .watchMyParticipantRow(meetingId);
}

@riverpod
Stream<Meeting?> meetingStatus(
  Ref ref,
  String meetingId,
) {
  return ref.watch(participantsRepositoryProvider).watchMeeting(meetingId);
}

@Riverpod(keepAlive: true)
class MeetingSessionNotifier extends _$MeetingSessionNotifier {
  // region: SUBSCRIPTIONS & BUILD
  ProviderSubscription<AsyncValue<List<MeetingParticipant>>>? _participantsSub;
  ProviderSubscription<AsyncValue<List<MeetingParticipant>>>? _waitingSub;

  @override
  MeetingSessionState build() {
    ref.onDispose(_closeSubscriptions);
    final defaults = ref.read(settingsProvider);
    return MeetingSessionState(
      isMicOn: defaults.defaultMicOn,
      isCameraOn: defaults.defaultCameraOn,
    );
  }

  void _closeSubscriptions() {
    _participantsSub?.close();
    _participantsSub = null;
    _waitingSub?.close();
    _waitingSub = null;
  }
  // endregion

  // region: MEDIA & DEVICE CONTROLS
  void toggleMic() {
    final nextMic = !state.isMicOn;
    state = state.copyWith(
      isMicOn: nextMic,
      participants: _updateSelf(
        (self) => self.copyWith(isMuted: !nextMic),
      ),
    );
    _syncMyState(isMuted: !nextMic);
  }

  void applyRemoteMute() {
    if (!state.isMicOn) {
      return;
    }
    state = state.copyWith(
      isMicOn: false,
      participants: _updateSelf(
        (self) => self.copyWith(isMuted: true),
      ),
    );
  }

  void toggleCamera() {
    final nextCamera = !state.isCameraOn;
    state = state.copyWith(
      isCameraOn: nextCamera,
      participants: _updateSelf(
        (self) => self.copyWith(isCameraOff: !nextCamera),
      ),
    );
    _syncMyState(isCameraOff: !nextCamera);
  }

  void toggleCameraFacing() {
    state = state.copyWith(isFrontCamera: !state.isFrontCamera);
  }

  void togglePresenting() {
    state = state.copyWith(isPresenting: !state.isPresenting);
  }

  void toggleHandRaised() {
    final nextRaised = !state.isHandRaised;
    state = state.copyWith(
      isHandRaised: nextRaised,
      participants: _updateSelf(
        (self) => self.copyWith(handRaised: nextRaised),
      ),
    );
    _syncMyState(handRaised: nextRaised);
  }

  void setAudioOutput(AudioOutputDevice device) {
    state = state.copyWith(audioOutput: device);
  }

  void setDefaults({required bool micOn, required bool cameraOn}) {
    state = state.copyWith(
      isMicOn: micOn,
      isCameraOn: cameraOn,
      participants: _updateSelf(
        (self) => self.copyWith(isMuted: !micOn, isCameraOff: !cameraOn),
      ),
    );
    _syncMyState(isMuted: !micOn, isCameraOff: !cameraOn);
  }

  Future<void> _syncMyState({
    bool? isMuted,
    bool? isCameraOff,
    bool? handRaised,
  }) async {
    final meetingId = state.meetingId;
    if (meetingId.isEmpty) {
      return;
    }
    final result = await ref
        .read(participantsRepositoryProvider)
        .updateMyState(
          meetingId,
          isMuted: isMuted,
          isCameraOff: isCameraOff,
          handRaised: handRaised,
        );
    result.when(
      success: (_) {},
      failure: (exception) {
        state = state.copyWith(errorMessage: exception.message);
      },
    );
  }

  List<MeetingParticipant> _updateSelf(
    MeetingParticipant Function(MeetingParticipant self) transform,
  ) {
    return state.participants
        .map((p) => p.isSelf ? transform(p) : p)
        .toList();
  }
  // endregion

  // region: ADMISSION & HOST MODERATION
  Future<String?> admitParticipant(String userId) async {
    if (state.meetingId.isEmpty) {
      return null;
    }
    final result = await ref
        .read(participantsRepositoryProvider)
        .admit(state.meetingId, userId);
    return result.when(
      success: (_) => null,
      failure: (exception) => exception.message,
    );
  }

  Future<String?> denyParticipant(String userId) async {
    if (state.meetingId.isEmpty) {
      return null;
    }
    final result = await ref
        .read(participantsRepositoryProvider)
        .deny(state.meetingId, userId);
    return result.when(
      success: (_) => null,
      failure: (exception) => exception.message,
    );
  }

  Future<String?> admitAllWaiting() async {
    if (state.meetingId.isEmpty) {
      return null;
    }
    final result = await ref
        .read(participantsRepositoryProvider)
        .admitAll(state.meetingId);
    return result.when(
      success: (_) => null,
      failure: (exception) => exception.message,
    );
  }

  Future<String?> hostMuteParticipant(String userId) async {
    if (state.meetingId.isEmpty) {
      return null;
    }
    final result = await ref
        .read(participantsRepositoryProvider)
        .hostMute(state.meetingId, userId);
    return result.when(
      success: (_) => null,
      failure: (exception) => exception.message,
    );
  }

  Future<String?> removeParticipantFromMeeting(String userId) async {
    if (state.meetingId.isEmpty) {
      return null;
    }
    final result = await ref
        .read(participantsRepositoryProvider)
        .removeParticipant(state.meetingId, userId);
    return result.when(
      success: (_) => null,
      failure: (exception) => exception.message,
    );
  }
  // endregion

  // region: SESSION LIFECYCLE
  void clearJoinError() {
    if (state.errorMessage != null || state.isJoining) {
      state = state.copyWith(isJoining: false, errorMessage: null);
    }
  }

  void _subscribeCallStreams(String meetingId, {required bool isHost}) {
    _closeSubscriptions();
    _participantsSub = ref.listen<AsyncValue<List<MeetingParticipant>>>(
      meetingParticipantsProvider(meetingId),
      (_, next) {
        final liveParticipants = next.asData?.value;
        if (liveParticipants != null) {
          final self = liveParticipants.where((p) => p.isSelf).firstOrNull;
          state = state.copyWith(
            participants: liveParticipants,
            isMicOn: self != null ? !self.isMuted : state.isMicOn,
            isCameraOn: self != null ? !self.isCameraOff : state.isCameraOn,
            isHandRaised: self != null ? self.handRaised : state.isHandRaised,
          );
        }
      },
      fireImmediately: true,
    );

    if (isHost) {
      _waitingSub = ref.listen<AsyncValue<List<MeetingParticipant>>>(
        waitingRequestsProvider(meetingId),
        (_, next) {
          final waiting = next.asData?.value;
          if (waiting != null) {
            state = state.copyWith(waitingRequests: waiting);
          }
        },
        fireImmediately: true,
      );
    }
  }

  Future<String?> requestJoin({
    required String code,
    required String title,
  }) async {
    state = state.copyWith(
      code: code,
      title: title,
      isJoining: true,
      errorMessage: null,
    );

    final result = await ref.read(meetingRepositoryProvider).requestJoin(code);

    return result.when(
      success: (joinResult) async {
        final meeting = joinResult.meeting;
        final currentUid = ref.read(authControllerProvider).asData?.value?.id;
        final isHost = currentUid != null && meeting.hostId == currentUid;

        state = state.copyWith(
          meetingId: meeting.id,
          code: meeting.code,
          title: meeting.title.isNotEmpty ? meeting.title : title,
          hostId: meeting.hostId,
          isHost: isHost,
          isJoining: false,
          participants: meeting.participants,
          waitingRequests: const <MeetingParticipant>[],
        );

        if (joinResult.isAdmitted) {
          await activateAdmittedCall(meeting.id, isHost: isHost);
        }

        return joinResult.participantStatus;
      },
      failure: (exception) {
        state = state.copyWith(
          isJoining: false,
          errorMessage: exception.message,
        );
        return null;
      },
    );
  }

  Future<void> activateAdmittedCall(
    String meetingId, {
    bool? isHost,
  }) async {
    final resolvedHost = isHost ?? state.isHost;
    _subscribeCallStreams(meetingId, isHost: resolvedHost);
    await _syncMyState(
      isMuted: !state.isMicOn,
      isCameraOff: !state.isCameraOn,
      handRaised: state.isHandRaised,
    );
  }

  Future<void> ensureJoined(String code) async {
    if (state.code == code && state.participants.isNotEmpty) {
      return;
    }
    await requestJoin(code: code, title: 'Meeting ($code)');
  }

  Future<void> sendHeartbeat() async {
    final meetingId = state.meetingId;
    if (meetingId.isEmpty) {
      return;
    }
    await ref.read(participantsRepositoryProvider).heartbeat(meetingId);
  }

  Future<void> cancelJoinRequest() async {
    final meetingId = state.meetingId;
    if (meetingId.isNotEmpty) {
      await ref.read(meetingRepositoryProvider).cancelJoinRequest(meetingId);
    }
    _resetSessionState();
  }

  Future<void> leaveCall() async {
    _closeSubscriptions();
    final activeId = state.meetingId;
    if (activeId.isNotEmpty) {
      await ref.read(meetingRepositoryProvider).leaveMeeting(activeId);
    }
    _resetSessionState();
    ref.invalidate(upcomingMeetingsProvider);
  }

  Future<void> endCall() async {
    _closeSubscriptions();
    final activeId = state.meetingId;
    if (activeId.isNotEmpty) {
      await ref.read(meetingRepositoryProvider).endMeeting(activeId);
    }
    _resetSessionState();
    ref.invalidate(upcomingMeetingsProvider);
  }

  void clearAfterRemoteEnd() {
    _closeSubscriptions();
    _resetSessionState();
    ref.invalidate(upcomingMeetingsProvider);
  }

  void leaveSilentlyIfActive(String meetingId) {
    _closeSubscriptions();
    if (meetingId.isEmpty) {
      return;
    }
    Future<void>.microtask(() async {
      await ref.read(meetingRepositoryProvider).leaveMeeting(meetingId);
      ref.invalidate(upcomingMeetingsProvider);
    });
  }

  void _resetSessionState() {
    final defaults = ref.read(settingsProvider);
    state = MeetingSessionState(
      isMicOn: defaults.defaultMicOn,
      isCameraOn: defaults.defaultCameraOn,
      isFrontCamera: state.isFrontCamera,
      audioOutput: state.audioOutput,
    );
  }
  // endregion
}
