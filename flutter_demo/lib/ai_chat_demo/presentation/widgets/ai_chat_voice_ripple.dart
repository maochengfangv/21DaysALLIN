import 'package:flutter/material.dart';

class AiChatVoiceRipple extends StatefulWidget {
  const AiChatVoiceRipple({super.key});

  @override
  State<AiChatVoiceRipple> createState() => _AiChatVoiceRippleState();
}

class _AiChatVoiceRippleState extends State<AiChatVoiceRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildRipple(double offset, Color color) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = (_controller.value + offset) % 1.0;
        final scale = 0.45 + progress * 1.15;
        final opacity = (1 - progress).clamp(0.0, 1.0).toDouble();

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.18),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: 144,
      height: 144,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildRipple(0.0, color),
          _buildRipple(0.33, color),
          _buildRipple(0.66, color),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mic,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}