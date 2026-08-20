import 'message_content_format.dart';

enum ChatRole { user, assistant, system }

enum ChatMessageStatus {
  ready,
  pending,
  streaming,
  completed,
  canceled,
  failed,
}

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final ChatMessageStatus status;
  final MessageContentFormat contentFormat;
  final String? errorMessage;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.status = ChatMessageStatus.ready,
    this.contentFormat = MessageContentFormat.plainText,
    this.errorMessage,
  });

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    DateTime? createdAt,
    ChatMessageStatus? status,
    MessageContentFormat? contentFormat,
    String? errorMessage,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      contentFormat: contentFormat ?? this.contentFormat,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
