import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A table change seen by the app's Realtime connection, or [connected] when the channel
/// (re)subscribes, after which callers refetch because events may have been missed.
class TableChange {
  const TableChange({required this.table, required this.event, this.record = const {}});

  const TableChange.connected(this.table) : event = 'SUBSCRIBED', record = const {};

  final String table;

  /// INSERT, UPDATE, DELETE or SUBSCRIBED.
  final String event;
  final Map<String, dynamic> record;

  bool get isConnected => event == 'SUBSCRIBED';
  bool get isInsert => event == 'INSERT';
}

/// Realtime `postgres_changes`, subject to RLS: an admin (`is_admin()`) receives every row of
/// alerts, messages and locations; a student receives only rows of their own alerts (D-028).
abstract interface class RealtimeChanges {
  /// Changes on [table] (`alerts`, `messages`, `locations`), optionally only for one alert.
  /// The channel opens on listen and closes when the subscription is cancelled.
  Stream<TableChange> changes(String table, {String? alertId});
}

class SupabaseRealtimeChanges implements RealtimeChanges {
  SupabaseRealtimeChanges(this._client);

  final SupabaseClient _client;
  var _counter = 0;

  @override
  Stream<TableChange> changes(String table, {String? alertId}) {
    late final StreamController<TableChange> controller;
    RealtimeChannel? channel;
    controller = StreamController<TableChange>(
      onListen: () {
        channel = _client
            .channel('app-$table-${alertId ?? 'all'}-${_counter++}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: table,
              filter: alertId == null
                  ? null
                  : PostgresChangeFilter(
                      type: PostgresChangeFilterType.eq,
                      column: 'alert_id',
                      value: alertId,
                    ),
              callback: (payload) {
                if (controller.isClosed) return;
                controller.add(
                  TableChange(
                    table: table,
                    event: payload.eventType.name.toUpperCase(),
                    record: payload.newRecord,
                  ),
                );
              },
            )
            .subscribe((status, _) {
              if (status == RealtimeSubscribeStatus.subscribed && !controller.isClosed) {
                controller.add(TableChange.connected(table));
              }
            });
      },
      onCancel: () async {
        final c = channel;
        if (c != null) await _client.removeChannel(c);
      },
    );
    return controller.stream;
  }
}

final realtimeChangesProvider = Provider<RealtimeChanges>(
  (ref) => SupabaseRealtimeChanges(Supabase.instance.client),
);

/// How often live admin data refetches as a safety net when Realtime events are missed (the dashboard
/// uses 30 s while connected). Tests override it with `null` (no timer).
final livePollIntervalProvider = Provider<Duration?>((_) => const Duration(seconds: 30));
