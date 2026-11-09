/// Longest message the DB accepts (D-072, CHECK `messages_body_length`).
const chatMaxLength = 1000;

/// Delivery state of a message. Only the phone's own unsent messages are `sending` or `failed`;
/// anything that came from the server is `sent` (D-072: offline = failed, tap to retry).
enum SendState { sent, sending, failed }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.sentAt,
    this.readAt,
    this.state = SendState.sent,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    senderId: json['sender_id'] as String,
    body: json['body'] as String,
    sentAt: DateTime.parse(json['sent_at'] as String),
    readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
  );

  final String id;
  final String senderId;
  final String body;
  final DateTime sentAt;
  final DateTime? readAt;
  final SendState state;

  ChatMessage withState(SendState s) =>
      ChatMessage(id: id, senderId: senderId, body: body, sentAt: sentAt, readAt: readAt, state: s);

  /// Unread for [userId]: someone else wrote it and it has not been marked read.
  bool isUnreadFor(String userId) => senderId != userId && readAt == null;
}

/// Merge by id (later wins) and order by time: dedupes the Realtime snapshot, our own sent
/// message and any re-delivery.
List<ChatMessage> mergeMessages(List<ChatMessage> current, List<ChatMessage> incoming) {
  final byId = {for (final m in current) m.id: m};
  for (final m in incoming) {
    byId[m.id] = m;
  }
  return byId.values.toList()..sort((a, b) => a.sentAt.compareTo(b.sentAt));
}
