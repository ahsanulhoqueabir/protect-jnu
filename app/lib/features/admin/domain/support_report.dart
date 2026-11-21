import 'package:flutter/foundation.dart';

/// One month of `GET /api/admin/reports` (D-076: Asia/Dhaka months, period = first admin action).
@immutable
class ReportMonth {
  const ReportMonth({
    required this.year,
    required this.month,
    required this.alertsHandled,
    required this.studentsSupported,
  });

  factory ReportMonth.fromJson(Map<String, dynamic> json) => ReportMonth(
    year: (json['year'] as num).toInt(),
    month: (json['month'] as num).toInt(),
    alertsHandled: (json['alerts_handled'] as num).toInt(),
    studentsSupported: (json['students_supported'] as num).toInt(),
  );

  final int year;
  final int month;
  final int alertsHandled;
  final int studentsSupported;
}

@immutable
class SupportReport {
  const SupportReport({required this.year, required this.months});

  final int year;
  final List<ReportMonth> months;

  int get totalAlerts => months.fold(0, (sum, m) => sum + m.alertsHandled);

  /// Sum of the monthly figures. A student supported in two months counts in both (D-076), so this
  /// is "student-months", not distinct students for the year.
  int get totalStudentMonths => months.fold(0, (sum, m) => sum + m.studentsSupported);
}

const monthShortNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];

/// The report year in Asia/Dhaka (UTC+6, no DST), same default as the server.
int currentReportYear([DateTime? now]) =>
    (now ?? DateTime.now()).toUtc().add(const Duration(hours: 6)).year;
