import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_exception.dart';
import '../domain/chat_message.dart';

/// Chat straight through Supabase; Row Level Security limits every call to the student's own
/// alert thread and refuses inserts once the alert is closed (D-028, D-072, migration 0016).
abstract interface class ChatRepository {
  /// The thread (newest 200, oldest first), live through Realtime.
  Stream<List<ChatMessage>> watch(String alertId);

  Future<ChatMessage> send({
    required String alertId,
    required String senderId,
    required String body,
  });

  /// Marks the other party's unread messages on this thread as read.
  Future<void> markRead({required String alertId, required String userId});
}

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client);

  final SupabaseClient _client;

  static const _columns = 'id, sender_id, body, sent_at, read_at';

  @override
  Stream<List<ChatMessage>> watch(String alertId) => _client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('alert_id', alertId)
      .order('sent_at', ascending: false)
      .limit(200)
      .map((rows) => rows.map(ChatMessage.fromJson).toList().reversed.toList());

  @override
  Future<ChatMessage> send({
    required String alertId,
    required String senderId,
    required String body,
  }) => _guard(() async {
    final row = await _client
        .from('messages')
        .insert({'alert_id': alertId, 'sender_id': senderId, 'body': body})
        .select(_columns)
        .single();
    return ChatMessage.fromJson(row);
  });

  @override
  Future<void> markRead({required String alertId, required String userId}) => _guard(() async {
    await _client
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('alert_id', alertId)
        .isFilter('read_at', null)
        .neq('sender_id', userId);
  });

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST301' || e.code == '401') throw const UnauthorizedException();
      // 42501 = RLS refusal: the alert is resolved or cancelled, the thread is read-only (D-072).
      if (e.code == '42501') {
        throw const UnknownApiException('This conversation is closed.');
      }
      throw const UnknownApiException('Could not send the message. Please try again.');
    } on AuthException {
      throw const UnauthorizedException();
    } on Exception {
      throw const NetworkException();
    }
  }
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => SupabaseChatRepository(Supabase.instance.client),
);
