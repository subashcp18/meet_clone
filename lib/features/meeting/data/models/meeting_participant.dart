import 'package:freezed_annotation/freezed_annotation.dart';

part 'meeting_participant.freezed.dart';
part 'meeting_participant.g.dart';

@freezed
abstract class MeetingParticipant with _$MeetingParticipant {
  const MeetingParticipant._();

  const factory MeetingParticipant({
    required String meetingId,
    required String userId,
    DateTime? joinedAt,
    DateTime? leftAt,
    @Default(false) bool isMuted,
    @Default(false) bool isCameraOff,
    @Default(false) bool handRaised,
    @Default('') String displayName,
    String? avatarUrl,
    @Default('') String email,
    @Default(false) bool isHost,
    @Default(false) bool isSelf,
    @Default(false) bool isSpeaking,
  }) = _MeetingParticipant;

  factory MeetingParticipant.fromJson(Map<String, dynamic> json) =>
      _$MeetingParticipantFromJson(json);

  String get id => userId;

  String get name => displayName.isNotEmpty ? displayName : 'Participant';

  bool get isVideoOn => !isCameraOff;

  bool get isHandRaised => handRaised;

  bool get isActive => leftAt == null;
}
