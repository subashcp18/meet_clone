import 'package:freezed_annotation/freezed_annotation.dart';

part 'open_meeting.freezed.dart';
part 'open_meeting.g.dart';

@freezed
abstract class OpenMeeting with _$OpenMeeting {
  const OpenMeeting._();

  const factory OpenMeeting({
    required String id,
    required String code,
    required String title,
    required String status,
    @Default(false) bool isInstant,
    DateTime? scheduledAt,
    DateTime? createdAt,
    DateTime? lastActivityAt,
    required String hostId,
    @Default('Host') String hostName,
    @Default(false) bool hostInCall,
    @Default(0) int activeParticipantCount,
    @Default(false) bool amIHost,
    @Default(30) int durationMinutes,
  }) = _OpenMeeting;

  factory OpenMeeting.fromJson(Map<String, dynamic> json) =>
      _$OpenMeetingFromJson(json);

  bool get isLive => status == 'live';

  DateTime get startTime => scheduledAt ?? createdAt ?? DateTime.now();
}
