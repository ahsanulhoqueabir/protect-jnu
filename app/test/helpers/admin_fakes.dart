import 'dart:async';

import 'package:protect_jnu/core/network/api_exception.dart';
import 'package:protect_jnu/core/notifications/app_notifier.dart';
import 'package:protect_jnu/core/realtime/realtime_changes.dart';
import 'package:protect_jnu/features/admin/data/admin_repository.dart';
import 'package:protect_jnu/features/admin/domain/admin_alert.dart';
import 'package:protect_jnu/features/admin/domain/admin_chat.dart';
import 'package:protect_jnu/features/admin/domain/admin_user.dart';
import 'package:protect_jnu/features/admin/domain/support_report.dart';
import 'package:protect_jnu/features/auth/domain/user.dart';
import 'package:protect_jnu/features/sos/domain/sos_alert.dart';

const adminUser = User(
  id: 'admin-1',
  fullName: 'Grace Admin',
  studentId: 'B210305041',
  email: 'grace@cse.jnu.ac.bd',
  role: 'admin',
);

const studentUser = User(
  id: 'student-1',
  fullName: 'Ada Lovelace',
  studentId: 'B210305040',
  email: 'ada@cse.jnu.ac.bd',
);

const ada = AlertStudent(fullName: 'Ada Lovelace', studentId: 'B210305040');

AdminAlert adminAlert(String id, AlertStatus status, {AlertStudent student = ada}) =>
    AdminAlert(id: id, status: status, startedAt: DateTime.utc(2026, 11, 9, 10), student: student);

AdminAlertDetail alertDetail(String id, AlertStatus status) => AdminAlertDetail(
  id: id,
  status: status,
  startedAt: DateTime.utc(2026, 11, 9, 10),
  acknowledgedAt: status == AlertStatus.active ? null : DateTime.utc(2026, 11, 9, 10, 1),
  acknowledgedByEmail: status == AlertStatus.active ? null : 'grace@cse.jnu.ac.bd',
  student: const AlertStudent(
    fullName: 'Ada Lovelace',
    studentId: 'B210305040',
    phone: '01700000000',
    email: 'ada@cse.jnu.ac.bd',
  ),
  contacts: const [AdminContact(id: 'c1', name: 'Mother', phone: '01711111111')],
);

/// In-memory admin backend with the same transition rule as the server.
class FakeAdminRepository implements AdminRepository {
  List<AdminAlert> open = [];
  final details = <String, AdminAlertDetail>{};
  List<TrailPoint> trail = [];
  List<Conversation> conversationRows = [];
  final threads = <String, List<AdminMessage>>{};
  List<AdminUser> userRows = [];
  SupportReport? reportValue;
  String csv = 'year,month,alerts_handled,students_supported\n2026,1,0,0\n';
  final calls = <String>[];
  var alertsCalls = 0;
  var _next = 1;

  /// Simulates another admin acting first.
  var raceOnTransition = false;

  @override
  Future<AdminPage<AdminAlert>> alerts({String status = 'open', int page = 1}) async {
    alertsCalls++;
    calls.add('alerts:$status:$page');
    final items = status == 'open' || status == 'all'
        ? open
        : open.where((a) => a.status.name == status).toList();
    return AdminPage(items: items, page: page, pageSize: 20, total: items.length);
  }

  @override
  Future<AdminAlertDetail> alert(String id) async {
    calls.add('alert:$id');
    final d = details[id];
    if (d == null) throw const NotFoundException();
    return d;
  }

  @override
  Future<List<TrailPoint>> locations(String alertId) async => trail;

  @override
  Future<void> transition(String alertId, AlertAction action) async {
    calls.add('transition:$alertId:${action.name}');
    final d = details[alertId]!;
    if (raceOnTransition) {
      details[alertId] = alertDetail(alertId, AlertStatus.acknowledged);
      throw const CodedApiException(
        statusCode: 409,
        code: 'invalid_transition',
        message: 'This alert is acknowledged and cannot be changed that way.',
        details: {'current_status': 'acknowledged'},
      );
    }
    details[alertId] = alertDetail(
      alertId,
      action == AlertAction.acknowledge ? AlertStatus.acknowledged : AlertStatus.resolved,
    );
    if (d.nextAction != action) throw StateError('wrong transition');
  }

  @override
  Future<List<Conversation>> conversations() async => conversationRows;

  @override
  Future<List<AdminMessage>> messages(String alertId, {DateTime? since}) async {
    final all = threads[alertId] ?? const [];
    return since == null ? all : all.where((m) => m.sentAt.isAfter(since)).toList();
  }

  @override
  Future<void> sendMessage(String alertId, String body) async {
    calls.add('send:$alertId:$body');
    final d = details[alertId];
    if (d != null && !d.chatOpen) {
      throw const CodedApiException(
        statusCode: 409,
        code: 'chat_closed',
        message: 'This conversation is closed.',
      );
    }
    (threads[alertId] ??= []).add(
      AdminMessage(
        id: 'am${_next++}',
        senderId: 'admin-1',
        body: body,
        sentAt: DateTime.utc(2026, 11, 9, 11, 0, _next),
        senderName: 'Grace Admin',
        fromStudent: false,
      ),
    );
  }

  @override
  Future<void> markRead(String alertId) async {
    calls.add('markRead:$alertId');
    threads[alertId] = [
      for (final m in threads[alertId] ?? const <AdminMessage>[])
        m.fromStudent && m.readAt == null
            ? AdminMessage(
                id: m.id,
                senderId: m.senderId,
                body: m.body,
                sentAt: m.sentAt,
                readAt: DateTime.utc(2026, 11, 9, 12),
                fromStudent: true,
              )
            : m,
    ];
  }

  @override
  Future<AdminPage<AdminUser>> users({int page = 1}) async {
    calls.add('users:$page');
    return AdminPage(items: userRows, page: page, pageSize: 20, total: 45);
  }

  @override
  Future<SupportReport> report(int year) async {
    calls.add('report:$year');
    return reportValue ??
        SupportReport(
          year: year,
          months: [
            for (var m = 1; m <= 12; m++)
              ReportMonth(
                year: year,
                month: m,
                alertsHandled: m == 3 ? 2 : 0,
                studentsSupported: m == 3 ? 1 : 0,
              ),
          ],
        );
  }

  @override
  Future<String> reportCsv(int year) async {
    calls.add('csv:$year');
    return csv;
  }
}

/// Realtime under test control: [emit] pushes a change to every listener of that table.
class FakeRealtimeChanges implements RealtimeChanges {
  final _controllers = <StreamController<TableChange>>[];
  final listened = <String>[];

  @override
  Stream<TableChange> changes(String table, {String? alertId}) {
    listened.add(alertId == null ? table : '$table:$alertId');
    final c = StreamController<TableChange>.broadcast();
    _controllers.add(c);
    return c.stream.where((change) => change.table == table);
  }

  void emit(TableChange change) {
    for (final c in _controllers) {
      if (!c.isClosed) c.add(change);
    }
  }
}

/// Records notifications instead of showing them.
class FakeAppNotifier implements AppNotifier {
  final shown = <AppNotice>[];
  var vibrations = 0;
  var permissionRequests = 0;
  final _taps = StreamController<String>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermission() async => permissionRequests++;

  @override
  Future<void> show(AppNotice notice) async => shown.add(notice);

  @override
  Stream<String> get taps => _taps.stream;

  void tap(String route) => _taps.add(route);

  @override
  Future<void> vibrate({bool urgent = false}) async => vibrations++;
}
