import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../settings/providers/settings_provider.dart';
import '../data/models/meeting_lobby_info.dart';
import '../data/models/participant_model.dart';
import '../data/repositories/meeting_repository.dart';

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
    this.participants = const <ParticipantModel>[],
  });

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
  final List<ParticipantModel> participants;

  MeetingSessionState copyWith({
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
    List<ParticipantModel>? participants,
  }) {
    return MeetingSessionState(
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
Future<MeetingLobbyInfo> meetingLobby(Ref ref, String code) async {
  final result = await ref.read(meetingRepositoryProvider).getLobbyInfo(code);
  return result.when(
    success: (info) => info,
    failure: (exception) => throw exception,
  );
}

@Riverpod(keepAlive: true)
class MeetingSessionNotifier extends _$MeetingSessionNotifier {
  // region: BUILD
  @override
  MeetingSessionState build() {
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
  }

  void toggleCamera() {
    final nextCamera = !state.isCameraOn;
    state = state.copyWith(
      isCameraOn: nextCamera,
      participants: _updateSelf(
        (self) => self.copyWith(isVideoOn: nextCamera),
      ),
    );
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
        (self) => self.copyWith(isHandRaised: nextRaised),
      ),
    );
  }

  void setAudioOutput(AudioOutputDevice device) {
    state = state.copyWith(audioOutput: device);
  }

  void setDefaults({required bool micOn, required bool cameraOn}) {
    state = state.copyWith(
      isMicOn: micOn,
      isCameraOn: cameraOn,
      participants: _updateSelf(
        (self) => self.copyWith(isMuted: !micOn, isVideoOn: cameraOn),
      ),
    );
  }

  List<ParticipantModel> _updateSelf(
    ParticipantModel Function(ParticipantModel self) transform,
  ) {
    return state.participants
        .map((participant) => participant.isSelf ? transform(participant) : participant)
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
    final result = await ref
        .read(meetingRepositoryProvider)
        .muteParticipant(state.code, participantId);
    result.when(
      success: (_) {
        state = state.copyWith(
          participants: state.participants
              .map(
                (p) => p.id == participantId
                    ? p.copyWith(isMuted: true, isSpeaking: false)
                    : p,
              )
              .toList(),
        );
      },
      failure: (exception) {
        state = state.copyWith(errorMessage: exception.message);
      },
    );
  }

  Future<void> removeParticipant(String participantId) async {
    final result = await ref
        .read(meetingRepositoryProvider)
        .removeParticipant(state.code, participantId);
    result.when(
      success: (_) {
        state = state.copyWith(
          participants: state.participants
              .where((p) => p.id != participantId || p.isSelf)
              .toList(),
        );
      },
      failure: (exception) {
        state = state.copyWith(errorMessage: exception.message);
      },
    );
  }
  // endregion

  // region: SESSION LIFECYCLE
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

    final result = await ref.read(meetingRepositoryProvider).joinMeeting(
      code,
      micOn: state.isMicOn,
      cameraOn: state.isCameraOn,
    );

    return result.when(
      success: (participants) {
        state = state.copyWith(
          isJoining: false,
          participants: participants,
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
    final activeCode = state.code;
    if (activeCode.isNotEmpty) {
      await ref.read(meetingRepositoryProvider).leaveMeeting(activeCode);
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
