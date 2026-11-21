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
import 'widgets/admin_widgets.dart';

/// Alert history with a status filter, 20 per page (dashboard `/admin/history`).
class AdminHistoryScreen extends ConsumerStatefulWidget {
  const AdminHistoryScreen({super.key});

  static const filters = ['all', 'active', 'acknowledged', 'resolved', 'cancelled'];

  @override
  ConsumerState<AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends ConsumerState<AdminHistoryScreen> {
  var _status = 'all';
  var _page = 1;

  @override
  Widget build(BuildContext context) {
    final query = (status: _status, page: _page);
    final result = ref.watch(alertHistoryProvider(query));
    return Scaffold(
      appBar: AppBar(title: const Text('Alert history')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Row(
              children: [
                for (final f in AdminHistoryScreen.filters)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: ChoiceChip(
                      label: Text(f.capitalized),
                      selected: _status == f,
                      onSelected: (_) => setState(() {
                        _status = f;
                        _page = 1;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: result,
              onRetry: () => ref.invalidate(alertHistoryProvider(query)),
              data: (page) => page.items.isEmpty
                  ? const StatusView.empty(icon: Icons.history, title: 'No alerts')
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      children: [
                        for (final a in page.items)
                          AdminAlertTile(
                            alert: a,
                            onTap: () => context.push(Routes.adminAlertFor(a.id)),
                          ),
                        AdminPager(
                          page: page.page,
                          pageCount: page.pageCount,
                          onPage: (p) => setState(() => _page = p),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
