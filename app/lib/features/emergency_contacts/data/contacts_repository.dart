import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_exception.dart';
import '../domain/emergency_contact.dart';

/// Reads and writes `emergency_contacts` straight through Supabase; Row Level Security limits
/// every call to the signed-in student's own rows (D-004, D-028, D-054).
abstract interface class ContactsRepository {
  Future<List<EmergencyContact>> list();
  Future<EmergencyContact> add({
    required String userId,
    required String name,
    required String phone,
  });
  Future<void> remove(String id);
}

class SupabaseContactsRepository implements ContactsRepository {
  SupabaseContactsRepository(this._client);

  final SupabaseClient _client;

  static const _columns = 'id, name, phone';

  @override
  Future<List<EmergencyContact>> list() => _guard(() async {
    final rows = await _client.from('emergency_contacts').select(_columns).order('created_at');
    return rows.map(EmergencyContact.fromJson).toList();
  });

  @override
  Future<EmergencyContact> add({
    required String userId,
    required String name,
    required String phone,
  }) => _guard(() async {
    final row = await _client
        .from('emergency_contacts')
        .insert({'user_id': userId, 'name': name, 'phone': phone})
        .select(_columns)
        .single();
    return EmergencyContact.fromJson(row);
  });

  @override
  Future<void> remove(String id) =>
      _guard(() => _client.from('emergency_contacts').delete().eq('id', id));

  /// Only [ApiException]s leave the data layer, with messages that are safe to show.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      // 23514 = check_violation: the "at most 3" trigger or the phone-format constraint.
      if (e.code == '23514') {
        throw const UnknownApiException(
          'A student can keep at most 3 contacts, with valid phone numbers.',
        );
      }
      if (e.code == 'PGRST301' || e.code == '401') throw const UnauthorizedException();
      throw const UnknownApiException('Could not save your contacts. Please try again.');
    } on AuthException {
      throw const UnauthorizedException();
    } on Exception {
      throw const NetworkException();
    }
  }
}

final contactsRepositoryProvider = Provider<ContactsRepository>(
  (ref) => SupabaseContactsRepository(Supabase.instance.client),
);
