import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protect_jnu/features/sos/domain/sos_alert.dart';
import 'package:protect_jnu/features/sos/domain/sos_flow.dart';

SosAlert _alert() =>
    SosAlert(id: 'a1', status: AlertStatus.active, startedAt: DateTime.utc(2026, 11, 9));

void main() {
  late List<SosFlowState> states;
  late int sendCalls;
  late GeoFix? sentFix;
  late int fetchCalls;
  late Future<GeoFix?> Function() fetch;
  late Future<SosAlert> Function(GeoFix?) send;

  SosFlow build() => SosFlow(
    fetchLocation: () {
      fetchCalls++;
      return fetch();
    },
    send: (fix) {
      sendCalls++;
      sentFix = fix;
      return send(fix);
    },
    onState: states.add,
    errorMessage: (e) => 'failed: $e',
  );

  setUp(() {
    states = [];
    sendCalls = 0;
    fetchCalls = 0;
    sentFix = null;
    fetch = () async => const GeoFix(latitude: 23.7, longitude: 90.4, accuracy: 5);
    send = (_) async => _alert();
  });

  test('a short press does nothing: no countdown, no location request, no alert', () {
    fakeAsync((async) {
      final flow = build()..pressStart();
      async.elapse(const Duration(milliseconds: 1500));
      flow.pressEnd();
      async.elapse(const Duration(seconds: 20));
      expect(flow.state, isA<SosIdle>());
      expect(fetchCalls, 0);
      expect(sendCalls, 0);
    });
  });

  test('holding 2 s starts the 5 s window; the alert is created only after the window ends', () {
    fakeAsync((async) {
      final flow = build()..pressStart();
      async.elapse(const Duration(milliseconds: 2100));
      expect(flow.state, isA<SosCountdown>());
      expect((flow.state as SosCountdown).secondsLeft, 5);
      expect(fetchCalls, 1, reason: 'location is requested when the window starts');
      async.elapse(const Duration(seconds: 4));
      expect(sendCalls, 0, reason: 'nothing is sent inside the window');
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(sendCalls, 1);
      expect(sentFix?.latitude, 23.7);
      final last = flow.state as SosSent;
      expect(last.withLocation, isTrue);
      flow.dispose();
    });
  });

  test('hold progress rises from 0 to 1 and releasing after the hold completes does not cancel', () {
    fakeAsync((async) {
      final flow = build()..pressStart();
      async.elapse(const Duration(seconds: 1));
      final progress = (flow.state as SosHolding).progress;
      expect(progress, closeTo(0.5, 0.06));
      async.elapse(const Duration(milliseconds: 1100));
      flow.pressEnd(); // finger lifted after 2 s: the window is already running
      expect(flow.state, isA<SosCountdown>());
      flow.dispose();
    });
  });

  test('cancel inside the window creates no alert and drops the location', () {
    fakeAsync((async) {
      final flow = build()..pressStart();
      async.elapse(const Duration(milliseconds: 2100));
      async.elapse(const Duration(seconds: 3));
      flow.cancel();
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      expect(flow.state, isA<SosIdle>());
      expect(sendCalls, 0);
    });
  });

  test('location denied (null) still sends the alert, without coordinates (D-059)', () {
    fetch = () async => null;
    fakeAsync((async) {
      final flow = build()..pressStart();
      async.elapse(const Duration(seconds: 8));
      async.flushMicrotasks();
      expect(sendCalls, 1);
      expect(sentFix, isNull);
      expect((flow.state as SosSent).withLocation, isFalse);
      flow.dispose();
    });
  });

  test('a position that never arrives delays the alert by at most the grace time, then sends without it', () {
    final never = Completer<GeoFix?>();
    fetch = () => never.future;
    fakeAsync((async) {
      final flow = build()..pressStart();
      async.elapse(const Duration(seconds: 7)); // 2 hold + 5 window
      expect(flow.state, isA<SosSending>());
      expect(sendCalls, 0);
      async.elapse(const Duration(seconds: 3, milliseconds: 100));
      async.flushMicrotasks();
      expect(sendCalls, 1);
      expect(sentFix, isNull);
      flow.dispose();
    });
  });

  test('a send error is reported and the student can try again', () {
    send = (_) async => throw Exception('boom');
    fakeAsync((async) {
      final flow = build()..pressStart();
      async.elapse(const Duration(seconds: 8));
      async.flushMicrotasks();
      expect(flow.state, isA<SosFailed>());
      expect((flow.state as SosFailed).message, contains('boom'));
      send = (_) async => _alert();
      flow.pressStart();
      expect(flow.state, isA<SosHolding>());
      flow.dispose();
    });
  });

  test('a second press while the window or send is running is ignored (no double alert)', () {
    fakeAsync((async) {
      final flow = build()..pressStart();
      async.elapse(const Duration(milliseconds: 2100));
      flow.pressStart();
      async.elapse(const Duration(seconds: 6));
      async.flushMicrotasks();
      expect(sendCalls, 1);
      flow.pressStart();
      expect(sendCalls, 1);
      flow.dispose();
    });
  });
}
