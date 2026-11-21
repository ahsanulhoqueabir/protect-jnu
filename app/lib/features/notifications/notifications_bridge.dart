import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/app_router.dart';
import '../../app/router/routes.dart';
import '../../core/notifications/app_notifier.dart';
import '../../core/realtime/realtime_changes.dart';
import '../admin/admin_providers.dart';
import '../admin/data/admin_repository.dart';
import '../auth/auth_providers.dart';
import '../sos/domain/sos_alert.dart';
import '../sos/sos_providers.dart';
import 'visible_chat_provider.dart';

/// Turns live events into system notifications with sound and vibration (D-081). Watched by `App`
/// so it runs whenever someone is signed in:
/// - admins: every new SOS alert, and new messages on any thread;
/// - everyone (admins can send an SOS too): their own alert being acknowledged or resolved, and
///   new admin-team messages on their own alert while the chat is not on screen.
/// Works while the app process runs (foreground or recently in the background). A closed app
/// receives nothing until remote push (FCM) exists, B-022.
final notificationsBridgeProvider = Provider<void>((ref) {
  final me = ref.watch(currentUserIdProvider);
  if (me == null) return;
  final notifier = ref.watch(appNotifierProvider);
  unawaited(notifier.requestPermission());

  final taps = notifier.taps.listen((route) => ref.read(routerProvider).push(route));
  ref.onDispose(taps.cancel);

  _watchOwnAlert(ref, me, notifier);
  if (ref.watch(isAdminProvider)) _watchAsAdmin(ref, me, notifier);
});

String _preview(Object? body) {
  final text = (body as String? ?? '').trim();
  return text.length <= 80 ? text : '${text.substring(0, 77)}...';
}

int _messageNoticeId(String alertId) => 'msg-$alertId'.hashCode;

void _watchOwnAlert(Ref ref, String me, AppNotifier notifier) {
  StreamSubscription<TableChange>? messages;
  String? watching;
  ref.onDispose(() => messages?.cancel());

  ref.listen<AsyncValue<SosAlert?>>(openAlertProvider, (prev, next) {
    final before = prev?.value;
    final now = next.value;

    // Status changes of the same alert.
    if (before != null && now != null && before.id == now.id && before.status != now.status) {
      final text = switch (now.status) {
        AlertStatus.acknowledged => 'An administrator has seen your alert and is responding.',
        AlertStatus.resolved => 'An administrator marked your alert as resolved.',
        _ => null,
      };
      if (text != null) {
        unawaited(notifier.vibrate(urgent: true));
        unawaited(
          notifier.show(
            AppNotice(
              id: 'status-${now.id}'.hashCode,
              kind: NoticeKind.alertStatus,
              title: now.status == AlertStatus.acknowledged
                  ? 'Alert acknowledged'
                  : 'Alert resolved',
              body: text,
              route: Routes.activeAlert,
            ),
          ),
        );
      }
    }

    // Admin-team messages on the open alert.
    final openId = (now?.status.isOpen ?? false) ? now!.id : null;
    if (openId == watching) return;
    messages?.cancel();
    messages = null;
    watching = openId;
    if (openId == null) return;
    messages = ref.read(realtimeChangesProvider).changes('messages', alertId: openId).listen((c) {
      if (!c.isInsert || c.record['sender_id'] == me) return;
      if (ref.read(visibleChatProvider).isVisible(openId)) return;
      unawaited(notifier.vibrate());
      unawaited(
        notifier.show(
          AppNotice(
            id: _messageNoticeId(openId),
            kind: NoticeKind.message,
            title: 'New message from the admin team',
            body: _preview(c.record['body']),
            route: Routes.alertChat,
          ),
        ),
      );
    }, onError: (_) {});
  }, fireImmediately: true);
}

void _watchAsAdmin(Ref ref, String me, AppNotifier notifier) {
  final realtime = ref.read(realtimeChangesProvider);

  final alerts = realtime.changes('alerts').listen((c) async {
    if (!c.isInsert || c.record['status'] != 'active' || c.record['user_id'] == me) return;
    final id = c.record['id'] as String?;
    if (id == null) return;
    unawaited(notifier.vibrate(urgent: true));
    var who = 'A student';
    try {
      final detail = await ref.read(adminRepositoryProvider).alert(id);
      who = '${detail.student.fullName} (${detail.student.studentId})';
    } on Object {
      // Offline or slow: notify without the name rather than not at all.
    }
    await notifier.show(
      AppNotice(
        id: 'sos-$id'.hashCode,
        kind: NoticeKind.sosAlert,
        title: 'New SOS alert',
        body: '$who needs help. Tap to open the alert.',
        route: Routes.adminAlertFor(id),
      ),
    );
  }, onError: (_) {});

  final messages = realtime.changes('messages').listen((c) {
    if (!c.isInsert || c.record['sender_id'] == me) return;
    final alertId = c.record['alert_id'] as String?;
    if (alertId == null || ref.read(visibleChatProvider).isVisible(alertId)) return;
    unawaited(notifier.vibrate());
    unawaited(
      notifier.show(
        AppNotice(
          id: _messageNoticeId(alertId),
          kind: NoticeKind.message,
          title: 'New message on an alert',
          body: _preview(c.record['body']),
          route: Routes.adminAlertChatFor(alertId),
        ),
      ),
    );
  }, onError: (_) {});

  ref.onDispose(() {
    alerts.cancel();
    messages.cancel();
  });
}
