import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:protect_jnu/features/location/data/location_queue.dart';
import 'package:protect_jnu/features/location/data/location_uploader.dart';
import 'package:protect_jnu/features/location/domain/location_point.dart';
import 'package:protect_jnu/features/location/domain/location_sharing.dart';

class _Source implements PositionSource {
  final controller = StreamController<LocationPoint>();
  bool get listening => controller.hasListener;

  @override
  Stream<LocationPoint> start() => controller.stream;
}

class _Uploader implements LocationUploader {
  UploadOutcome next = UploadOutcome.sent;
  final sent = <LocationPoint>[];
  int calls = 0;

  @override
  Future<UploadOutcome> upload({
    required String alertId,
    required String userId,
    required List<LocationPoint> points,
  }) async {
    calls++;
    if (next == UploadOutcome.sent) sent.addAll(points);
    return next;
  }
}

LocationPoint _p(int second) => LocationPoint(
  latitude: 23.7 + second / 1000,
  longitude: 90.4,
  recordedAt: DateTime.utc(2026, 11, 9, 12, 0, second),
);

void main() {
  late _Source source;
  late _Uploader uploader;
  late InMemoryLocationQueue queue;
  late LocationSharing sharing;
  var rejected = 0;

  setUp(() {
    source = _Source();
    uploader = _Uploader();
    queue = InMemoryLocationQueue();
    rejected = 0;
    sharing = LocationSharing(
      source: source,
      queue: queue,
      uploader: uploader,
      onRejected: () => rejected++,
    );
  });

  Future<void> emit(LocationPoint p) async {
    source.controller.add(p);
    await Future<void>.delayed(Duration.zero);
    await sharing.settle();
  }

  test('online: each point is sent and the queue stays empty', () async {
    sharing.start(alertId: 'a1', userId: 'u1');
    await emit(_p(1));
    await emit(_p(2));
    expect(uploader.sent.map((p) => p.recordedAt.second), [1, 2]);
    expect(await queue.count('a1'), 0);
  });

  test('offline: points are kept, then arrive in order after reconnect', () async {
    sharing.start(alertId: 'a1', userId: 'u1');
    uploader.next = UploadOutcome.retry;
    await emit(_p(1));
    await emit(_p(2));
    await emit(_p(3));
    expect(uploader.sent, isEmpty);
    expect(await queue.count('a1'), 3);

    uploader.next = UploadOutcome.sent;
    await emit(_p(4));
    expect(uploader.sent.map((p) => p.recordedAt.second), [1, 2, 3, 4]);
    expect(await queue.count('a1'), 0);
  });

  test('queue keeps only the newest 500 points', () async {
    for (var i = 0; i < 510; i++) {
      await queue.add('a1', _p(i % 60).copyAt(i));
    }
    expect(await queue.count('a1'), LocationQueue.maxPoints);
    final oldest = await queue.oldest('a1', limit: 1);
    expect(oldest.first.recordedAt, DateTime.utc(2026, 11, 9, 12).add(const Duration(seconds: 10)));
  });

  test('leftover points from an earlier run are flushed on start', () async {
    await queue.add('a1', _p(1));
    uploader.next = UploadOutcome.sent;
    sharing.start(alertId: 'a1', userId: 'u1');
    await sharing.settle();
    expect(uploader.sent, hasLength(1));
  });

  test('server refusal drops the queue, stops the service and reports', () async {
    sharing.start(alertId: 'a1', userId: 'u1');
    uploader.next = UploadOutcome.rejected;
    await emit(_p(1));
    expect(rejected, 1);
    expect(await queue.count('a1'), 0);
    expect(sharing.isRunning, isFalse);
    expect(source.listening, isFalse);
  });

  test('stop cancels the position stream and later points are ignored', () async {
    sharing.start(alertId: 'a1', userId: 'u1');
    expect(source.listening, isTrue);
    sharing.stop();
    expect(source.listening, isFalse);
    expect(uploader.calls, 0);
  });

  test('starting twice for the same alert keeps one subscription', () async {
    sharing.start(alertId: 'a1', userId: 'u1');
    sharing.start(alertId: 'a1', userId: 'u1');
    await emit(_p(1));
    expect(uploader.sent, hasLength(1));
  });
}

extension on LocationPoint {
  LocationPoint copyAt(int index) => LocationPoint(
    latitude: latitude,
    longitude: longitude,
    recordedAt: DateTime.utc(2026, 11, 9, 12).add(Duration(seconds: index)),
  );
}
