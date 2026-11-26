import 'package:freezed_annotation/freezed_annotation.dart';

part 'meeting_summary.freezed.dart';
part 'meeting_summary.g.dart';

@freezed
abstract class MeetingSummary with _$MeetingSummary {
  const factory MeetingSummary({
    required String id,
    required String title,
    required String code,
    required DateTime startTime,
    required int durationMinutes,
    required String hostName,
    required int participantCount,
    @Default(false) bool isLive,
  }) = _MeetingSummary;

  factory MeetingSummary.fromJson(Map<String, dynamic> json) =>
      _$MeetingSummaryFromJson(json);
}
