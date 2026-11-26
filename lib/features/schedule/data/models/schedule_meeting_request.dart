import 'package:freezed_annotation/freezed_annotation.dart';

part 'schedule_meeting_request.freezed.dart';
part 'schedule_meeting_request.g.dart';

@freezed
abstract class ScheduleMeetingRequest with _$ScheduleMeetingRequest {
  const factory ScheduleMeetingRequest({
    required String title,
    required DateTime startTime,
    required int durationMinutes,
    @Default(<String>[]) List<String> invitees,
    String? notes,
  }) = _ScheduleMeetingRequest;

  factory ScheduleMeetingRequest.fromJson(Map<String, dynamic> json) =>
      _$ScheduleMeetingRequestFromJson(json);
}
