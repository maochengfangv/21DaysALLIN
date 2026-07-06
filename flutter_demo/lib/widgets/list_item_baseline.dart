import 'package:flutter/material.dart';

class BaselineListItem extends StatelessWidget {
  final int id;
  final bool highlight;
  final VoidCallback? onToggle;

  const BaselineListItem({
    super.key,
    required this.id,
    this.highlight = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = highlight ? theme.colorScheme.primary.withOpacity(0.08) : null;
    final url = 'https://picsum.photos/seed/$id/400/400';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Opacity(
        opacity: highlight ? 1 : 0.92,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            color: bg ?? theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Baseline Item #$id',
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'This is a heavier widget tree. Tap heart to rebuild whole page.',
                          style: theme.textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              'id=$id',
                              style: theme.textTheme.labelMedium,
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: onToggle,
                              icon: Icon(
                                highlight ? Icons.favorite : Icons.favorite_border,
                                color: highlight ? theme.colorScheme.primary : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}