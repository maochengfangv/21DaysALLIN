import 'package:flutter/material.dart';

import 'loading_controller.dart';

final class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LoadingController.instance.listenable,
      builder: (context, count, _) {
        final isLoading = count > 0;
        return Stack(
          children: [
            child,
            if (isLoading)
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: ColoredBox(
                    color: Colors.black.withOpacity(0.18),
                    child: const Center(
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
