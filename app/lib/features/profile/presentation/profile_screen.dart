import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/feedback/app_feedback.dart';
import '../../auth/auth_providers.dart';
import '../../emergency_contacts/contacts_providers.dart';

Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final ok = await showConfirmDialog(context, title: 'Sign out?', confirmLabel: 'Sign out');
  if (ok) await ref.read(authProvider.notifier).logout();
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final contactCount = ref.watch(contactsProvider).value?.length;
    final colors = context.colors;
    // Null only for the moment between sign-out and the router's redirect.
    if (user == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: colors.primaryContainer,
              child: Text(
                user.fullName.initials,
                style: context.textTheme.headlineMedium?.copyWith(color: colors.onPrimaryContainer),
              ),
            ),
          ),
          const Gap(AppSpacing.md),
          Text(user.fullName, textAlign: TextAlign.center, style: context.textTheme.headlineSmall),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const Gap(AppSpacing.lg),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Student ID'),
                  subtitle: Text(user.studentId),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Phone'),
                  subtitle: Text(user.phone ?? 'Not set'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.contacts_outlined),
                  title: const Text('Emergency contacts'),
                  subtitle: Text(contactCount == null ? '…' : '$contactCount of 3 saved'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(Routes.contacts),
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.lg),
          AppButton(
            label: 'Sign out',
            icon: Icons.logout_rounded,
            variant: AppButtonVariant.secondary,
            // Not async: AppButton would spin for as long as the dialog stays open.
            onPressed: () => unawaited(_confirmSignOut(context, ref)),
          ),
        ],
      ),
    );
  }
}
