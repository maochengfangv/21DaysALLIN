import 'application/ai_chat_controller.dart';
import 'application/cancel_voice_input_use_case.dart';
import 'application/observe_session_events_use_case.dart';
import 'application/pick_image_from_gallery_use_case.dart';
import 'application/send_chat_message_use_case.dart';
import 'application/start_voice_input_use_case.dart';
import 'application/stop_generation_use_case.dart';
import 'domain/repositories/ai_chat_repository.dart';
import 'infrastructure/datasources/mock_sse_chat_data_source.dart';
import 'infrastructure/datasources/mock_websocket_event_data_source.dart';
import 'infrastructure/datasources/system_media_picker_data_source.dart';
import 'infrastructure/datasources/system_voice_input_data_source.dart';
import 'infrastructure/datasources/ws_chat_data_source.dart';
import 'infrastructure/repositories/mock_ai_chat_repository_impl.dart';
import 'infrastructure/repositories/system_media_picker_repository_impl.dart';
import 'infrastructure/repositories/system_voice_input_repository_impl.dart';
import 'infrastructure/repositories/ws_ai_chat_repository_impl.dart';

/// ============================================================
/// 【Composition Root】模块装配入口（四层架构唯一 new 对象的地方）
/// [useWs] = true  → 使用真实 WebSocket Repository（对接文档 §5）
/// [useWs] = false → 使用 Mock 离线实现（不联网也能跑通 Demo）
/// 生产环境必须 [useWs]=true + [useSsl]=true + 配置真实 host/sessionId
/// ============================================================
AiChatController buildAiChatController({
  bool useWs = true,
  String host = 'localhost',
  int port = 8000,
  String sessionId = 'demo_session_001',
  bool useSsl = false,
}) {
  final AiChatRepository repository;
  if (useWs) {
    final dataSource = WsChatDataSource(
      host: host,
      port: port,
      sessionId: sessionId,
      useSsl: useSsl,
    );
    repository = WsAiChatRepositoryImpl(dataSource);
  } else {
    repository = MockAiChatRepositoryImpl(
      sseChatDataSource: MockSseChatDataSource(),
      websocketEventDataSource: MockWebSocketEventDataSource(),
    );
  }

  final mediaPickerRepository = SystemMediaPickerRepositoryImpl(
    dataSource: SystemMediaPickerDataSource(),
  );
  final voiceInputRepository = SystemVoiceInputRepositoryImpl(
    dataSource: SystemVoiceInputDataSource(),
  );
  return AiChatController(
    sendChatMessageUseCase: SendChatMessageUseCase(repository),
    stopGenerationUseCase: StopGenerationUseCase(repository),
    observeSessionEventsUseCase: ObserveSessionEventsUseCase(repository),
    pickImageFromGalleryUseCase:
        PickImageFromGalleryUseCase(mediaPickerRepository),
    startVoiceInputUseCase: StartVoiceInputUseCase(voiceInputRepository),
    cancelVoiceInputUseCase: CancelVoiceInputUseCase(voiceInputRepository),
    disposeRepository: () {
      repository.dispose();
      voiceInputRepository.dispose();
    },
  );
}
