import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/extensions.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/feedback/app_feedback.dart';
import '../admin_providers.dart';
import '../domain/admin_alert.dart';
import 'widgets/admin_widgets.dart';
import 'widgets/alert_live_map.dart';

/// Alert details (dashboard `/admin/alerts/[id]`): status + action, live map, student, emergency
/// contacts, timeline and the chat entry point.
class AdminAlertScreen extends ConsumerWidget {
  const AdminAlertScreen({super.key, required this.alertId});

  final String alertId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(alertDetailProvider(alertId));
    return Scaffold(
      appBar: AppBar(title: const Text('Alert')),
      body: AsyncValueView(
        value: detail,
        onRetry: () => ref.invalidate(alertDetailProvider(alertId)),
        data: (alert) => RefreshIndicator(
          onRefresh: () => ref.read(alertDetailProvider(alertId).notifier).reload(),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _StatusCard(alert: alert),
              AdminSection(
                title: 'Live location',
                child: _LiveLocation(alert: alert),
              ),
              AdminSection(
                title: 'Student',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.student.fullName, style: context.textTheme.titleSmall),
                    Text(alert.student.studentId),
                    if (alert.student.email != null) Text(alert.student.email!),
                    if (alert.student.phone != null)
                      _CopyLine(label: 'Phone', value: alert.student.phone!),
                  ],
                ),
              ),
              AdminSection(
                title: 'Emergency contacts',
                child: alert.contacts.isEmpty
                    ? const Text('No contacts saved.')
                    : Column(
                        children: [
                          for (final c in alert.contacts) _CopyLine(label: c.name, value: c.phone),
                        ],
                      ),
              ),
              AdminSection(
                title: 'Timeline',
                child: _Timeline(alert: alert),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.push(Routes.adminAlertChatFor(alert.id)),
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(alert.chatOpen ? 'Open chat' : 'View chat history'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.alert});

  final AdminAlertDetail alert;

  Future<void> _act(BuildContext context, WidgetRef ref, AlertAction action) async {
    try {
      await ref.read(alertDetailProvider(alert.id).notifier).transition(action);
      if (context.mounted) {
        showAppSnack(
          context,
          'Alert ${action == AlertAction.acknowledge ? 'acknowledged' : 'resolved'}.',
          type: SnackType.success,
        );
      }
    } on CodedApiException catch (e) {
      if (!context.mounted) return;
      final text = e.code == 'invalid_transition'
          ? 'Another admin already changed this alert. It is now ${e.details['current_status'] ?? 'updated'}.'
          : e.message;
      showAppSnack(context, text, type: SnackType.error);
    } on Object catch (e) {
      if (context.mounted) showAppSnack(context, userMessage(e), type: SnackType.error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = alert.nextAction;
    return AdminSection(
      title: 'Status',
      trailing: AlertStatusChip(status: alert.status),
      child: action == null
          ? Text('This alert is ${alert.status.name}; no further action.')
          : SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final ok = await showConfirmDialog(
                    context,
                    title: '${action.label}?',
                    message: action == AlertAction.acknowledge
                        ? 'The student will see that an administrator has seen the alert.'
                        : 'The alert closes, location sharing stops and the chat becomes read-only.',
                    confirmLabel: action.label,
                  );
                  if (ok && context.mounted) await _act(context, ref, action);
                },
                child: Text(action.label),
              ),
            ),
    );
  }
}

class _LiveLocation extends ConsumerWidget {
  const _LiveLocation({required this.alert});

  final AdminAlertDetail alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trail = ref.watch(alertTrailProvider(alert.id));
    final fallback = alert.firstLatitude != null && alert.firstLongitude != null
        ? LatLng(alert.firstLatitude!, alert.firstLongitude!)
        : null;
    return AsyncValueView(
      value: trail,
      onRetry: () => ref.invalidate(alertTrailProvider(alert.id)),
      data: (points) => AlertLiveMap(points: points, fallback: fallback),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.alert});

  final AdminAlertDetail alert;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, DateTime? at, [String? by]) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Text(
        at == null ? '$label: —' : '$label: ${adminTime(at)}${by == null ? '' : ' by $by'}',
        style: at == null
            ? context.textTheme.bodyMedium?.copyWith(color: context.colors.outline)
            : null,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row('Sent', alert.startedAt),
        row('Acknowledged', alert.acknowledgedAt, alert.acknowledgedByEmail),
        row('Resolved', alert.resolvedAt, alert.resolvedByEmail),
        if (alert.cancelledAt != null) row('Cancelled by the student', alert.cancelledAt),
      ],
    );
  }
}

/// A phone number with a copy button (no dialer package in the app).
class _CopyLine extends StatelessWidget {
  const _CopyLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('$label: $value')),
        IconButton(
          tooltip: 'Copy $label',
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) showAppSnack(context, 'Copied.');
          },
        ),
      ],
    );
  }
}
