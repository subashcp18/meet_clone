import 'package:freezed_annotation/freezed_annotation.dart';

part 'participant_model.freezed.dart';
part 'participant_model.g.dart';

@freezed
abstract class ParticipantModel with _$ParticipantModel {
  const factory ParticipantModel({
    required String id,
    required String name,
    required String email,
    @Default(false) bool isHost,
    @Default(false) bool isSelf,
    @Default(false) bool isMuted,
    @Default(true) bool isVideoOn,
    @Default(false) bool isHandRaised,
    @Default(false) bool isSpeaking,
  }) = _ParticipantModel;

  factory ParticipantModel.fromJson(Map<String, dynamic> json) =>
      _$ParticipantModelFromJson(json);
}
