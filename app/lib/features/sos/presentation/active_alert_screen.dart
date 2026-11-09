import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/feedback/app_feedback.dart';
import '../../auth/auth_providers.dart';
import '../../chat/chat_providers.dart';
import '../domain/sos_alert.dart';
import '../sos_providers.dart';

/// Status of the student's alert, live through Realtime (FR-SOS). Map and chat come in later phases.
class ActiveAlertScreen extends ConsumerWidget {
  const ActiveAlertScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alert = ref.watch(openAlertProvider).value;
    if (alert == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your alert')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppButton(label: 'Back to home', onPressed: () => context.go(Routes.home)),
          ),
        ),
      );
    }

    return PopScope(
      onPopInvokedWithResult: (_, _) => ref.read(openAlertProvider.notifier).dismissClosed(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Your alert')),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _Headline(alert: alert),
            const SizedBox(height: AppSpacing.lg),
            _Steps(alert: alert),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Sent ${alert.startedAt.toLocal().formatted}',
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            _MessagesButton(alertId: alert.id),
            const SizedBox(height: AppSpacing.xl),
            if (alert.status == AlertStatus.active)
              AppButton(
                label: "I'm safe, cancel the alert",
                variant: AppButtonVariant.destructive,
                onPressed: () async {
                  final ok = await showConfirmDialog(
                    context,
                    title: 'Cancel the alert?',
                    message: 'Administrators will see that you ended it.',
                    confirmLabel: 'Cancel alert',
                  );
                  if (!ok || !context.mounted) return;
                  await runGuarded(context, ref.read(openAlertProvider.notifier).cancelActive);
                },
              ),
            if (!alert.status.isOpen)
              AppButton(
                label: 'Done',
                onPressed: () {
                  ref.read(openAlertProvider.notifier).dismissClosed();
                  context.go(Routes.home);
                },
              ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Take photo or video',
              variant: AppButtonVariant.secondary,
              onPressed: () => context.push(Routes.camera),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the chat; the badge counts administrator messages not yet read (D-072: in-app notice only).
class _MessagesButton extends ConsumerWidget {
  const _MessagesButton({required this.alertId});

  final String alertId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserIdProvider);
    final unread = me == null ? 0 : ref.watch(chatProvider(alertId)).unreadFor(me);
    return AppButton(
      label: unread > 0 ? 'Messages ($unread new)' : 'Messages',
      variant: AppButtonVariant.secondary,
      onPressed: () => context.push(Routes.alertChat),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.alert});

  final SosAlert alert;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, body) = switch (alert.status) {
      AlertStatus.active => (
        Icons.sos,
        const Color(0xFFC62828),
        'Alert sent',
        'Administrators have been notified. Stay where you are if it is safe.',
      ),
      AlertStatus.acknowledged => (
        Icons.support_agent,
        const Color(0xFFEF6C00),
        'Help is on the way',
        'An administrator has seen your alert.',
      ),
      AlertStatus.resolved => (
        Icons.check_circle,
        const Color(0xFF2E7D32),
        'Alert resolved',
        'An administrator marked this alert as resolved.',
      ),
      AlertStatus.cancelled => (
        Icons.cancel,
        Colors.grey,
        'Alert cancelled',
        'You ended this alert.',
      ),
    };
    return Column(
      children: [
        Icon(icon, size: 72, color: color),
        const SizedBox(height: AppSpacing.sm),
        Text(title, style: context.textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        Text(body, textAlign: TextAlign.center),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.alert});

  final SosAlert alert;

  @override
  Widget build(BuildContext context) {
    final s = alert.status;
    final cancelled = s == AlertStatus.cancelled;
    bool reached(AlertStatus step) =>
        !cancelled &&
        (s == step ||
            (step == AlertStatus.active) ||
            (step == AlertStatus.acknowledged && s == AlertStatus.resolved));
    Widget row(String label, bool done) => ListTile(
      dense: true,
      leading: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? const Color(0xFF2E7D32) : Colors.grey,
      ),
      title: Text(label),
    );
    return Card(
      child: Column(
        children: [
          row('Alert sent', !cancelled),
          row('Acknowledged by an administrator', reached(AlertStatus.acknowledged)),
          row('Resolved', reached(AlertStatus.resolved)),
        ],
      ),
    );
  }
}
