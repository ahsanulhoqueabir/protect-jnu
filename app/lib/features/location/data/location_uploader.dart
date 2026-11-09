import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/location_point.dart';

enum UploadOutcome {
  /// Rows stored.
  sent,

  /// No connection or server trouble: keep the points and retry later.
  retry,

  /// The server refuses them for good (alert no longer open, RLS): drop them and stop.
  rejected,
}

abstract interface class LocationUploader {
  /// Inserts [points] (oldest first) for the alert, in one request.
  Future<UploadOutcome> upload({
    required String alertId,
    required String userId,
    required List<LocationPoint> points,
  });
}

/// Direct insert under RLS (D-061): only the owner, only while the alert is open.
class SupabaseLocationUploader implements LocationUploader {
  SupabaseLocationUploader(this._client);

  final SupabaseClient Function() _client;

  @override
  Future<UploadOutcome> upload({
    required String alertId,
    required String userId,
    required List<LocationPoint> points,
  }) async {
    try {
      // Needs unique (alert_id, recorded_at) from migration 0015; duplicates are skipped.
      await _client().from('locations').upsert(
        onConflict: 'alert_id,recorded_at',
        ignoreDuplicates: true,
        [
          for (final p in points)
            {
              'alert_id': alertId,
              'user_id': userId,
              'latitude': p.latitude,
              'longitude': p.longitude,
              if (p.accuracy != null) 'accuracy': p.accuracy,
              'recorded_at': p.recordedAt.toUtc().toIso8601String(),
            },
        ],
      );
      return UploadOutcome.sent;
    } on PostgrestException catch (e) {
      // 42501 = RLS refused (alert closed); 23503 = alert gone. Anything else may be temporary.
      if (e.code == '42501' || e.code == '23503') return UploadOutcome.rejected;
      return UploadOutcome.retry;
    } on Object {
      return UploadOutcome.retry;
    }
  }
}
