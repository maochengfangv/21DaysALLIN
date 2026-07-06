import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/item_model.dart';

class OptimizedListItem extends StatelessWidget {
  final ItemModel item;
  final ValueListenable<bool> isScrollingListenable;
  final ValueListenable<bool> likedListenable;
  final VoidCallback? onToggleLiked;

  const OptimizedListItem({
    super.key,
    required this.item,
    required this.isScrollingListenable,
    required this.likedListenable,
    this.onToggleLiked,
  });
  
  @override

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RepaintBoundary(
      child:Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: DecoratedBox(
         decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:Row(
              children: [
                _Thumb(
                  id: item.id,
                  url: item.thumbUrl,
                  isScrollingListenable: isScrollingListenable,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Texts(
                    title: item.title,
                    subtitle: item.subtitle,
                  ),
                ),
                _Actions(
                  likedListenable: likedListenable,
                  onToggleLiked: onToggleLiked ?? () {},
                ),
              ]
                
            )
          )
        )
        
      )
    );
      
  }
}

class _Thumb extends StatelessWidget {
  static const double _size = 56;

  final int id;
  final String url;
  final ValueListenable<bool> isScrollingListenable;

  const _Thumb({
    required this.id,
    required this.url,
    required this.isScrollingListenable,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = (_size * dpr).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: _size,
        height: _size,
        child: ValueListenableBuilder<bool>(
          valueListenable: isScrollingListenable,
          builder: (context, isScrolling, _) {
            if (isScrolling) {
              return ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              );
            }

            return CachedNetworkImage(
              imageUrl: url,
              memCacheWidth: cacheSize,
              memCacheHeight: cacheSize,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (context, _) {
                return ColoredBox(
                  color: Theme.of(context).colorScheme.surface,
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
              errorWidget: (context, _, __) {
                return ColoredBox(
                  color: Theme.of(context).colorScheme.surface,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                );
              },
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
            );
          },
        ),
      ),
    );
  }
}

class _Texts extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Texts({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(text: title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        _Subtitle(text: subtitle, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _Title({
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Subtitle extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _Subtitle({
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Actions extends StatelessWidget {
  final ValueListenable<bool> likedListenable;
  final VoidCallback onToggleLiked;

  const _Actions({
    required this.likedListenable,
    required this.onToggleLiked,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: likedListenable,
      builder: (context, liked, _) {
        return IconButton(
          onPressed: onToggleLiked,
          icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
          color: liked ? Theme.of(context).colorScheme.primary : null,
        );
      },
    );
  }
}