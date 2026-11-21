import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/feedback/status_view.dart';
import '../admin_providers.dart';
import 'widgets/admin_alert_tile.dart';

/// Admin tab: live open alerts (dashboard "Live") plus entry points to the other admin pages.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(liveAlertsProvider);
    final unread = ref.watch(
      conversationsProvider.select(
        (c) => c.value?.fold<int>(0, (sum, conv) => sum + conv.unreadCount) ?? 0,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(liveAlertsProvider.notifier).reload(),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            GridView.count(
              crossAxisCount: context.isWide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.xs,
              crossAxisSpacing: AppSpacing.xs,
              childAspectRatio: 2.6,
              children: [
                _AdminLink(
                  icon: Icons.forum_outlined,
                  label: 'Conversations',
                  badge: unread,
                  onTap: () => context.push(Routes.adminConversations),
                ),
                _AdminLink(
                  icon: Icons.history,
                  label: 'History',
                  onTap: () => context.push(Routes.adminHistory),
                ),
                _AdminLink(
                  icon: Icons.group_outlined,
                  label: 'Users',
                  onTap: () => context.push(Routes.adminUsers),
                ),
                _AdminLink(
                  icon: Icons.bar_chart_rounded,
                  label: 'Reports',
                  onTap: () => context.push(Routes.adminReports),
                ),
              ],
            ),
            const Gap(AppSpacing.lg),
            Text('Live alerts', style: context.textTheme.titleLarge),
            const Gap(AppSpacing.xs),
            AsyncValueView(
              value: alerts,
              onRetry: () => ref.read(liveAlertsProvider.notifier).reload(),
              data: (items) => items.isEmpty
                  ? const SizedBox(
                      height: 280,
                      child: StatusView.empty(
                        icon: Icons.verified_user_outlined,
                        title: 'No open alerts',
                        message: 'New SOS alerts appear here instantly.',
                      ),
                    )
                  : Column(
                      children: [
                        for (final alert in items)
                          AdminAlertTile(
                            alert: alert,
                            onTap: () => context.push(Routes.adminAlertFor(alert.id)),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminLink extends StatelessWidget {
  const _AdminLink({required this.icon, required this.label, required this.onTap, this.badge = 0});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge'),
                child: Icon(icon, color: context.colors.primary),
              ),
              const Gap(AppSpacing.sm),
              Expanded(child: Text(label, style: context.textTheme.titleSmall)),
            ],
          ),
        ),
      ),
    );
  }
}
