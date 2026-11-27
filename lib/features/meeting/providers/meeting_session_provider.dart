import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../settings/providers/settings_provider.dart';
import '../data/models/meeting.dart';
import '../data/models/meeting_participant.dart';
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
    this.isMicOn = true,
    this.isCameraOn = true,
    this.isFrontCamera = true,
    this.isPresenting = false,
    this.isHandRaised = false,
    this.audioOutput = AudioOutputDevice.speaker,
    this.isJoining = false,
    this.errorMessage,
    this.participants = const <MeetingParticipant>[],
  });

  final String meetingId;
  final String code;
  final String title;
  final bool isMicOn;
  final bool isCameraOn;
  final bool isFrontCamera;
  final bool isPresenting;
  final bool isHandRaised;
  final AudioOutputDevice audioOutput;
  final bool isJoining;
  final String? errorMessage;
  final List<MeetingParticipant> participants;

  MeetingSessionState copyWith({
    String? meetingId,
    String? code,
    String? title,
    bool? isMicOn,
    bool? isCameraOn,
    bool? isFrontCamera,
    bool? isPresenting,
    bool? isHandRaised,
    AudioOutputDevice? audioOutput,
    bool? isJoining,
    String? errorMessage,
    List<MeetingParticipant>? participants,
  }) {
    return MeetingSessionState(
      meetingId: meetingId ?? this.meetingId,
      code: code ?? this.code,
      title: title ?? this.title,
      isMicOn: isMicOn ?? this.isMicOn,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isPresenting: isPresenting ?? this.isPresenting,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      audioOutput: audioOutput ?? this.audioOutput,
      isJoining: isJoining ?? this.isJoining,
      errorMessage: errorMessage,
      participants: participants ?? this.participants,
    );
  }
}

@riverpod
Future<Meeting> joinMeeting(Ref ref, String code) async {
  final result = await ref.read(meetingRepositoryProvider).joinByCode(code);
  return result.when(
    success: (meeting) => meeting,
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

@Riverpod(keepAlive: true)
class MeetingSessionNotifier extends _$MeetingSessionNotifier {
  // region: SUBSCRIPTION & BUILD
  ProviderSubscription<AsyncValue<List<MeetingParticipant>>>? _participantsSub;

  @override
  MeetingSessionState build() {
    ref.onDispose(() {
      _participantsSub?.close();
      _participantsSub = null;
    });
    final defaults = ref.read(settingsProvider);
    return MeetingSessionState(
      isMicOn: defaults.defaultMicOn,
      isCameraOn: defaults.defaultCameraOn,
    );
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

  // region: PARTICIPANT MODERATION
  Future<void> muteParticipant(String participantId) async {
    final target = state.participants
        .where((p) => p.id == participantId)
        .firstOrNull;
    if (target == null) {
      return;
    }
    if (target.isSelf) {
      if (state.isMicOn) {
        toggleMic();
      }
      return;
    }
    state = state.copyWith(
      participants: state.participants
          .map(
            (p) => p.id == participantId
                ? p.copyWith(isMuted: true, isSpeaking: false)
                : p,
          )
          .toList(),
    );
  }

  Future<void> removeParticipant(String participantId) async {
    state = state.copyWith(
      participants: state.participants
          .where((p) => p.id != participantId || p.isSelf)
          .toList(),
    );
  }
  // endregion

  // region: SESSION LIFECYCLE
  void _subscribeParticipants(String meetingId) {
    _participantsSub?.close();
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
  }

  Future<bool> joinMeeting({
    required String code,
    required String title,
  }) async {
    state = state.copyWith(
      code: code,
      title: title,
      isJoining: true,
      errorMessage: null,
    );

    final result = await ref.read(meetingRepositoryProvider).joinByCode(code);

    return result.when(
      success: (meeting) async {
        final initialParticipants = meeting.participants;
        state = state.copyWith(
          meetingId: meeting.id,
          code: meeting.code,
          title: meeting.title.isNotEmpty ? meeting.title : title,
          isJoining: false,
          participants: initialParticipants,
        );
        _subscribeParticipants(meeting.id);
        await ref
            .read(participantsRepositoryProvider)
            .updateMyState(
              meeting.id,
              isMuted: !state.isMicOn,
              isCameraOff: !state.isCameraOn,
              handRaised: state.isHandRaised,
            );
        return true;
      },
      failure: (exception) {
        state = state.copyWith(
          isJoining: false,
          errorMessage: exception.message,
        );
        return false;
      },
    );
  }

  Future<void> ensureJoined(String code) async {
    if (state.code == code && state.participants.isNotEmpty) {
      return;
    }
    await joinMeeting(code: code, title: 'Meeting ($code)');
  }

  Future<void> leaveCall() async {
    _participantsSub?.close();
    _participantsSub = null;
    final activeId = state.meetingId.isNotEmpty ? state.meetingId : state.code;
    if (activeId.isNotEmpty) {
      await ref.read(meetingRepositoryProvider).leaveMeeting(activeId);
    }
    final defaults = ref.read(settingsProvider);
    state = MeetingSessionState(
      isMicOn: defaults.defaultMicOn,
      isCameraOn: defaults.defaultCameraOn,
      isFrontCamera: state.isFrontCamera,
      audioOutput: state.audioOutput,
    );
  }

  Future<void> endCall() async {
    _participantsSub?.close();
    _participantsSub = null;
    final activeId = state.meetingId.isNotEmpty ? state.meetingId : state.code;
    if (activeId.isNotEmpty) {
      await ref.read(meetingRepositoryProvider).endMeeting(activeId);
    }
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
