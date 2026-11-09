import 'dart:async';

import 'sos_alert.dart';

/// Timings. Hold 2 s and cancel window 5 s are PRD values; the location grace is a proposal (D-064).
class SosTimings {
  const SosTimings({
    this.hold = const Duration(seconds: 2),
    this.cancelWindow = const Duration(seconds: 5),
    this.locationGrace = const Duration(seconds: 3),
    this.tick = const Duration(milliseconds: 50),
  });

  final Duration hold;
  final Duration cancelWindow;

  /// After the cancel window ends, wait at most this long for a position before sending without one.
  final Duration locationGrace;
  final Duration tick;
}

sealed class SosFlowState {
  const SosFlowState();
}

class SosIdle extends SosFlowState {
  const SosIdle();
}

/// Button is being held. [progress] runs 0..1 over the hold time.
class SosHolding extends SosFlowState {
  const SosHolding(this.progress);
  final double progress;
}

/// Cancel window. Nothing has been sent yet; cancelling creates no alert.
class SosCountdown extends SosFlowState {
  const SosCountdown(this.secondsLeft);
  final int secondsLeft;
}

class SosSending extends SosFlowState {
  const SosSending();
}

class SosSent extends SosFlowState {
  const SosSent(this.alert, {required this.withLocation});
  final SosAlert alert;
  final bool withLocation;
}

class SosFailed extends SosFlowState {
  const SosFailed(this.message);
  final String message;
}

/// Pure state machine for the SOS trigger: hold 2 s -> 5 s cancel window -> send (D-059, D-060).
/// No Flutter and no Riverpod, so it is unit tested with fake time.
///
/// A short press does nothing. The position is requested when the window starts, in parallel, and is
/// DISCARDED if the student cancels (PRD: location is collected only after an SOS).
class SosFlow {
  SosFlow({
    required this.fetchLocation,
    required this.send,
    required this.onState,
    required this.errorMessage,
    this.timings = const SosTimings(),
  });

  /// Returns the first fix or null (denied, services off, timeout). Never throws.
  final Future<GeoFix?> Function() fetchLocation;

  /// Creates the alert. Returns the new alert, or the student's existing open alert (D-060).
  final Future<SosAlert> Function(GeoFix? fix) send;
  final void Function(SosFlowState state) onState;

  /// Turns a send error into text that is safe to show.
  final String Function(Object error) errorMessage;
  final SosTimings timings;

  SosFlowState _state = const SosIdle();
  Timer? _timer;
  Future<GeoFix?>? _fix;
  int _generation = 0;

  SosFlowState get state => _state;

  void _emit(SosFlowState s) {
    _state = s;
    onState(s);
  }

  void pressStart() {
    if (_state is! SosIdle && _state is! SosFailed) return;
    _emit(const SosHolding(0));
    _timer?.cancel();
    var elapsed = Duration.zero;
    _timer = Timer.periodic(timings.tick, (t) {
      elapsed += timings.tick;
      if (elapsed >= timings.hold) {
        t.cancel();
        _startCountdown();
      } else {
        _emit(SosHolding(elapsed.inMicroseconds / timings.hold.inMicroseconds));
      }
    });
  }

  /// Finger lifted. Before the hold completes this aborts; afterwards it has no effect.
  void pressEnd() {
    if (_state is SosHolding) {
      _timer?.cancel();
      _emit(const SosIdle());
    }
  }

  void _startCountdown() {
    final generation = ++_generation;
    // `.then<GeoFix?>` makes the runtime type nullable, so `timeout(onTimeout: null)` is always valid.
    _fix = fetchLocation().then<GeoFix?>((v) => v, onError: (_) => null);
    var left = timings.cancelWindow.inSeconds;
    _emit(SosCountdown(left));
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      left--;
      if (left > 0) {
        _emit(SosCountdown(left));
      } else {
        t.cancel();
        unawaited(_sendNow(generation));
      }
    });
  }

  /// Abort during the cancel window: no alert is created and the position is dropped.
  void cancel() {
    if (_state is! SosCountdown) return;
    _timer?.cancel();
    _generation++;
    _fix = null;
    _emit(const SosIdle());
  }

  Future<void> _sendNow(int generation) async {
    _emit(const SosSending());
    GeoFix? fix;
    try {
      fix = await (_fix ?? Future<GeoFix?>.value()).timeout(timings.locationGrace, onTimeout: () => null);
    } on Object {
      fix = null;
    }
    if (generation != _generation) return;
    try {
      final alert = await send(fix);
      if (generation != _generation) return;
      _emit(SosSent(alert, withLocation: fix != null));
    } on Object catch (e) {
      if (generation != _generation) return;
      _emit(SosFailed(errorMessage(e)));
    }
  }

  /// Back to idle after a result was shown.
  void reset() {
    _timer?.cancel();
    _generation++;
    _fix = null;
    _emit(const SosIdle());
  }

  void dispose() {
    _timer?.cancel();
    _generation++;
  }
}
