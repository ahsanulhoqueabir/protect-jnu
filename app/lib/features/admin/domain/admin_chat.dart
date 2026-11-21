import 'package:flutter/foundation.dart';

import '../../sos/domain/sos_alert.dart';
import 'admin_alert.dart';

/// One row of `GET /api/admin/conversations`: last message + unread count per alert.
@immutable
class Conversation {
  const Conversation({
    required this.alertId,
    required this.lastBody,
    required this.lastSentAt,
    required this.lastSenderId,
    required this.unreadCount,
    required this.student,
    this.status,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    alertId: json['alert_id'] as String,
    lastBody: json['last_body'] as String? ?? '',
    lastSentAt: DateTime.parse(json['last_sent_at'] as String),
    lastSenderId: json['last_sender_id'] as String? ?? '',
    unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    student: AlertStudent.fromJson(json['student'] as Map<String, dynamic>?),
    status: json['status'] == null ? null : AlertStatus.parse(json['status'] as String),
  );

  final String alertId;
  final String lastBody;
  final DateTime lastSentAt;
  final String lastSenderId;
  final int unreadCount;
  final AlertStudent student;
  final AlertStatus? status;
}

/// A message as the admin API returns it (`GET /api/admin/alerts/:id/messages`).
@immutable
class AdminMessage {
  const AdminMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.sentAt,
    required this.fromStudent,
    this.readAt,
    this.senderName,
  });

  factory AdminMessage.fromJson(Map<String, dynamic> json) => AdminMessage(
    id: json['id'] as String,
    senderId: json['sender_id'] as String,
    body: json['body'] as String,
    sentAt: DateTime.parse(json['sent_at'] as String),
    readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
    senderName: json['sender_name'] as String?,
    fromStudent: json['from_student'] as bool? ?? false,
  );

  final String id;
  final String senderId;
  final String body;
  final DateTime sentAt;
  final DateTime? readAt;
  final String? senderName;
  final bool fromStudent;
}

/// Merge by id (later wins), oldest first: dedupes refetches, Realtime-triggered reloads and our
/// own sends (same rule as the dashboard chat panel).
List<AdminMessage> mergeAdminMessages(List<AdminMessage> current, Iterable<AdminMessage> incoming) {
  final byId = {for (final m in current) m.id: m};
  for (final m in incoming) {
    byId[m.id] = m;
  }
  return byId.values.toList()..sort((a, b) => a.sentAt.compareTo(b.sentAt));
}
