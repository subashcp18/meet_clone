import 'package:freezed_annotation/freezed_annotation.dart';

import 'participant_model.dart';

part 'meeting_lobby_info.freezed.dart';
part 'meeting_lobby_info.g.dart';

@freezed
abstract class MeetingLobbyInfo with _$MeetingLobbyInfo {
  const factory MeetingLobbyInfo({
    required String code,
    required String title,
    required List<ParticipantModel> waitingParticipants,
  }) = _MeetingLobbyInfo;

  factory MeetingLobbyInfo.fromJson(Map<String, dynamic> json) =>
      _$MeetingLobbyInfoFromJson(json);
}
