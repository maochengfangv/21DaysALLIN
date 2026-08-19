import 'application/ai_chat_controller.dart';
import 'application/observe_session_events_use_case.dart';
import 'application/send_chat_message_use_case.dart';
import 'application/stop_generation_use_case.dart';
import 'infrastructure/datasources/mock_sse_chat_data_source.dart';
import 'infrastructure/datasources/mock_websocket_event_data_source.dart';
import 'infrastructure/repositories/mock_ai_chat_repository_impl.dart';

AiChatController buildAiChatController() {
  final repository = MockAiChatRepositoryImpl(
    sseChatDataSource: MockSseChatDataSource(),
    websocketEventDataSource: MockWebSocketEventDataSource(),
  );

  return AiChatController(
    sendChatMessageUseCase: SendChatMessageUseCase(repository),
    stopGenerationUseCase: StopGenerationUseCase(repository),
    observeSessionEventsUseCase: ObserveSessionEventsUseCase(repository),
    disposeRepository: repository.dispose,
  );
}