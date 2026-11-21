import 'package:flutter/foundation.dart';

import '../../sos/domain/sos_alert.dart';

DateTime? _time(Object? v) => v == null ? null : DateTime.parse(v as String);

/// The student shown on an alert card (api-contract 6: name + student ID only).
@immutable
class AlertStudent {
  const AlertStudent({required this.fullName, required this.studentId, this.phone, this.email});

  factory AlertStudent.fromJson(Map<String, dynamic>? json) => AlertStudent(
    fullName: json?['full_name'] as String? ?? 'Unknown student',
    studentId: json?['student_id'] as String? ?? '',
    phone: json?['phone'] as String?,
    email: json?['email'] as String?,
  );

  final String fullName;
  final String studentId;
  final String? phone;
  final String? email;
}

/// One row of `GET /api/admin/alerts` (live list and history).
@immutable
class AdminAlert {
  const AdminAlert({
    required this.id,
    required this.status,
    required this.startedAt,
    required this.student,
    this.acknowledgedAt,
    this.resolvedAt,
    this.cancelledAt,
  });

  factory AdminAlert.fromJson(Map<String, dynamic> json) => AdminAlert(
    id: json['id'] as String,
    status: AlertStatus.parse(json['status'] as String),
    startedAt: DateTime.parse(json['started_at'] as String),
    acknowledgedAt: _time(json['acknowledged_at']),
    resolvedAt: _time(json['resolved_at']),
    cancelledAt: _time(json['cancelled_at']),
    student: AlertStudent.fromJson(json['student'] as Map<String, dynamic>?),
  );

  final String id;
  final AlertStatus status;
  final DateTime startedAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final DateTime? cancelledAt;
  final AlertStudent student;
}

/// An emergency contact shown to admins during an alert (PRD 5.1).
@immutable
class AdminContact {
  const AdminContact({required this.id, required this.name, required this.phone});

  factory AdminContact.fromJson(Map<String, dynamic> json) => AdminContact(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
  );

  final String id;
  final String name;
  final String phone;
}

/// `GET /api/admin/alerts/:id`.
@immutable
class AdminAlertDetail {
  const AdminAlertDetail({
    required this.id,
    required this.status,
    required this.startedAt,
    required this.student,
    required this.contacts,
    this.acknowledgedAt,
    this.resolvedAt,
    this.cancelledAt,
    this.firstLatitude,
    this.firstLongitude,
    this.acknowledgedByEmail,
    this.resolvedByEmail,
  });

  factory AdminAlertDetail.fromJson(Map<String, dynamic> json) => AdminAlertDetail(
    id: json['id'] as String,
    status: AlertStatus.parse(json['status'] as String),
    startedAt: DateTime.parse(json['started_at'] as String),
    acknowledgedAt: _time(json['acknowledged_at']),
    resolvedAt: _time(json['resolved_at']),
    cancelledAt: _time(json['cancelled_at']),
    firstLatitude: (json['first_latitude'] as num?)?.toDouble(),
    firstLongitude: (json['first_longitude'] as num?)?.toDouble(),
    student: AlertStudent.fromJson(json['student'] as Map<String, dynamic>?),
    contacts: [
      for (final c in (json['contacts'] as List<dynamic>? ?? const []))
        AdminContact.fromJson(c as Map<String, dynamic>),
    ],
    acknowledgedByEmail: json['acknowledged_by_email'] as String?,
    resolvedByEmail: json['resolved_by_email'] as String?,
  );

  final String id;
  final AlertStatus status;
  final DateTime startedAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final DateTime? cancelledAt;
  final double? firstLatitude;
  final double? firstLongitude;
  final AlertStudent student;
  final List<AdminContact> contacts;
  final String? acknowledgedByEmail;
  final String? resolvedByEmail;

  /// The action an admin may take now (PRD 5.2: active -> acknowledged -> resolved).
  AlertAction? get nextAction => switch (status) {
    AlertStatus.active => AlertAction.acknowledge,
    AlertStatus.acknowledged => AlertAction.resolve,
    _ => null,
  };

  /// A thread accepts messages only while the alert is open (D-072).
  bool get chatOpen => status.isOpen;
}

enum AlertAction {
  acknowledge('Acknowledge'),
  resolve('Mark resolved');

  const AlertAction(this.label);
  final String label;
}

/// One point of the live-map trail (`GET /api/admin/alerts/:id/locations`).
@immutable
class TrailPoint {
  const TrailPoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.accuracy,
  });

  factory TrailPoint.fromJson(Map<String, dynamic> json) => TrailPoint(
    id: json['id'].toString(),
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    accuracy: (json['accuracy'] as num?)?.toDouble(),
    recordedAt: DateTime.parse(json['recorded_at'] as String),
  );

  final String id;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime recordedAt;
}

/// Newest [max] points, oldest first, deduplicated by id (same rule as the dashboard's
/// `mergePoints`: out-of-order and repeated Realtime events are harmless).
List<TrailPoint> mergeTrail(
  List<TrailPoint> current,
  Iterable<TrailPoint> incoming, {
  int max = 20,
}) {
  final byId = {for (final p in current) p.id: p};
  for (final p in incoming) {
    byId[p.id] = p;
  }
  final sorted = byId.values.toList()..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  return sorted.length <= max ? sorted : sorted.sublist(sorted.length - max);
}

/// A page of a paginated admin list (20 per page, D-024).
@immutable
class AdminPage<T> {
  const AdminPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;

  int get pageCount => total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;
  bool get hasPrevious => page > 1;
  bool get hasNext => page < pageCount;
}
