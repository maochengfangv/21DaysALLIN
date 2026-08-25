import 'application/ai_chat_controller.dart';
import 'application/cancel_voice_input_use_case.dart';
import 'application/observe_session_events_use_case.dart';
import 'application/pick_image_from_gallery_use_case.dart';
import 'application/send_chat_message_use_case.dart';
import 'application/start_voice_input_use_case.dart';
import 'application/stop_generation_use_case.dart';
import 'infrastructure/datasources/mock_sse_chat_data_source.dart';
import 'infrastructure/datasources/mock_websocket_event_data_source.dart';
import 'infrastructure/datasources/system_media_picker_data_source.dart';
import 'infrastructure/datasources/system_voice_input_data_source.dart';
import 'infrastructure/repositories/mock_ai_chat_repository_impl.dart';
import 'infrastructure/repositories/system_media_picker_repository_impl.dart';
import 'infrastructure/repositories/system_voice_input_repository_impl.dart';

AiChatController buildAiChatController() {
  final repository = MockAiChatRepositoryImpl(
    sseChatDataSource: MockSseChatDataSource(),
    websocketEventDataSource: MockWebSocketEventDataSource(),
  );

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
