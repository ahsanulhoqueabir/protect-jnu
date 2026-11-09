import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../domain/media_item.dart';
import '../media_providers.dart';

/// Grid of the media saved on this phone. Nothing here is shared or uploaded.
class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(mediaListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My photos and videos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.camera),
        icon: const Icon(Icons.camera_alt),
        label: const Text('Camera'),
      ),
      body: media.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load your media.')),
        data: (items) => items.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Nothing here yet. Files you capture stay on this phone only.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.sm),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) => _Tile(item: items[i]),
              ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final isVideo = item.type == MediaType.video;
    return InkWell(
      onTap: () => context.push(Routes.mediaViewFor(item.id)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isVideo)
            ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest)
          else
            Image.file(
              File(item.path),
              fit: BoxFit.cover,
              cacheWidth: 300,
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
            ),
          if (isVideo) const Center(child: Icon(Icons.play_circle_fill, size: 40)),
        ],
      ),
    );
  }
}
