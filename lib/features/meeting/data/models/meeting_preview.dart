import 'package:freezed_annotation/freezed_annotation.dart';

part 'meeting_preview.freezed.dart';
part 'meeting_preview.g.dart';

@freezed
abstract class MeetingPreviewParticipant with _$MeetingPreviewParticipant {
  const factory MeetingPreviewParticipant({
    required String displayName,
    String? avatarUrl,
  }) = _MeetingPreviewParticipant;

  factory MeetingPreviewParticipant.fromJson(Map<String, dynamic> json) =>
      _$MeetingPreviewParticipantFromJson(json);
}

@freezed
abstract class MeetingPreview with _$MeetingPreview {
  const MeetingPreview._();

  const factory MeetingPreview({
    required String id,
    required String code,
    required String title,
    required String status,
    required String hostId,
    @Default('Host') String hostName,
    @Default(false) bool hostInCall,
    @Default(false) bool isInstant,
    DateTime? scheduledAt,
    DateTime? createdAt,
    @Default(<MeetingPreviewParticipant>[])
    List<MeetingPreviewParticipant> previewParticipants,
  }) = _MeetingPreview;

  factory MeetingPreview.fromJson(Map<String, dynamic> json) =>
      _$MeetingPreviewFromJson(json);
}
