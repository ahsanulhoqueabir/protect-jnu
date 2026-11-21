import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/feedback/status_view.dart';
import '../admin_providers.dart';
import 'widgets/admin_widgets.dart';

/// Conversations with the last message and unread counts, newest first, live (PRD 5.4).
class AdminConversationsScreen extends ConsumerWidget {
  const AdminConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Conversations')),
      body: AsyncValueView(
        value: conversations,
        onRetry: () => ref.invalidate(conversationsProvider),
        data: (items) => items.isEmpty
            ? const StatusView.empty(
                icon: Icons.forum_outlined,
                title: 'No conversations yet',
                message: 'Chats start from an alert.',
              )
            : RefreshIndicator(
                onRefresh: () => ref.read(conversationsProvider.notifier).reload(),
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = items[i];
                    return ListTile(
                      onTap: () => context.push(Routes.adminAlertChatFor(c.alertId)),
                      title: Text('${c.student.fullName} · ${c.student.studentId}'),
                      subtitle: Text(c.lastBody, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            timeAgo(c.lastSentAt),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 4),
                          if (c.unreadCount > 0)
                            Badge(label: Text('${c.unreadCount}'))
                          else if (c.status != null)
                            AlertStatusChip(status: c.status!),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
