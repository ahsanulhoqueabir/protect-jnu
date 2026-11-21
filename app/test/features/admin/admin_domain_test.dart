import 'package:flutter_test/flutter_test.dart';
import 'package:protect_jnu/features/admin/domain/admin_alert.dart';
import 'package:protect_jnu/features/admin/domain/admin_chat.dart';
import 'package:protect_jnu/features/admin/domain/support_report.dart';
import 'package:protect_jnu/features/admin/presentation/widgets/admin_widgets.dart';
import 'package:protect_jnu/features/sos/domain/sos_alert.dart';

import '../../helpers/admin_fakes.dart';

TrailPoint point(String id, int second) => TrailPoint(
  id: id,
  latitude: 23.7,
  longitude: 90.4,
  recordedAt: DateTime.utc(2026, 11, 9, 10, 0, second),
);

void main() {
  test('trail merge orders by time, drops duplicates and keeps the newest 20', () {
    final merged = mergeTrail([point('b', 2)], [point('a', 1), point('b', 2), point('c', 3)]);
    expect(merged.map((p) => p.id), ['a', 'b', 'c']);
    final many = mergeTrail(const [], [for (var i = 0; i < 30; i++) point('$i', i)]);
    expect(many, hasLength(20));
    expect(many.first.id, '10');
    expect(many.last.id, '29');
  });

  test('chat merge dedupes by id and orders oldest first', () {
    AdminMessage m(String id, int s) => AdminMessage(
      id: id,
      senderId: 'x',
      body: id,
      sentAt: DateTime.utc(2026, 1, 1, 0, 0, s),
      fromStudent: true,
    );
    expect(mergeAdminMessages([m('2', 2)], [m('1', 1), m('2', 2)]).map((e) => e.id), ['1', '2']);
  });

  test('only active -> acknowledged -> resolved; chat open only while the alert is open', () {
    expect(alertDetail('a', AlertStatus.active).nextAction, AlertAction.acknowledge);
    expect(alertDetail('a', AlertStatus.acknowledged).nextAction, AlertAction.resolve);
    expect(alertDetail('a', AlertStatus.resolved).nextAction, isNull);
    expect(alertDetail('a', AlertStatus.cancelled).nextAction, isNull);
    expect(alertDetail('a', AlertStatus.acknowledged).chatOpen, isTrue);
    expect(alertDetail('a', AlertStatus.resolved).chatOpen, isFalse);
  });

  test('page math', () {
    const empty = AdminPage<int>(items: [], page: 1, pageSize: 20, total: 0);
    expect(empty.pageCount, 1);
    expect(empty.hasNext, isFalse);
    const p = AdminPage<int>(items: [], page: 3, pageSize: 20, total: 41);
    expect(p.pageCount, 3);
    expect(p.hasNext, isFalse);
    expect(p.hasPrevious, isTrue);
  });

  test('report year follows Asia/Dhaka (UTC+6)', () {
    expect(currentReportYear(DateTime.utc(2026, 12, 31, 18, 30)), 2027);
    expect(currentReportYear(DateTime.utc(2026, 12, 31, 17, 59)), 2026);
  });

  test('time ago labels', () {
    final now = DateTime.utc(2026, 11, 9, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 12)), now), '12s ago');
    expect(timeAgo(now.subtract(const Duration(minutes: 5)), now), '5 min ago');
    expect(timeAgo(now.subtract(const Duration(hours: 2)), now), '2 h ago');
  });
}
