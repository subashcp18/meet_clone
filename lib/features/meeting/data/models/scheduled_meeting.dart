import 'package:freezed_annotation/freezed_annotation.dart';

part 'scheduled_meeting.freezed.dart';
part 'scheduled_meeting.g.dart';

@freezed
abstract class ScheduledMeeting with _$ScheduledMeeting {
  const factory ScheduledMeeting({
    required String title,
    required DateTime startTime,
    required int durationMinutes,
    @Default(<String>[]) List<String> invitees,
    String? notes,
  }) = _ScheduledMeeting;

  factory ScheduledMeeting.fromJson(Map<String, dynamic> json) =>
      _$ScheduledMeetingFromJson(json);
}
