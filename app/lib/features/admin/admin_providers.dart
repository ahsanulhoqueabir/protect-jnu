import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/realtime/realtime_changes.dart';
import '../auth/auth_providers.dart';
import 'data/admin_repository.dart';
import 'domain/admin_alert.dart';
import 'domain/admin_chat.dart';
import 'domain/admin_user.dart';
import 'domain/support_report.dart';

/// True when the signed-in account has `role = 'admin'` (D-078). Only decides what the app SHOWS;
/// the server re-checks the role on every admin request.
final isAdminProvider = Provider<bool>(
  (ref) => ref.watch(authProvider.select((auth) => auth.value?.role == 'admin')),
);

/// Keeps a notifier fresh: refetches on every Realtime change/reconnect it is told about and on
/// a safety-net timer. Cancels both when the provider is disposed.
mixin _LiveRefresh {
  void keepFresh(
    Ref ref, {
    required String table,
    String? alertId,
    required void Function(TableChange change) onChange,
    required Future<void> Function() poll,
  }) {
    final sub = ref
        .read(realtimeChangesProvider)
        .changes(table, alertId: alertId)
        .listen(onChange, onError: (_) {});
    final every = ref.read(livePollIntervalProvider);
    final timer = every == null ? null : Timer.periodic(every, (_) => poll());
    ref.onDispose(() {
      sub.cancel();
      timer?.cancel();
    });
  }
}

/// Open alerts (active + acknowledged), live (dashboard "Live alerts"). App-wide while an admin is
/// signed in; empty for everyone else.
final liveAlertsProvider = AsyncNotifierProvider<LiveAlertsNotifier, List<AdminAlert>>(
  LiveAlertsNotifier.new,
);

class LiveAlertsNotifier extends AsyncNotifier<List<AdminAlert>> with _LiveRefresh {
  @override
  Future<List<AdminAlert>> build() async {
    ref.watch(currentUserIdProvider);
    if (!ref.watch(isAdminProvider)) return const [];
    keepFresh(ref, table: 'alerts', onChange: (_) => reload(), poll: reload);
    return _fetch();
  }

  Future<List<AdminAlert>> _fetch() async =>
      (await ref.read(adminRepositoryProvider).alerts()).items;

  /// Refetch without dropping the list on screen when it fails (offline, slow socket).
  Future<void> reload() async {
    final next = await AsyncValue.guard(_fetch);
    if (next.hasValue || !state.hasValue) state = next;
  }
}

/// Alert history page (status filter + page, 20 per page).
final alertHistoryProvider = FutureProvider.autoDispose
    .family<AdminPage<AdminAlert>, ({String status, int page})>(
      (ref, query) =>
          ref.watch(adminRepositoryProvider).alerts(status: query.status, page: query.page),
    );

/// Users list page.
final adminUsersProvider = FutureProvider.autoDispose.family<AdminPage<AdminUser>, int>(
  (ref, page) => ref.watch(adminRepositoryProvider).users(page: page),
);

/// Monthly report for a year.
final supportReportProvider = FutureProvider.autoDispose.family<SupportReport, int>(
  (ref, year) => ref.watch(adminRepositoryProvider).report(year),
);

/// Conversations with unread counts, live.
final conversationsProvider =
    AsyncNotifierProvider.autoDispose<ConversationsNotifier, List<Conversation>>(
      ConversationsNotifier.new,
    );

class ConversationsNotifier extends AsyncNotifier<List<Conversation>> with _LiveRefresh {
  @override
  Future<List<Conversation>> build() async {
    ref.watch(currentUserIdProvider);
    keepFresh(ref, table: 'messages', onChange: (_) => reload(), poll: reload);
    return ref.read(adminRepositoryProvider).conversations();
  }

  Future<void> reload() async {
    final next = await AsyncValue.guard(() => ref.read(adminRepositoryProvider).conversations());
    if (next.hasValue || !state.hasValue) state = next;
  }
}

/// One alert's details (student, contacts, timeline), refreshed when the alert row changes.
final alertDetailProvider = AsyncNotifierProvider.autoDispose
    .family<AlertDetailNotifier, AdminAlertDetail, String>(AlertDetailNotifier.new);

class AlertDetailNotifier extends AsyncNotifier<AdminAlertDetail> with _LiveRefresh {
  AlertDetailNotifier(this.alertId);

  final String alertId;

  @override
  Future<AdminAlertDetail> build() async {
    ref.watch(currentUserIdProvider);
    keepFresh(
      ref,
      table: 'alerts',
      onChange: (change) {
        if (change.isConnected || change.record['id'] == alertId) reload();
      },
      poll: reload,
    );
    return ref.read(adminRepositoryProvider).alert(alertId);
  }

  Future<void> reload() async {
    final next = await AsyncValue.guard(() => ref.read(adminRepositoryProvider).alert(alertId));
    if (next.hasValue || !state.hasValue) state = next;
  }

  /// Acknowledge / resolve. On a race lost to another admin (409 `invalid_transition`) the
  /// current state is reloaded and the error rethrown so the screen can say so.
  Future<void> transition(AlertAction action) async {
    try {
      await ref.read(adminRepositoryProvider).transition(alertId, action);
    } finally {
      await reload();
      ref.read(liveAlertsProvider.notifier).reload().ignore();
    }
  }
}

/// The live-map trail (newest 20 points), from the API and then Realtime `locations` inserts.
final alertTrailProvider = AsyncNotifierProvider.autoDispose
    .family<AlertTrailNotifier, List<TrailPoint>, String>(AlertTrailNotifier.new);

class AlertTrailNotifier extends AsyncNotifier<List<TrailPoint>> with _LiveRefresh {
  AlertTrailNotifier(this.alertId);

  final String alertId;

  @override
  Future<List<TrailPoint>> build() async {
    ref.watch(currentUserIdProvider);
    keepFresh(
      ref,
      table: 'locations',
      alertId: alertId,
      onChange: (change) {
        if (change.isInsert) {
          try {
            final point = TrailPoint.fromJson(change.record);
            state = AsyncData(mergeTrail(state.value ?? const [], [point]));
          } on Object {
            reload();
          }
        } else if (change.isConnected) {
          reload();
        }
      },
      poll: reload,
    );
    return mergeTrail(const [], await ref.read(adminRepositoryProvider).locations(alertId));
  }

  Future<void> reload() async {
    final next = await AsyncValue.guard(() => ref.read(adminRepositoryProvider).locations(alertId));
    if (next.hasValue) {
      state = AsyncData(mergeTrail(state.value ?? const [], next.requireValue));
    } else if (!state.hasValue) {
      state = AsyncError(next.error!, next.stackTrace!);
    }
  }
}

class AdminChatState {
  const AdminChatState({this.messages = const [], this.loaded = false, this.loadFailed = false});

  final List<AdminMessage> messages;
  final bool loaded;
  final bool loadFailed;

  int get unreadFromStudent => messages.where((m) => m.fromStudent && m.readAt == null).length;

  AdminChatState copyWith({List<AdminMessage>? messages, bool? loaded, bool? loadFailed}) =>
      AdminChatState(
        messages: messages ?? this.messages,
        loaded: loaded ?? this.loaded,
        loadFailed: loadFailed ?? this.loadFailed,
      );
}

/// The admin side of one alert's chat (dashboard chat panel). Live while a screen watches it.
final adminChatProvider = NotifierProvider.autoDispose
    .family<AdminChatController, AdminChatState, String>(AdminChatController.new);

class AdminChatController extends Notifier<AdminChatState> with _LiveRefresh {
  AdminChatController(this.alertId);

  final String alertId;

  @override
  AdminChatState build() {
    ref.watch(currentUserIdProvider);
    keepFresh(
      ref,
      table: 'messages',
      alertId: alertId,
      onChange: (change) => load(onlyNew: !change.isConnected),
      poll: load,
    );
    Future.microtask(load);
    return const AdminChatState();
  }

  /// Full history, or only messages newer than the last one we have (reconnect / new event).
  Future<void> load({bool onlyNew = false}) async {
    final since = onlyNew && state.messages.isNotEmpty ? state.messages.last.sentAt : null;
    try {
      final rows = await ref.read(adminRepositoryProvider).messages(alertId, since: since);
      if (!ref.mounted) return;
      state = state.copyWith(
        messages: mergeAdminMessages(state.messages, rows),
        loaded: true,
        loadFailed: false,
      );
    } on ApiException {
      if (!ref.mounted) return;
      state = state.copyWith(loaded: true, loadFailed: !state.loaded || state.loadFailed);
    }
  }

  /// Throws [ApiException] (e.g. `chat_closed`) so the screen can show it.
  Future<void> send(String text) async {
    final body = text.trim();
    if (body.isEmpty || body.length > 1000) return;
    await ref.read(adminRepositoryProvider).sendMessage(alertId, body);
    await load(onlyNew: true);
  }

  /// The admin is looking at the thread: mark the student's messages read (any admin, D-021).
  Future<void> markRead() async {
    if (state.unreadFromStudent == 0) return;
    try {
      await ref.read(adminRepositoryProvider).markRead(alertId);
      await load();
    } on Object {
      // Not critical; retried on the next message.
    }
  }
}
