/// One position sample taken during an open alert. `recordedAt` is the device time.
class LocationPoint {
  const LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.accuracy,
    this.id,
  });

  /// Queue row id; null until the point is stored.
  final int? id;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime recordedAt;
}
