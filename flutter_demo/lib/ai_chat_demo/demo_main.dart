import 'package:flutter/material.dart';

import 'application/ai_chat_controller.dart';
import 'application/observe_session_events_use_case.dart';
import 'application/send_chat_message_use_case.dart';
import 'application/stop_generation_use_case.dart';
import 'infrastructure/datasources/mock_sse_chat_data_source.dart';
import 'infrastructure/datasources/mock_websocket_event_data_source.dart';
import 'infrastructure/repositories/mock_ai_chat_repository_impl.dart';
import 'presentation/ai_chat_demo_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = MockAiChatRepositoryImpl(
    sseChatDataSource: MockSseChatDataSource(),
    websocketEventDataSource: MockWebSocketEventDataSource(),
  );

  final controller = AiChatController(
    sendChatMessageUseCase: SendChatMessageUseCase(repository),
    stopGenerationUseCase: StopGenerationUseCase(repository),
    observeSessionEventsUseCase: ObserveSessionEventsUseCase(repository),
    disposeRepository: repository.dispose,
  );

  runApp(AiChatDemoApp(controller: controller));
}

class AiChatDemoApp extends StatelessWidget {
  final AiChatController controller;

  const AiChatDemoApp({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Chat SSE & WebSocket Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: AiChatDemoPage(controller: controller),
    );
  }
}