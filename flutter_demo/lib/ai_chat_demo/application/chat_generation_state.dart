sealed class ChatGenerationState {
  const ChatGenerationState({this.assistantMessageId});

  final String? assistantMessageId;

  bool get isInFlight => switch (this) {
     IdleState() ||
        CompletedState() ||
        CanceledState() ||
        FailedState() =>
          false,
        PreparingState() || StreamingState() || StoppingState() => true,
  };

  bool get canSend => !isInFlight;

  bool get canStop => switch (this) {
    PreparingState() || StreamingState() || StoppingState() => true,
    _ => false,
  };

  String get label => switch (this) {

      IdleState() => 'SSE 空闲',
      PreparingState() => 'SSE 准备中',
      StreamingState() => 'SSE 输出中',
      StoppingState() => 'SSE 停止中',
      CompletedState() => 'SSE 已完成',
      CanceledState() => 'SSE 已取消',
      FailedState() => 'SSE 失败',
  };
}

final class IdleState extends ChatGenerationState {
  const IdleState();
}

final class PreparingState extends ChatGenerationState {
  const PreparingState({
    required super.assistantMessageId,
    required this.step,
  });

  final String step;
}

final class StreamingState extends ChatGenerationState {
  const StreamingState({
    required super.assistantMessageId,
    required this.receivedChars,
  });
  final int receivedChars;
}

final class StoppingState extends ChatGenerationState {
  const StoppingState({required super.assistantMessageId});
}

final class CompletedState extends ChatGenerationState {
  const CompletedState({required super.assistantMessageId});
}

final class CanceledState extends ChatGenerationState {
  const CanceledState({
    required super.assistantMessageId,
    required this.reason,
  });

  final String reason;
}

final class FailedState extends ChatGenerationState {
  const FailedState({
    required super.assistantMessageId,
    required this.error,
  });

  final String error;
}
