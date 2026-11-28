import 'package:freezed_annotation/freezed_annotation.dart';

import 'meeting_participant.dart';

part 'meeting.freezed.dart';
part 'meeting.g.dart';

@freezed
abstract class Meeting with _$Meeting {
  const Meeting._();

  const factory Meeting({
    required String id,
    required String code,
    required String title,
    required String hostId,
    @Default(false) bool isInstant,
    DateTime? scheduledAt,
    @Default('scheduled') String status,
    DateTime? createdAt,
    DateTime? endedAt,
    DateTime? lastActivityAt,
    @Default('') String hostName,
    @Default(30) int durationMinutes,
    String? notes,
    @Default(<MeetingParticipant>[]) List<MeetingParticipant> participants,
  }) = _Meeting;

  factory Meeting.fromJson(Map<String, dynamic> json) =>
      _$MeetingFromJson(json);

  bool get isLive => status == 'live';

  bool get isEnded => status == 'ended';

  DateTime get startTime => scheduledAt ?? createdAt ?? DateTime.now();

  int get participantCount => participants.length;
}
