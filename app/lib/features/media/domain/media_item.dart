enum MediaType { photo, video }

/// One captured file kept on the phone only (PRD 5.5, D-013). [alertId] is set when the file was
/// captured while an alert was open (D-074); it never leaves the device.
class MediaItem {
  const MediaItem({
    required this.id,
    required this.path,
    required this.type,
    required this.capturedAt,
    this.alertId,
  });

  /// File name inside the media folder; unique.
  final String id;
  final String path;
  final MediaType type;
  final DateTime capturedAt;
  final String? alertId;

  /// The index stores only [id]; [path] is rebuilt from the current folder on load.
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'captured_at': capturedAt.toUtc().toIso8601String(),
    'alert_id': alertId,
  };

  static MediaItem? fromJson(Map<String, Object?> json, String folder) {
    final id = json['id'];
    final type = json['type'];
    final at = json['captured_at'];
    if (id is! String || type is! String || at is! String) return null;
    final parsedType = MediaType.values.where((t) => t.name == type).firstOrNull;
    final parsedAt = DateTime.tryParse(at);
    if (parsedType == null || parsedAt == null) return null;
    return MediaItem(
      id: id,
      path: '$folder/$id',
      type: parsedType,
      capturedAt: parsedAt,
      alertId: json['alert_id'] as String?,
    );
  }
}

/// Video length limit (D-074).
const maxVideoDuration = Duration(seconds: 60);
