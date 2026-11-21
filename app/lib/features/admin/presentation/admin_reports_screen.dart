import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/feedback/app_feedback.dart';
import '../admin_providers.dart';
import '../data/admin_repository.dart';
import '../domain/support_report.dart';

/// Shares the CSV file. A provider so tests can replace the platform share sheet.
final csvSharerProvider = Provider<Future<void> Function(String fileName, String csv)>(
  (_) => (fileName, csv) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csv);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: fileName,
      ),
    );
  },
);

/// Support reports (PRD 5.6, D-076, D-080): year filter, monthly bar chart, table, CSV share.
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  late int _year = currentReportYear();
  var _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    await runGuarded(context, () async {
      final csv = await ref.read(adminRepositoryProvider).reportCsv(_year);
      await ref.read(csvSharerProvider)('support-report-$_year.csv', csv);
    });
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final current = currentReportYear();
    final report = ref.watch(supportReportProvider(_year));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Share CSV',
            onPressed: _exporting ? null : _export,
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              Text('Year', style: context.textTheme.titleMedium),
              const Gap(AppSpacing.sm),
              DropdownButton<int>(
                value: _year,
                items: [
                  for (var y = current; y >= current - 5; y--)
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: (y) => setState(() => _year = y ?? _year),
              ),
            ],
          ),
          const Gap(AppSpacing.sm),
          AsyncValueView(
            value: report,
            onRetry: () => ref.invalidate(supportReportProvider(_year)),
            data: (r) => _ReportBody(report: r),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final SupportReport report;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxY = report.months.fold<int>(
      1,
      (m, r) => [m, r.alertsHandled, r.studentsSupported].reduce((a, b) => a > b ? a : b),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _Stat(label: 'Alerts handled', value: report.totalAlerts),
            ),
            const Gap(AppSpacing.xs),
            Expanded(
              child: _Stat(
                label: 'Students supported (monthly sum)',
                value: report.totalStudentMonths,
              ),
            ),
          ],
        ),
        const Gap(AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xxs,
          children: [
            _Legend(color: colors.primary, label: 'Alerts handled'),
            _Legend(color: colors.tertiary, label: 'Students supported'),
          ],
        ),
        const Gap(AppSpacing.xs),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: (maxY + 1).toDouble(),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(drawVerticalLine: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: maxY > 10 ? (maxY / 5).ceilToDouble() : 1,
                    getTitlesWidget: (v, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text('${v.toInt()}', style: context.textTheme.labelSmall),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        monthShortNames[v.toInt().clamp(0, 11)].substring(0, 1),
                        style: context.textTheme.labelSmall,
                      ),
                    ),
                  ),
                ),
              ),
              barGroups: [
                for (final m in report.months)
                  BarChartGroupData(
                    x: m.month - 1,
                    barRods: [
                      BarChartRodData(
                        toY: m.alertsHandled.toDouble(),
                        color: colors.primary,
                        width: 6,
                      ),
                      BarChartRodData(
                        toY: m.studentsSupported.toDouble(),
                        color: colors.tertiary,
                        width: 6,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const Gap(AppSpacing.md),
        Table(
          columnWidths: const {0: FlexColumnWidth(2)},
          children: [
            TableRow(
              children: [
                for (final h in ['Month', 'Alerts', 'Students'])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                    child: Text(h, style: context.textTheme.labelLarge),
                  ),
              ],
            ),
            for (final m in report.months)
              TableRow(
                children: [
                  Text('${monthShortNames[m.month - 1]} ${m.year}'),
                  Text('${m.alertsHandled}'),
                  Text('${m.studentsSupported}'),
                ],
              ),
          ],
        ),
        const Gap(AppSpacing.sm),
        Text(
          'A student is counted once per month in which an admin acknowledged or resolved their '
          'alert (Asia/Dhaka time). Cancelled and unhandled alerts are not counted.',
          style: context.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: context.textTheme.headlineSmall),
            Text(label, style: context.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: AppSpacing.xxs),
        Text(label, style: context.textTheme.labelSmall),
      ],
    );
  }
}
