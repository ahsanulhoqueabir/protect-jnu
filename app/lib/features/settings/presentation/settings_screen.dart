import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../shared/widgets/feedback/app_feedback.dart';
import '../../auth/auth_providers.dart';
import '../../emergency_contacts/contacts_providers.dart';
import '../../media/media_providers.dart';
import '../theme_mode_provider.dart';

/// App version text, or `null` if the platform cannot provide it.
final appVersionProvider = FutureProvider<String?>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  } on Object {
    return null;
  }
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sign out?',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (confirmed) await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final contactCount = ref.watch(contactsProvider).value?.length;
    final mediaCount = ref.watch(mediaListProvider).value?.length;
    final version = ref.watch(appVersionProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const _Section('Appearance'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {mode},
              onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
            ),
          ),
          const _Section('Safety'),
          Card(
            child: Column(
              children: [
                _NavTile(
                  icon: Icons.contacts_outlined,
                  title: 'Emergency contacts',
                  subtitle: contactCount == null ? null : '$contactCount of 3 saved',
                  onTap: () => context.push(Routes.contacts),
                ),
                const Divider(height: 1),
                _NavTile(
                  icon: Icons.photo_library_outlined,
                  title: 'SOS photos and videos',
                  subtitle: mediaCount == null
                      ? 'Saved on this phone only'
                      : '$mediaCount saved on this phone only',
                  onTap: () => context.push(Routes.media),
                ),
              ],
            ),
          ),
          const _Section('Account'),
          Card(
            child: Column(
              children: [
                _NavTile(
                  icon: Icons.lock_reset_rounded,
                  title: 'Change password',
                  subtitle: 'We email you a code',
                  onTap: () => _changePassword(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: context.colors.error),
                  title: Text('Sign out', style: TextStyle(color: context.colors.error)),
                  onTap: () => _signOut(context, ref),
                ),
              ],
            ),
          ),
          const _Section('About'),
          Card(
            child: Column(
              children: [
                _NavTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  onTap: () => context.push(Routes.terms),
                ),
                const Divider(height: 1),
                _NavTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () => context.push(Routes.privacy),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Version'),
                  subtitle: Text(version ?? 'Unknown'),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: "Protect JnU'ins",
                    applicationVersion: version,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Reuses the emailed-code reset flow: the student must be signed out to open it, so this
  /// only explains and confirms first.
  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Change password?',
      message:
          'You will be signed out. Choose "Forgot password" on the sign-in screen and we '
          'will email you a code.',
      confirmLabel: 'Continue',
    );
    if (ok) await ref.read(authProvider.notifier).logout();
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.title, required this.onTap, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
      child: Text(
        title,
        style: context.textTheme.titleSmall?.copyWith(color: context.colors.primary),
      ),
    );
  }
}
