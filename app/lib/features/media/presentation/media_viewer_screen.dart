import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/utils/extensions.dart';
import '../../../shared/widgets/feedback/app_feedback.dart';
import '../domain/media_item.dart';
import '../media_providers.dart';

/// Full-size photo or video playback, with delete (confirmed).
class MediaViewerScreen extends ConsumerStatefulWidget {
  const MediaViewerScreen({required this.mediaId, super.key});

  final String mediaId;

  @override
  ConsumerState<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> {
  VideoPlayerController? _video;
  String? _videoFor;

  void _prepare(MediaItem item) {
    if (item.type != MediaType.video || _videoFor == item.id) return;
    _videoFor = item.id;
    final controller = VideoPlayerController.file(File(item.path));
    _video = controller;
    controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  Future<void> _delete(MediaItem item) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this file?',
      message: 'It is removed from this phone and cannot be recovered.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    await _video?.dispose();
    _video = null;
    await ref.read(mediaListProvider.notifier).remove(item.id);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final item = ref
        .watch(mediaListProvider)
        .value
        ?.where((i) => i.id == widget.mediaId)
        .firstOrNull;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Media')),
        body: const Center(child: Text('This file is no longer available.')),
      );
    }
    _prepare(item);
    final video = _video;
    return Scaffold(
      appBar: AppBar(
        title: Text(item.capturedAt.toLocal().formatted),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(item),
          ),
        ],
      ),
      body: Center(
        child: item.type == MediaType.photo
            ? InteractiveViewer(child: Image.file(File(item.path)))
            : video != null && video.value.isInitialized
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(aspectRatio: video.value.aspectRatio, child: VideoPlayer(video)),
                  IconButton(
                    iconSize: 48,
                    icon: Icon(video.value.isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: () {
                      video.value.isPlaying ? video.pause() : video.play();
                      setState(() {});
                    },
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
