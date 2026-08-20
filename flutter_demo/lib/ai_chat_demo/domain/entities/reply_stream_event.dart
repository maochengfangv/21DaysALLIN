import 'message_content_format.dart';

sealed class ReplyStreamEvent {
  const ReplyStreamEvent({required this.messageId});

  final String messageId;
}

final class ReplyStarted extends ReplyStreamEvent {
  const ReplyStarted({
    required super.messageId,
    this.contentFormat = MessageContentFormat.plainText,
  });

  final MessageContentFormat contentFormat;
}

final class ReplyStatus extends ReplyStreamEvent {
  const ReplyStatus({required super.messageId, required this.text});

  final String text;
}

final class ReplyDelta extends ReplyStreamEvent {
  const ReplyDelta({required super.messageId, required this.text});

  final String text;
}

final class ReplyFinished extends ReplyStreamEvent {
  const ReplyFinished({required super.messageId});
}

final class ReplyCanceled extends ReplyStreamEvent {
  const ReplyCanceled({required super.messageId, required this.reason});

  final String reason;
} 

final class ReplyFailed extends ReplyStreamEvent {
  const ReplyFailed({required super.messageId, required this.error});

  final String error;
}