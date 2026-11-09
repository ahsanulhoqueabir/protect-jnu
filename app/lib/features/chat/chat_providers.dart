import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../auth/auth_providers.dart';
import 'data/chat_repository.dart';
import 'domain/chat_message.dart';

class ChatState {
  const ChatState({
    this.server = const [],
    this.pending = const [],
    this.loaded = false,
    this.connectionLost = false,
    this.failureText = const {},
  });

  /// Messages the server has (Realtime snapshot, merged with our own confirmed sends).
  final List<ChatMessage> server;

  /// Our own messages that are sending or failed (D-072).
  final List<ChatMessage> pending;
  final bool loaded;
  final bool connectionLost;

  /// Why a pending message failed, by id.
  final Map<String, String> failureText;

  List<ChatMessage> get messages => [...server, ...pending];

  ChatState copyWith({
    List<ChatMessage>? server,
    List<ChatMessage>? pending,
    bool? loaded,
    bool? connectionLost,
    Map<String, String>? failureText,
  }) => ChatState(
    server: server ?? this.server,
    pending: pending ?? this.pending,
    loaded: loaded ?? this.loaded,
    connectionLost: connectionLost ?? this.connectionLost,
    failureText: failureText ?? this.failureText,
  );

  int unreadFor(String userId) => server.where((m) => m.isUnreadFor(userId)).length;
}

/// The chat of one alert (keyed by alert id). Lives while a screen watches it.
final chatProvider = NotifierProvider.autoDispose.family<ChatController, ChatState, String>(
  ChatController.new,
);

class ChatController extends Notifier<ChatState> {
  ChatController(this.alertId);

  final String alertId;
  StreamSubscription<List<ChatMessage>>? _sub;
  var _localCounter = 0;

  @override
  ChatState build() {
    ref.onDispose(() => _sub?.cancel());
    ref.watch(currentUserIdProvider);
    _sub = ref
        .read(chatRepositoryProvider)
        .watch(alertId)
        .listen(
          (rows) => state = state.copyWith(
            server: mergeMessages(state.server, rows),
            loaded: true,
            connectionLost: false,
          ),
          onError: (_) => state = state.copyWith(loaded: true, connectionLost: true),
        );
    return const ChatState();
  }

  String? get _me => ref.read(currentUserIdProvider);

  Future<void> send(String text) async {
    final me = _me;
    final body = text.trim();
    if (me == null || body.isEmpty || body.length > chatMaxLength) return;
    final local = ChatMessage(
      id: 'local-${_localCounter++}',
      senderId: me,
      body: body,
      sentAt: DateTime.now().toUtc(),
      state: SendState.sending,
    );
    state = state.copyWith(pending: [...state.pending, local]);
    await _deliver(local, me);
  }

  /// Tap to retry a failed message (D-072).
  Future<void> retry(String localId) async {
    final me = _me;
    final matches = state.pending.where((m) => m.id == localId);
    if (me == null || matches.isEmpty) return;
    await _deliver(matches.first, me);
  }

  void discard(String localId) {
    state = state.copyWith(pending: state.pending.where((m) => m.id != localId).toList());
  }

  Future<void> _deliver(ChatMessage local, String me) async {
    _setPending(local.id, SendState.sending);
    try {
      final sent = await ref
          .read(chatRepositoryProvider)
          .send(alertId: alertId, senderId: me, body: local.body);
      state = state.copyWith(
        pending: state.pending.where((m) => m.id != local.id).toList(),
        server: mergeMessages(state.server, [sent]),
      );
    } on ApiException catch (e) {
      _fail(local.id, e.message);
    } on Object {
      _fail(local.id, 'Could not send the message. Please try again.');
    }
  }

  void _setPending(String id, SendState s) {
    state = state.copyWith(
      pending: [for (final m in state.pending) m.id == id ? m.withState(s) : m],
    );
  }

  void _fail(String id, String text) {
    state = state.copyWith(
      pending: [for (final m in state.pending) m.id == id ? m.withState(SendState.failed) : m],
      failureText: {...state.failureText, id: text},
    );
  }

  /// The student is looking at the thread: mark the administrators' messages read.
  Future<void> markRead() async {
    final me = _me;
    if (me == null || state.unreadFor(me) == 0) return;
    try {
      await ref.read(chatRepositoryProvider).markRead(alertId: alertId, userId: me);
    } on Object {
      // Not critical; it is retried when the next message arrives.
    }
  }
}
