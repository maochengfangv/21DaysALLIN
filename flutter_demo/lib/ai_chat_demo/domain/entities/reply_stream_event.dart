enum ReplyStreamEventType {
 started, /// 开始
 status, /// 状态更新
 delta, /// 增量内容
 finished, /// 完成
 failed, /// 失败
}

class ReplyStreamEvent {
  final ReplyStreamEventType type;
  final String messageId;
  final String? text;
  final String? error;

 const ReplyStreamEvent._({
    required this.type,
    required this.messageId,
    this.text,
    this.error,
  });
 
 const ReplyStreamEvent.started({
    required String messageId,
  }) : this._(
    type: ReplyStreamEventType.started,
    messageId: messageId,
  );

const ReplyStreamEvent.status({
    required String messageId,
    required String text,
  }) : this._(
    type: ReplyStreamEventType.status,
    messageId: messageId,
    text: text,
  );

  const ReplyStreamEvent.delta({
    required String messageId,
    required String text,
  }) : this._(
    type: ReplyStreamEventType.delta,
    messageId: messageId,
    text: text,
  );

  const ReplyStreamEvent.finished({
    required String messageId,
  }) : this._(
    type: ReplyStreamEventType.finished,
    messageId: messageId,
  );

  const ReplyStreamEvent.failed({
    required String messageId,
    required String error,
  }) : this._(
    type: ReplyStreamEventType.failed,
    messageId: messageId,
    error: error,
  );

}