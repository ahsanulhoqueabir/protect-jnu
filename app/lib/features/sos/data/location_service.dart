import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/sos_alert.dart';

/// One-shot position for the SOS (D-059). Never throws: any problem means "no location".
abstract interface class LocationService {
  Future<GeoFix?> firstFix();
}

/// Uses `geolocator` (D-023, verified on pub.dev). Permission is requested here, i.e. only at SOS time
/// (PRD: collect location only after an SOS).
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<GeoFix?> firstFix() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return null;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return GeoFix(latitude: p.latitude, longitude: p.longitude, accuracy: p.accuracy);
    } on Object {
      return null;
    }
  }
}

final locationServiceProvider = Provider<LocationService>((_) => const GeolocatorLocationService());
