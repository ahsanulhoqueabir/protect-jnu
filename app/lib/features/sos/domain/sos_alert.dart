/// Alert lifecycle as stored in `alerts.status` (D-022).
enum AlertStatus {
  active,
  acknowledged,
  resolved,
  cancelled;

  static AlertStatus parse(String value) =>
      AlertStatus.values.firstWhere((s) => s.name == value, orElse: () => AlertStatus.active);

  /// An open alert blocks a new one (D-060).
  bool get isOpen => this == active || this == acknowledged;
}

class SosAlert {
  const SosAlert({required this.id, required this.status, required this.startedAt});

  factory SosAlert.fromJson(Map<String, dynamic> json) => SosAlert(
    id: json['id'] as String,
    status: AlertStatus.parse(json['status'] as String),
    startedAt: DateTime.parse(json['started_at'] as String),
  );

  final String id;
  final AlertStatus status;
  final DateTime startedAt;
}

/// First position fix for the alert. Absent when the student denied permission or no fix arrived (D-059).
class GeoFix {
  const GeoFix({required this.latitude, required this.longitude, this.accuracy});

  final double latitude;
  final double longitude;
  final double? accuracy;
}
