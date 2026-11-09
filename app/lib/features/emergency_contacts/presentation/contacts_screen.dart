import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/forms/validators.dart';
import '../../../core/utils/extensions.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/feedback/app_feedback.dart';
import '../../../shared/widgets/forms/app_text_field.dart';
import '../contacts_providers.dart';
import '../domain/emergency_contact.dart';

/// Emergency contacts: shown right after first login until 2 are saved (FR-AUTH-10), and
/// reachable later from Profile. Name + phone only (D-057); 2 to 3 contacts.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await runGuarded(
      context,
      () => ref.read(contactsProvider.notifier).add(name: _name.text, phone: _phone.text),
    );
    if (ok) {
      _name.clear();
      _phone.clear();
      _formKey.currentState?.reset();
    }
  }

  Future<void> _remove(EmergencyContact contact) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove ${contact.name}?',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await runGuarded(context, () => ref.read(contactsProvider.notifier).remove(contact.id));
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider);
    final count = contacts.value?.length ?? 0;
    final ready = count >= EmergencyContact.minRequired;

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency contacts')),
      body: AsyncValueView<List<EmergencyContact>>(
        value: contacts,
        onRetry: () => ref.invalidate(contactsProvider),
        data: (list) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Add ${EmergencyContact.minRequired} to ${EmergencyContact.max} people we can '
              'alert if you are in danger.',
              style: context.textTheme.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            const Gap(AppSpacing.lg),
            for (final contact in list) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(contact.name),
                  subtitle: Text(contact.phone),
                  trailing: IconButton(
                    tooltip: 'Remove ${contact.name}',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _remove(contact),
                  ),
                ),
              ),
              const Gap(AppSpacing.sm),
            ],
            if (list.length < EmergencyContact.max) ...[
              const Gap(AppSpacing.sm),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: 'Contact name',
                      controller: _name,
                      prefixIcon: Icons.person_outline_rounded,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: Validators.compose([
                        Validators.required('Enter a name'),
                        Validators.maxLength(100),
                      ]),
                    ),
                    const Gap(AppSpacing.md),
                    AppTextField(
                      label: 'Phone',
                      controller: _phone,
                      hint: '01XXXXXXXXX',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
                      onSubmitted: (_) => _add(),
                      validator: Validators.compose([
                        Validators.required('Enter a phone number'),
                        Validators.bdPhone(),
                      ]),
                    ),
                    const Gap(AppSpacing.md),
                    AppButton(
                      label: 'Add contact',
                      icon: Icons.add_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: _add,
                    ),
                  ],
                ),
              ),
            ],
            const Gap(AppSpacing.xl),
            AppButton(
              label: ready
                  ? 'Done'
                  : 'Add ${EmergencyContact.minRequired - count} more to continue',
              onPressed: ready ? () => context.go(Routes.home) : null,
            ),
          ],
        ),
      ),
    );
  }
}
