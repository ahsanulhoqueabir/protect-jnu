import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../../../sos/domain/sos_alert.dart';

/// Coloured status label (dashboard `StatusBadge`).
class AlertStatusChip extends StatelessWidget {
  const AlertStatusChip({super.key, required this.status});

  final AlertStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground) = switch (status) {
      AlertStatus.active => (colors.errorContainer, colors.onErrorContainer),
      AlertStatus.acknowledged => (colors.tertiaryContainer, colors.onTertiaryContainer),
      AlertStatus.resolved => (colors.primaryContainer, colors.onPrimaryContainer),
      AlertStatus.cancelled => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.smAll),
      child: Text(
        status.name.capitalized,
        style: context.textTheme.labelMedium?.copyWith(color: foreground),
      ),
    );
  }
}

/// Previous / next for 20-per-page admin lists.
class AdminPager extends StatelessWidget {
  const AdminPager({super.key, required this.page, required this.pageCount, required this.onPage});

  final int page;
  final int pageCount;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: page > 1 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Page $page of $pageCount', style: context.textTheme.bodySmall),
          IconButton(
            tooltip: 'Next page',
            onPressed: page < pageCount ? () => onPage(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

/// A titled card section used on the alert detail screen.
class AdminSection extends StatelessWidget {
  const AdminSection({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: context.textTheme.titleMedium)),
                ?trailing,
              ],
            ),
            const Gap(AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

/// Local date and time, e.g. for alert timelines.
String adminTime(DateTime time) {
  final local = time.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.formatted}, ${two(local.hour)}:${two(local.minute)}';
}

/// "12s ago", "5 min ago", "2 h ago".
String timeAgo(DateTime time, [DateTime? now]) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inSeconds < 60) return '${diff.inSeconds.clamp(0, 59)}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return adminTime(time);
}
