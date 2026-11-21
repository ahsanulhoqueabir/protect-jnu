import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protect_jnu/core/network/api_client.dart';
import 'package:protect_jnu/core/network/api_exception.dart';
import 'package:protect_jnu/features/admin/data/admin_repository.dart';
import 'package:protect_jnu/features/admin/domain/admin_alert.dart';
import 'package:protect_jnu/features/sos/domain/sos_alert.dart';

/// Answers each request with the canned body for its path and records what was sent.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.responses);

  final Map<String, (int, Object)> responses;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? _,
  ) async {
    requests.add(options);
    final (status, data) = responses[options.path] ?? (404, {'success': false, 'error': 'x'});
    final isText = data is String;
    return ResponseBody.fromString(
      isText ? data : jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [isText ? 'text/csv' : 'application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Adapter adapter;
  AdminRepository repo(Map<String, (int, Object)> responses) {
    adapter = _Adapter(responses);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
    return ApiAdminRepository(ApiClient(dio));
  }

  Map<String, Object> ok(Object data) => {'success': true, 'data': data};

  test('lists alerts with status and page, parsing the student card', () async {
    final r = repo({
      '/api/admin/alerts': (
        200,
        ok({
          'items': [
            {
              'id': 'a1',
              'status': 'active',
              'started_at': '2026-11-09T10:00:00Z',
              'acknowledged_at': null,
              'resolved_at': null,
              'cancelled_at': null,
              'student': {'full_name': 'Ada', 'student_id': 'B210305040'},
            },
          ],
          'page': 2,
          'page_size': 20,
          'total': 41,
        }),
      ),
    });
    final page = await r.alerts(status: 'all', page: 2);
    expect(adapter.requests.single.queryParameters, {'status': 'all', 'page': 2});
    expect(page.items.single.student.fullName, 'Ada');
    expect(page.items.single.status, AlertStatus.active);
    expect(page.pageCount, 3);
    expect(page.hasNext, isTrue);
  });

  test('reads alert detail with contacts and acting admins', () async {
    final r = repo({
      '/api/admin/alerts/a1': (
        200,
        ok({
          'id': 'a1',
          'status': 'acknowledged',
          'started_at': '2026-11-09T10:00:00Z',
          'acknowledged_at': '2026-11-09T10:01:00Z',
          'resolved_at': null,
          'cancelled_at': null,
          'first_latitude': 23.7,
          'first_longitude': 90.4,
          'student': {
            'full_name': 'Ada',
            'student_id': 'B210305040',
            'phone': '01700000000',
            'email': 'ada@cse.jnu.ac.bd',
          },
          'contacts': [
            {'id': 'c1', 'name': 'Mother', 'phone': '01711111111'},
          ],
          'acknowledged_by_email': 'grace@cse.jnu.ac.bd',
          'resolved_by_email': null,
        }),
      ),
    });
    final d = await r.alert('a1');
    expect(d.contacts.single.name, 'Mother');
    expect(d.acknowledgedByEmail, 'grace@cse.jnu.ac.bd');
    expect(d.nextAction, AlertAction.resolve);
    expect(d.firstLatitude, 23.7);
  });

  test('sends the transition action and surfaces a lost race as invalid_transition', () async {
    final r = repo({
      '/api/admin/alerts/a1/status': (
        409,
        {
          'success': false,
          'error': 'This alert is acknowledged and cannot be changed that way.',
          'code': 'invalid_transition',
          'data': {'current_status': 'acknowledged'},
        },
      ),
    });
    await expectLater(
      r.transition('a1', AlertAction.acknowledge),
      throwsA(
        isA<CodedApiException>()
            .having((e) => e.code, 'code', 'invalid_transition')
            .having((e) => e.details['current_status'], 'current', 'acknowledged'),
      ),
    );
    expect(adapter.requests.single.method, 'PATCH');
    expect(adapter.requests.single.data, {'action': 'acknowledge'});
  });

  test('a non-admin token is refused by the server with not_admin', () async {
    final r = repo({
      '/api/admin/users': (
        403,
        {'success': false, 'error': 'Administrator access required', 'code': 'not_admin'},
      ),
    });
    await expectLater(
      r.users(),
      throwsA(isA<CodedApiException>().having((e) => e.code, 'code', 'not_admin')),
    );
  });

  test('chat: history with since, send body, mark read', () async {
    final r = repo({
      '/api/admin/alerts/a1/messages': (
        200,
        ok([
          {
            'id': 'm1',
            'sender_id': 's1',
            'body': 'help',
            'sent_at': '2026-11-09T10:00:00Z',
            'read_at': null,
            'sender_name': 'Ada',
            'from_student': true,
          },
        ]),
      ),
    });
    final since = DateTime.utc(2026, 11, 9, 9);
    final rows = await r.messages('a1', since: since);
    expect(rows.single.fromStudent, isTrue);
    expect(adapter.requests.last.queryParameters['since'], since.toIso8601String());
    await r.sendMessage('a1', 'On our way');
    expect(adapter.requests.last.method, 'POST');
    expect(adapter.requests.last.data, {'body': 'On our way'});
    await r.markRead('a1');
    expect(adapter.requests.last.method, 'PATCH');
  });

  test('conversations, locations, users and reports parse', () async {
    final r = repo({
      '/api/admin/conversations': (
        200,
        ok([
          {
            'alert_id': 'a1',
            'last_body': 'hi',
            'last_sent_at': '2026-11-09T10:00:00Z',
            'last_sender_id': 's1',
            'unread_count': 2,
            'student': {'full_name': 'Ada', 'student_id': 'B210305040'},
            'status': 'active',
          },
        ]),
      ),
      '/api/admin/alerts/a1/locations': (
        200,
        ok([
          {
            'id': 7,
            'latitude': 23.7,
            'longitude': 90.4,
            'accuracy': 5,
            'recorded_at': '2026-11-09T10:00:10Z',
          },
        ]),
      ),
      '/api/admin/users': (
        200,
        ok({
          'items': [
            {
              'id': 'u1',
              'full_name': 'Ada',
              'student_id': 'B210305040',
              'phone': null,
              'role': 'admin',
              'created_at': '2026-11-09T10:00:00Z',
              'email': 'ada@cse.jnu.ac.bd',
              'verified': true,
            },
          ],
          'page': 1,
          'page_size': 20,
          'total': 1,
        }),
      ),
      '/api/admin/reports': (
        200,
        ok({
          'year': 2026,
          'months': [
            {'year': 2026, 'month': 3, 'alerts_handled': 2, 'students_supported': 1},
          ],
        }),
      ),
      '/api/admin/reports/export': (200, 'year,month,alerts_handled,students_supported\n'),
    });
    expect((await r.conversations()).single.unreadCount, 2);
    expect((await r.locations('a1')).single.id, '7');
    expect((await r.users()).items.single.isAdmin, isTrue);
    final report = await r.report(2026);
    expect(report.totalAlerts, 2);
    expect(adapter.requests.last.queryParameters, {'year': 2026});
    expect(await r.reportCsv(2026), startsWith('year,month'));
  });
}
