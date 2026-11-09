import 'package:sqflite/sqflite.dart';

import '../domain/location_point.dart';

/// Persistent FIFO of points not yet uploaded (D-066: SQLite, newest 500 kept).
abstract interface class LocationQueue {
  static const maxPoints = 500;

  /// Adds a point; when more than [maxPoints] are stored the oldest are dropped.
  Future<void> add(String alertId, LocationPoint point);

  /// Oldest points first, at most [limit], for [alertId].
  Future<List<LocationPoint>> oldest(String alertId, {int limit = 50});

  Future<void> remove(Iterable<int> ids);
  Future<void> clear(String alertId);
  Future<int> count(String alertId);
}

class SqfliteLocationQueue implements LocationQueue {
  SqfliteLocationQueue(this._open);

  final Future<Database> Function() _open;
  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  /// Opens the on-device database file.
  static Future<Database> openDefault() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      '$dir/location_queue.db',
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE points (id INTEGER PRIMARY KEY AUTOINCREMENT, alert_id TEXT NOT NULL, '
        'lat REAL NOT NULL, lng REAL NOT NULL, accuracy REAL, recorded_at INTEGER NOT NULL)',
      ),
    );
  }

  @override
  Future<void> add(String alertId, LocationPoint p) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert('points', {
        'alert_id': alertId,
        'lat': p.latitude,
        'lng': p.longitude,
        'accuracy': p.accuracy,
        'recorded_at': p.recordedAt.millisecondsSinceEpoch,
      });
      await txn.execute(
        'DELETE FROM points WHERE alert_id = ? AND id NOT IN '
        '(SELECT id FROM points WHERE alert_id = ? ORDER BY id DESC LIMIT ?)',
        [alertId, alertId, LocationQueue.maxPoints],
      );
    });
  }

  @override
  Future<List<LocationPoint>> oldest(String alertId, {int limit = 50}) async {
    final rows = await (await _database).query(
      'points',
      where: 'alert_id = ?',
      whereArgs: [alertId],
      orderBy: 'recorded_at ASC, id ASC',
      limit: limit,
    );
    return [
      for (final r in rows)
        LocationPoint(
          id: r['id']! as int,
          latitude: (r['lat']! as num).toDouble(),
          longitude: (r['lng']! as num).toDouble(),
          accuracy: (r['accuracy'] as num?)?.toDouble(),
          recordedAt: DateTime.fromMillisecondsSinceEpoch(r['recorded_at']! as int, isUtc: true),
        ),
    ];
  }

  @override
  Future<void> remove(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    final marks = List.filled(ids.length, '?').join(',');
    await (await _database).delete('points', where: 'id IN ($marks)', whereArgs: ids.toList());
  }

  @override
  Future<void> clear(String alertId) async {
    await (await _database).delete('points', where: 'alert_id = ?', whereArgs: [alertId]);
  }

  @override
  Future<int> count(String alertId) async {
    final r = await (await _database).rawQuery(
      'SELECT COUNT(*) AS c FROM points WHERE alert_id = ?',
      [alertId],
    );
    return r.first['c']! as int;
  }
}

/// Test double with the same rules.
class InMemoryLocationQueue implements LocationQueue {
  final _rows = <({int id, String alertId, LocationPoint p})>[];
  int _next = 1;

  @override
  Future<void> add(String alertId, LocationPoint p) async {
    _rows.add((id: _next++, alertId: alertId, p: p));
    final mine = _rows.where((r) => r.alertId == alertId).toList();
    final excess = mine.length - LocationQueue.maxPoints;
    if (excess > 0) {
      for (final r in mine.take(excess)) {
        _rows.remove(r);
      }
    }
  }

  @override
  Future<List<LocationPoint>> oldest(String alertId, {int limit = 50}) async {
    final mine = _rows.where((r) => r.alertId == alertId).toList()
      ..sort((a, b) {
        final c = a.p.recordedAt.compareTo(b.p.recordedAt);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    return [
      for (final r in mine.take(limit))
        LocationPoint(
          id: r.id,
          latitude: r.p.latitude,
          longitude: r.p.longitude,
          accuracy: r.p.accuracy,
          recordedAt: r.p.recordedAt,
        ),
    ];
  }

  @override
  Future<void> remove(Iterable<int> ids) async => _rows.removeWhere((r) => ids.contains(r.id));

  @override
  Future<void> clear(String alertId) async => _rows.removeWhere((r) => r.alertId == alertId);

  @override
  Future<int> count(String alertId) async => _rows.where((r) => r.alertId == alertId).length;
}
