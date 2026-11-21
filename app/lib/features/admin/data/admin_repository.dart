import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../domain/admin_alert.dart';
import '../domain/admin_chat.dart';
import '../domain/admin_user.dart';
import '../domain/support_report.dart';

/// The admin side of the app, over the existing `/api/admin/*` routes (docs/api-contract.md 6,
/// 6b, 6c). The server re-checks `role = 'admin'` on every call (`withAdmin`) and answers 403
/// `not_admin` otherwise, so hiding screens in the app is a convenience, not the security check.
abstract interface class AdminRepository {
  /// `status`: open (active + acknowledged), all, active, acknowledged, resolved, cancelled.
  Future<AdminPage<AdminAlert>> alerts({String status = 'open', int page = 1});
  Future<AdminAlertDetail> alert(String id);
  Future<List<TrailPoint>> locations(String alertId);

  /// Throws [CodedApiException] `invalid_transition` (409) when another admin got there first.
  Future<void> transition(String alertId, AlertAction action);

  Future<List<Conversation>> conversations();
  Future<List<AdminMessage>> messages(String alertId, {DateTime? since});

  /// Throws [CodedApiException] `chat_closed` (409) once the alert is resolved or cancelled.
  Future<void> sendMessage(String alertId, String body);
  Future<void> markRead(String alertId);

  Future<AdminPage<AdminUser>> users({int page = 1});
  Future<SupportReport> report(int year);

  /// The CSV body of `/api/admin/reports/export` (columns year, month, alerts_handled,
  /// students_supported).
  Future<String> reportCsv(int year);
}

class ApiAdminRepository implements AdminRepository {
  ApiAdminRepository(this._api);

  final ApiClient _api;

  /// Unwraps `{ "success": true, "data": ... }`.
  T _data<T>(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is T) return data;
    throw const BadResponseException();
  }

  AdminPage<T> _page<T>(Map<String, dynamic> data, T Function(Map<String, dynamic>) item) =>
      AdminPage(
        items: [
          for (final row in (data['items'] as List<dynamic>? ?? const []))
            item(row as Map<String, dynamic>),
        ],
        page: (data['page'] as num?)?.toInt() ?? 1,
        pageSize: (data['page_size'] as num?)?.toInt() ?? 20,
        total: (data['total'] as num?)?.toInt() ?? 0,
      );

  @override
  Future<AdminPage<AdminAlert>> alerts({String status = 'open', int page = 1}) async {
    final body = await _api.get<Map<String, dynamic>>(
      '/api/admin/alerts',
      query: {'status': status, 'page': page},
    );
    return _page(_data<Map<String, dynamic>>(body), AdminAlert.fromJson);
  }

  @override
  Future<AdminAlertDetail> alert(String id) async {
    final body = await _api.get<Map<String, dynamic>>('/api/admin/alerts/$id');
    return AdminAlertDetail.fromJson(_data<Map<String, dynamic>>(body));
  }

  @override
  Future<List<TrailPoint>> locations(String alertId) async {
    final body = await _api.get<Map<String, dynamic>>('/api/admin/alerts/$alertId/locations');
    return [
      for (final p in _data<List<dynamic>>(body)) TrailPoint.fromJson(p as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> transition(String alertId, AlertAction action) async {
    await _api.patch<Map<String, dynamic>>(
      '/api/admin/alerts/$alertId/status',
      data: {'action': action.name},
    );
  }

  @override
  Future<List<Conversation>> conversations() async {
    final body = await _api.get<Map<String, dynamic>>('/api/admin/conversations');
    return [
      for (final c in _data<List<dynamic>>(body)) Conversation.fromJson(c as Map<String, dynamic>),
    ];
  }

  @override
  Future<List<AdminMessage>> messages(String alertId, {DateTime? since}) async {
    final body = await _api.get<Map<String, dynamic>>(
      '/api/admin/alerts/$alertId/messages',
      query: {if (since != null) 'since': since.toUtc().toIso8601String()},
    );
    return [
      for (final m in _data<List<dynamic>>(body)) AdminMessage.fromJson(m as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> sendMessage(String alertId, String body) async {
    await _api.post<Map<String, dynamic>>(
      '/api/admin/alerts/$alertId/messages',
      data: {'body': body},
    );
  }

  @override
  Future<void> markRead(String alertId) async {
    await _api.patch<Map<String, dynamic>>('/api/admin/alerts/$alertId/messages');
  }

  @override
  Future<AdminPage<AdminUser>> users({int page = 1}) async {
    final body = await _api.get<Map<String, dynamic>>('/api/admin/users', query: {'page': page});
    return _page(_data<Map<String, dynamic>>(body), AdminUser.fromJson);
  }

  @override
  Future<SupportReport> report(int year) async {
    final body = await _api.get<Map<String, dynamic>>('/api/admin/reports', query: {'year': year});
    final data = _data<Map<String, dynamic>>(body);
    return SupportReport(
      year: (data['year'] as num?)?.toInt() ?? year,
      months: [
        for (final m in (data['months'] as List<dynamic>? ?? const []))
          ReportMonth.fromJson(m as Map<String, dynamic>),
      ],
    );
  }

  @override
  Future<String> reportCsv(int year) =>
      _api.getText('/api/admin/reports/export', query: {'year': year});
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => ApiAdminRepository(ref.watch(apiClientProvider)),
);
