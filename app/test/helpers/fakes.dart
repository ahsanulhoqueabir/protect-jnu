import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:protect_jnu/core/network/api_exception.dart';
import 'package:protect_jnu/features/auth/data/auth_repository.dart';
import 'package:protect_jnu/features/chat/data/chat_repository.dart';
import 'package:protect_jnu/features/chat/domain/chat_message.dart';
import 'package:protect_jnu/features/emergency_contacts/data/contacts_repository.dart';
import 'package:protect_jnu/features/emergency_contacts/domain/emergency_contact.dart';
import 'package:protect_jnu/features/location/domain/location_point.dart';
import 'package:protect_jnu/features/location/domain/location_sharing.dart';
import 'package:protect_jnu/features/sos/data/alert_repository.dart';
import 'package:protect_jnu/features/sos/data/location_service.dart';
import 'package:protect_jnu/features/sos/domain/sos_alert.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// In-memory contacts backend with the same 3-contact limit as the DB trigger.
class FakeContactsRepository implements ContactsRepository {
  FakeContactsRepository([List<EmergencyContact> initial = const []]) : rows = [...initial];

  final List<EmergencyContact> rows;
  var _next = 1;

  final listedFor = <String>[];

  @override
  Future<List<EmergencyContact>> list(String userId) async {
    listedFor.add(userId);
    return [...rows];
  }

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

  final openQueriedFor = <String>[];

  @override
  Future<SosAlert?> currentOpen(String userId) async {
    openQueriedFor.add(userId);
    return (open?.status.isOpen ?? false) ? open : null;
  }

  @override
  Future<SosAlert> create({required String userId, GeoFix? fix}) async {
    final existing = await currentOpen(userId);
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

/// In-memory chat backend with a controllable Realtime stream; [failSends] simulates being offline.
class FakeChatRepository implements ChatRepository {
  final rows = <ChatMessage>[];
  final _updates = StreamController<List<ChatMessage>>.broadcast();
  var failSends = false;
  var markReadCalls = 0;
  var _next = 1;

  @override
  Stream<List<ChatMessage>> watch(String alertId) async* {
    yield [...rows];
    yield* _updates.stream;
  }

  @override
  Future<ChatMessage> send({
    required String alertId,
    required String senderId,
    required String body,
  }) async {
    if (failSends) throw const NetworkException();
    final m = ChatMessage(
      id: 'm${_next++}',
      senderId: senderId,
      body: body,
      sentAt: DateTime.utc(2026, 11, 9, 10, 0, _next),
    );
    rows.add(m);
    _updates.add([...rows]);
    return m;
  }

  @override
  Future<void> markRead({required String alertId, required String userId}) async {
    markReadCalls++;
    for (var i = 0; i < rows.length; i++) {
      final m = rows[i];
      if (m.isUnreadFor(userId)) {
        rows[i] = ChatMessage(
          id: m.id,
          senderId: m.senderId,
          body: m.body,
          sentAt: m.sentAt,
          readAt: DateTime.utc(2026, 11, 9, 11),
        );
      }
    }
    _updates.add([...rows]);
  }

  /// An administrator's message arriving through Realtime.
  void incoming(String body, {String senderId = 'admin-1'}) {
    rows.add(
      ChatMessage(
        id: 'm${_next++}',
        senderId: senderId,
        body: body,
        sentAt: DateTime.utc(2026, 11, 9, 10, 0, _next),
      ),
    );
    _updates.add([...rows]);
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

/// Position source that never emits, so no foreground service is started in widget tests.
class FakePositionSource implements PositionSource {
  @override
  Stream<LocationPoint> start() => const Stream.empty();
}
