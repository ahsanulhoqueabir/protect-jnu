import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/feedback/status_view.dart';
import '../admin_providers.dart';
import '../domain/admin_user.dart';
import 'widgets/admin_widgets.dart';

/// Read-only users list, 20 per page (dashboard `/admin/users`). Roles are changed only by the
/// project team through SQL (PRD 5.1), never from the app.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  var _page = 1;

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(adminUsersProvider(_page));
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: AsyncValueView(
        value: result,
        onRetry: () => ref.invalidate(adminUsersProvider(_page)),
        data: (page) => page.items.isEmpty
            ? const StatusView.empty(icon: Icons.group_outlined, title: 'No users')
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  for (final u in page.items) _UserTile(user: u),
                  AdminPager(
                    page: page.page,
                    pageCount: page.pageCount,
                    onPage: (p) => setState(() => _page = p),
                  ),
                ],
              ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(user.fullName.initials)),
        title: Text(user.fullName),
        subtitle: Text(
          [
            user.studentId,
            user.email + (user.verified ? '' : ' (unverified)'),
            if (user.phone != null) user.phone!,
            'Joined ${adminTime(user.createdAt)}',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: user.isAdmin
            ? Chip(label: const Text('Admin'), backgroundColor: context.colors.secondaryContainer)
            : null,
      ),
    );
  }
}
