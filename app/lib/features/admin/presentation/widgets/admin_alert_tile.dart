import 'package:flutter/material.dart';

import '../../../../core/utils/extensions.dart';
import '../../../sos/domain/sos_alert.dart';
import '../../domain/admin_alert.dart';
import 'admin_widgets.dart';

/// Alert card: student name + ID, time, status (D-062 card fields). Active alerts stand out.
class AdminAlertTile extends StatelessWidget {
  const AdminAlertTile({super.key, required this.alert, required this.onTap});

  final AdminAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = alert.status == AlertStatus.active;
    return Card(
      color: active ? context.colors.errorContainer.withValues(alpha: 0.35) : null,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          active ? Icons.sos_rounded : Icons.shield_outlined,
          color: active ? context.colors.error : context.colors.primary,
        ),
        title: Text(alert.student.fullName),
        subtitle: Text('${alert.student.studentId} · ${adminTime(alert.startedAt)}'),
        trailing: AlertStatusChip(status: alert.status),
      ),
    );
  }
}
