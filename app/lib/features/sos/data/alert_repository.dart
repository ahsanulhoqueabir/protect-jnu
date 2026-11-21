import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_exception.dart';
import '../domain/sos_alert.dart';

/// The student's own alerts straight through Supabase; Row Level Security limits every call to
/// the signed-in student (D-061, D-004, D-028).
abstract interface class AlertRepository {
  /// The student's own open (active or acknowledged) alert, if any (D-060). Filtered by [userId]
  /// as well as RLS: RLS lets an admin read every alert, and an admin also uses the student
  /// features (D-078), so RLS alone would hand an admin another student's alert.
  Future<SosAlert?> currentOpen(String userId);

  /// Creates the alert and, when a fix exists, its first location. If the student already has an
  /// open alert (another device, a double send) that alert is returned instead (D-060).
  Future<SosAlert> create({required String userId, GeoFix? fix});

  /// Student ends their own ACTIVE alert (RLS allows only active -> cancelled, D-022).
  Future<void> cancel(String alertId);

  /// Live status of one alert through Realtime.
  Stream<SosAlert> watch(String alertId);
}

class SupabaseAlertRepository implements AlertRepository {
  SupabaseAlertRepository(this._client);

  final SupabaseClient _client;

  static const _columns = 'id, status, started_at';

  @override
  Future<SosAlert?> currentOpen(String userId) => _guard(() async {
    final rows = await _client
        .from('alerts')
        .select(_columns)
        .eq('user_id', userId)
        .inFilter('status', ['active', 'acknowledged'])
        .order('started_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : SosAlert.fromJson(rows.first);
  });

  @override
  Future<SosAlert> create({required String userId, GeoFix? fix}) => _guard(() async {
    final Map<String, dynamic> row;
    try {
      row = await _client
          .from('alerts')
          .insert({
            'user_id': userId,
            if (fix != null) 'first_latitude': fix.latitude,
            if (fix != null) 'first_longitude': fix.longitude,
          })
          .select(_columns)
          .single();
    } on PostgrestException catch (e) {
      // 23505 = alerts_one_open_per_user: an open alert already exists, show that one.
      if (e.code == '23505') {
        final existing = await currentOpen(userId);
        if (existing != null) return existing;
      }
      rethrow;
    }
    final alert = SosAlert.fromJson(row);
    if (fix != null) {
      try {
        await _client.from('locations').insert({
          'alert_id': alert.id,
          'user_id': userId,
          'latitude': fix.latitude,
          'longitude': fix.longitude,
          if (fix.accuracy != null) 'accuracy': fix.accuracy,
        });
      } on PostgrestException {
        // The alert already exists and carries the first coordinates; losing this row must not fail the SOS.
      }
    }
    return alert;
  });

  @override
  Future<void> cancel(String alertId) => _guard(() async {
    await _client.from('alerts').update({'status': 'cancelled'}).eq('id', alertId);
  });

  @override
  Stream<SosAlert> watch(String alertId) => _client
      .from('alerts')
      .stream(primaryKey: ['id'])
      .eq('id', alertId)
      .where((rows) => rows.isNotEmpty)
      .map((rows) => SosAlert.fromJson(rows.first));

  /// Only [ApiException]s leave the data layer, with messages that are safe to show.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST301' || e.code == '401') throw const UnauthorizedException();
      throw const UnknownApiException('Could not reach the safety service. Please try again.');
    } on AuthException {
      throw const UnauthorizedException();
    } on Exception {
      throw const NetworkException();
    }
  }
}

final alertRepositoryProvider = Provider<AlertRepository>(
  (ref) => SupabaseAlertRepository(Supabase.instance.client),
);
