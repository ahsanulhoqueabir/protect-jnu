import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../auth/auth_providers.dart';
import 'data/alert_repository.dart';
import 'data/location_service.dart';
import 'domain/sos_alert.dart';
import 'domain/sos_flow.dart';

/// The student's open alert (active or acknowledged), kept fresh through Realtime while one exists.
/// `null` data = no open alert. Resets when the user changes.
final openAlertProvider = AsyncNotifierProvider<OpenAlertNotifier, SosAlert?>(
  OpenAlertNotifier.new,
);

class OpenAlertNotifier extends AsyncNotifier<SosAlert?> {
  StreamSubscription<SosAlert>? _sub;

  @override
  Future<SosAlert?> build() async {
    ref.onDispose(() => _sub?.cancel());
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return null;
    final alert = await ref.watch(alertRepositoryProvider).currentOpen(userId);
    if (alert != null) _watch(alert.id);
    return alert;
  }

  void _watch(String id) {
    _sub?.cancel();
    _sub = ref
        .read(alertRepositoryProvider)
        .watch(id)
        .listen(
          (alert) {
            // A closed alert leaves the "open" slot; the screen shows the final status first.
            state = AsyncData(alert);
          },
          onError: (_) {
            // Realtime dropped. The last known status stays on screen; `refresh` re-reads it.
          },
        );
  }

  /// Called after a new alert was created.
  void adopt(SosAlert alert) {
    state = AsyncData(alert);
    _watch(alert.id);
  }

  /// Re-read from the server (pull to refresh, Realtime fallback).
  Future<void> refresh() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final alert = await ref.read(alertRepositoryProvider).currentOpen(userId);
    if (alert != null) {
      adopt(alert);
    } else if (state.value?.status.isOpen ?? false) {
      // It was closed while we were not listening; re-read that very alert is not needed:
      // clear it so the SOS button comes back.
      state = const AsyncData(null);
    }
  }

  Future<void> cancelActive() async {
    final alert = state.value;
    if (alert == null || alert.status != AlertStatus.active) return;
    await ref.read(alertRepositoryProvider).cancel(alert.id);
    state = AsyncData(
      SosAlert(id: alert.id, status: AlertStatus.cancelled, startedAt: alert.startedAt),
    );
  }

  /// Leave the closed alert's screen: forget it so the home screen offers SOS again.
  void dismissClosed() {
    final alert = state.value;
    if (alert != null && !alert.status.isOpen) {
      _sub?.cancel();
      state = const AsyncData(null);
    }
  }
}

/// Drives the hold -> countdown -> send state machine (see [SosFlow]).
final sosFlowProvider = NotifierProvider<SosFlowNotifier, SosFlowState>(SosFlowNotifier.new);

class SosFlowNotifier extends Notifier<SosFlowState> {
  late final SosFlow _flow;

  @override
  SosFlowState build() {
    _flow = SosFlow(
      fetchLocation: () => ref.read(locationServiceProvider).firstFix(),
      send: _send,
      onState: (s) => state = s,
      errorMessage: (e) =>
          e is ApiException ? e.message : 'Could not send the alert. Please try again.',
    );
    ref.onDispose(_flow.dispose);
    return const SosIdle();
  }

  Future<SosAlert> _send(GeoFix? fix) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) throw const UnauthorizedException();
    final alert = await ref.read(alertRepositoryProvider).create(userId: userId, fix: fix);
    ref.read(openAlertProvider.notifier).adopt(alert);
    return alert;
  }

  void pressStart() => _flow.pressStart();
  void pressEnd() => _flow.pressEnd();
  void cancel() => _flow.cancel();
  void reset() => _flow.reset();
}
