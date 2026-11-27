import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

@freezed
abstract class ChatMessage with _$ChatMessage {
  const ChatMessage._();

  const factory ChatMessage({
    required String id,
    required String meetingId,
    required String userId,
    required String body,
    required DateTime createdAt,
    @Default('') String senderName,
    @Default(false) bool isSelf,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

  String get displaySender =>
      senderName.isNotEmpty ? senderName : 'Participant';
}
