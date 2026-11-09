import 'dart:async';

import '../data/location_queue.dart';
import '../data/location_uploader.dart';
import 'location_point.dart';

/// Source of positions (the real one runs a foreground service, see `GeolocatorPositionSource`).
abstract interface class PositionSource {
  /// Starts the foreground service and emits one point per interval. Cancelling the
  /// subscription stops the service.
  Stream<LocationPoint> start();
}

/// While an alert is open: every point goes into the persistent queue first, then the queue is
/// flushed in order. A failed flush leaves the points for the next attempt, so going offline
/// loses nothing (up to the queue bound).
class LocationSharing {
  LocationSharing({
    required this.source,
    required this.queue,
    required this.uploader,
    this.onRejected,
  });

  final PositionSource source;
  final LocationQueue queue;
  final LocationUploader uploader;

  /// The server refused the points for good; sharing has already stopped.
  final void Function()? onRejected;

  StreamSubscription<LocationPoint>? _sub;
  String? _alertId;
  Future<void> _chain = Future.value();

  bool get isRunning => _sub != null;

  void start({required String alertId, required String userId}) {
    if (_alertId == alertId && _sub != null) return;
    stop();
    _alertId = alertId;
    _sub = source.start().listen((p) {
      // Serialised so points and flushes never interleave.
      _chain = _chain.then((_) => _handle(alertId, userId, p));
    });
    _chain = _chain.then((_) => flush(alertId, userId)); // leftovers from an earlier run
  }

  /// Stops the position stream (and with it the foreground service).
  void stop() {
    _sub?.cancel();
    _sub = null;
    _alertId = null;
  }

  Future<void> _handle(String alertId, String userId, LocationPoint p) async {
    if (_alertId != alertId) return; // stopped meanwhile
    await queue.add(alertId, p);
    await flush(alertId, userId);
  }

  /// Sends everything queued, oldest first, in batches. Stops at the first failure.
  Future<void> flush(String alertId, String userId) async {
    while (true) {
      final batch = await queue.oldest(alertId);
      if (batch.isEmpty) return;
      final outcome = await uploader.upload(alertId: alertId, userId: userId, points: batch);
      switch (outcome) {
        case UploadOutcome.sent:
          await queue.remove([for (final p in batch) p.id!]);
        case UploadOutcome.retry:
          return;
        case UploadOutcome.rejected:
          await queue.clear(alertId);
          stop();
          onRejected?.call();
          return;
      }
    }
  }

  /// Lets queued work finish (tests, shutdown).
  Future<void> settle() => _chain;
}
