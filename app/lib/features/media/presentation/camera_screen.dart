import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/feedback/app_feedback.dart';
import '../../sos/sos_providers.dart';
import '../domain/media_item.dart';
import '../media_providers.dart';

/// Photo and video capture. Saves into the app-private store only; nothing is uploaded (D-013).
/// Does not touch the location service, so live location keeps running while this screen is open.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _controller;
  String? _error;
  bool _recording = false;
  bool _busy = false;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _fail('No camera was found on this phone.');
        return;
      }
      final back = cameras.where((c) => c.lensDirection == CameraLensDirection.back);
      final controller = CameraController(
        back.isNotEmpty ? back.first : cameras.first,
        ResolutionPreset.medium, // D-074: medium quality
        enableAudio: true,
      );
      await controller.initialize(); // asks for camera + microphone permission
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      _fail(_describe(e));
    }
  }

  String _describe(CameraException e) {
    final code = e.code.toLowerCase();
    if (code.contains('audio')) {
      return 'Microphone access is needed to record video. Allow it in the phone settings.';
    }
    if (code.contains('denied') || code.contains('permission')) {
      return 'Camera access is off. Allow it in the phone settings to take photos and videos.';
    }
    return 'The camera could not be started.';
  }

  void _fail(String message) {
    if (mounted) setState(() => _error = message);
  }

  /// Alert id only while an alert is open (D-074).
  String? get _openAlertId {
    final alert = ref.read(openAlertProvider).value;
    return alert != null && alert.status.isOpen ? alert.id : null;
  }

  Future<void> _photo() async {
    final c = _controller;
    if (c == null || _busy || _recording) return;
    setState(() => _busy = true);
    try {
      final file = await c.takePicture();
      await ref
          .read(mediaListProvider.notifier)
          .add(sourcePath: file.path, type: MediaType.photo, alertId: _openAlertId);
      if (mounted) showAppSnack(context, 'Photo saved on this phone.');
    } on CameraException catch (_) {
      if (mounted) showAppSnack(context, 'Could not take the photo.', type: SnackType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleVideo() async {
    final c = _controller;
    if (c == null || _busy) return;
    if (_recording) {
      await _stopVideo();
      return;
    }
    try {
      await c.startVideoRecording();
    } on CameraException {
      if (mounted) showAppSnack(context, 'Could not start recording.', type: SnackType.error);
      return;
    }
    setState(() {
      _recording = true;
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
      if (_elapsed >= maxVideoDuration) unawaited(_stopVideo());
    });
  }

  Future<void> _stopVideo() async {
    final c = _controller;
    if (c == null || !_recording) return;
    _ticker?.cancel();
    setState(() {
      _recording = false;
      _busy = true;
    });
    try {
      final file = await c.stopVideoRecording();
      await ref
          .read(mediaListProvider.notifier)
          .add(sourcePath: file.path, type: MediaType.video, alertId: _openAlertId);
      if (mounted) showAppSnack(context, 'Video saved on this phone.');
    } on CameraException {
      if (mounted) showAppSnack(context, 'Could not save the video.', type: SnackType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    final c = _controller;
    if (c != null) {
      // Leaving mid-recording: stop and keep what was recorded rather than lose it.
      if (_recording) {
        final notifier = ref.read(mediaListProvider.notifier);
        final alertId = _openAlertId;
        unawaited(() async {
          try {
            final file = await c.stopVideoRecording();
            await notifier.add(sourcePath: file.path, type: MediaType.video, alertId: alertId);
          } on Object {
            // Nothing usable was recorded; leaving the screen must not throw.
          } finally {
            await c.dispose();
          }
        }());
      } else {
        unawaited(c.dispose());
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Camera')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : c == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: Center(child: CameraPreview(c))),
                if (_recording)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(
                      'Recording ${_elapsed.inSeconds}s / ${maxVideoDuration.inSeconds}s',
                    ),
                  ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Gallery',
                          onPressed: _recording ? null : () => context.pop(),
                          icon: const Icon(Icons.photo_library),
                        ),
                        IconButton.filled(
                          tooltip: 'Take photo',
                          iconSize: 40,
                          onPressed: _busy || _recording ? null : _photo,
                          icon: const Icon(Icons.camera_alt),
                        ),
                        IconButton.filled(
                          tooltip: _recording ? 'Stop recording' : 'Record video',
                          iconSize: 40,
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: _busy ? null : _toggleVideo,
                          icon: Icon(_recording ? Icons.stop : Icons.videocam),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
