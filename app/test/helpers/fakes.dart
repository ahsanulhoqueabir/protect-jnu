import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:protect_jnu/features/auth/data/auth_repository.dart';
import 'package:protect_jnu/features/emergency_contacts/data/contacts_repository.dart';
import 'package:protect_jnu/features/emergency_contacts/domain/emergency_contact.dart';
import 'package:protect_jnu/features/sos/data/alert_repository.dart';
import 'package:protect_jnu/features/sos/data/location_service.dart';
import 'package:protect_jnu/features/sos/domain/sos_alert.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// In-memory contacts backend with the same 3-contact limit as the DB trigger.
class FakeContactsRepository implements ContactsRepository {
  FakeContactsRepository([List<EmergencyContact> initial = const []]) : rows = [...initial];

  final List<EmergencyContact> rows;
  var _next = 1;

  @override
  Future<List<EmergencyContact>> list() async => [...rows];

  @override
  Future<EmergencyContact> add({
    required String userId,
    required String name,
    required String phone,
  }) async {
    final created = EmergencyContact(id: 'c${_next++}', name: name, phone: phone);
    rows.add(created);
    return created;
  }

  @override
  Future<void> remove(String id) async => rows.removeWhere((c) => c.id == id);
}

/// In-memory alerts backend: same one-open-alert rule as the DB index (D-060) and a controllable
/// Realtime stream.
class FakeAlertRepository implements AlertRepository {
  FakeAlertRepository({this.open});

  SosAlert? open;
  final created = <GeoFix?>[];
  final _updates = StreamController<SosAlert>.broadcast();
  var cancelCalls = 0;

  @override
  Future<SosAlert?> currentOpen() async => (open?.status.isOpen ?? false) ? open : null;

  @override
  Future<SosAlert> create({required String userId, GeoFix? fix}) async {
    final existing = await currentOpen();
    if (existing != null) return existing;
    created.add(fix);
    return open = SosAlert(
      id: 'alert-${created.length}',
      status: AlertStatus.active,
      startedAt: DateTime.utc(2026, 11, 9, 10),
    );
  }

  @override
  Future<void> cancel(String alertId) async {
    cancelCalls++;
    open = SosAlert(id: alertId, status: AlertStatus.cancelled, startedAt: open!.startedAt);
  }

  @override
  Stream<SosAlert> watch(String alertId) => _updates.stream;

  /// What Realtime would push when an admin changes the status.
  void push(AlertStatus status) {
    open = SosAlert(id: open!.id, status: status, startedAt: open!.startedAt);
    _updates.add(open!);
  }
}

class FakeLocationService implements LocationService {
  FakeLocationService(this.fix);

  final GeoFix? fix;
  var calls = 0;

  @override
  Future<GeoFix?> firstFix() async {
    calls++;
    return fix;
  }
}
