import 'package:mocktail/mocktail.dart';
import 'package:protect_jnu/features/auth/data/auth_repository.dart';
import 'package:protect_jnu/features/emergency_contacts/data/contacts_repository.dart';
import 'package:protect_jnu/features/emergency_contacts/domain/emergency_contact.dart';

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
