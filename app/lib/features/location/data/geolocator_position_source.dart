import 'package:geolocator/geolocator.dart';

import '../domain/location_point.dart';
import '../domain/location_sharing.dart';

/// Android foreground location service through geolocator's built-in support (D-066, D-069).
/// Listening starts the service and shows the notification; cancelling the subscription stops both.
class GeolocatorPositionSource implements PositionSource {
  const GeolocatorPositionSource();

  static const interval = Duration(seconds: 10);

  @override
  Stream<LocationPoint> start() {
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: interval,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: "Protect JnU'ins",
        notificationText: 'Sharing your location with campus security',
        notificationChannelName: 'Live location',
        setOngoing: true,
        enableWakeLock: true,
      ),
    );
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (p) => LocationPoint(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracy: p.accuracy,
        recordedAt: p.timestamp.toUtc(),
      ),
    );
  }
}
