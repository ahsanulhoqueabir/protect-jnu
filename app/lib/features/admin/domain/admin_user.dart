import 'package:flutter/foundation.dart';

/// One row of `GET /api/admin/users` (read-only list, api-contract 6).
@immutable
class AdminUser {
  const AdminUser({
    required this.id,
    required this.fullName,
    required this.studentId,
    required this.email,
    required this.role,
    required this.verified,
    required this.createdAt,
    this.phone,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: json['id'] as String,
    fullName: json['full_name'] as String,
    studentId: json['student_id'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String?,
    role: json['role'] as String? ?? 'user',
    verified: json['verified'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final String id;
  final String fullName;
  final String studentId;
  final String email;
  final String? phone;
  final String role;
  final bool verified;
  final DateTime createdAt;

  bool get isAdmin => role == 'admin';
}
