import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'data/contacts_repository.dart';
import 'domain/emergency_contact.dart';

/// The signed-in student's contacts. Resets when the user changes.
final contactsProvider = AsyncNotifierProvider<ContactsNotifier, List<EmergencyContact>>(
  ContactsNotifier.new,
);

class ContactsNotifier extends AsyncNotifier<List<EmergencyContact>> {
  @override
  Future<List<EmergencyContact>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    return ref.watch(contactsRepositoryProvider).list();
  }

  Future<void> add({required String name, required String phone}) async {
    final userId = ref.read(currentUserIdProvider);
    final current = state.value ?? const <EmergencyContact>[];
    if (userId == null || current.length >= EmergencyContact.max) return;
    final created = await ref
        .read(contactsRepositoryProvider)
        .add(userId: userId, name: name.trim(), phone: phone.trim());
    state = AsyncData([...current, created]);
  }

  Future<void> remove(String id) async {
    await ref.read(contactsRepositoryProvider).remove(id);
    state = AsyncData([
      for (final c in state.value ?? const <EmergencyContact>[])
        if (c.id != id) c,
    ]);
  }
}

/// `null` while loading (or if loading failed), else whether the student has the 2 contacts
/// required before using the app (FR-AUTH-10). The router waits on `null`.
final hasRequiredContactsProvider = Provider<bool?>((ref) {
  final contacts = ref.watch(contactsProvider);
  if (contacts.hasError && !contacts.hasValue) return false;
  final list = contacts.value;
  return list == null ? null : list.length >= EmergencyContact.minRequired;
});
