import 'package:flutter/material.dart';

import 'ai_chat_info_card.dart';

class AiChatTopPanel extends StatelessWidget {
  final bool isConnected;
  final int unreadCount;
  final String generationLabel;
  final List<String> latestSteps;
  final List<String> latestEvents;

  const AiChatTopPanel({
    super.key,
    required this.isConnected,
    required this.unreadCount,
    required this.generationLabel,
    required this.latestSteps,
    required this.latestEvents,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: CircleAvatar(
                  backgroundColor: isConnected ? Colors.green : Colors.red,
                  radius: 5,
                ),
                label: Text(
                  isConnected ? 'WebSocket 已连接' : 'WebSocket 未连接',
                ),
              ),
              Chip(label: Text('未读数: $unreadCount')),
              Chip(label: Text(generationLabel)),
            ],
          ),
          const SizedBox(height: 8),
          AiChatInfoCard(
            title: 'SSE 回答流',
            items: latestSteps.isEmpty ? const ['等待发送消息'] : latestSteps,
          ),
          const SizedBox(height: 8),
          AiChatInfoCard(
            title: 'WebSocket 事件流',
            items: latestEvents.isEmpty ? const ['等待实时事件'] : latestEvents,
          ),
        ],
      ),
    );
  }
}