import 'package:flutter/foundation.dart';

import '../../../core/storage/token_store.dart';

/// Client-safe profile returned by `/auth/login` and `/auth/me` (docs/api-contract.md).
@immutable
class User {
  const User({
    required this.id,
    required this.fullName,
    required this.studentId,
    required this.email,
    this.phone,
    this.role = 'user',
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'].toString(),
    fullName: json['full_name'] as String,
    studentId: json['student_id'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String?,
    role: json['role'] as String? ?? 'user',
  );

  final String id;
  final String fullName;
  final String studentId;
  final String email;
  final String? phone;
  final String role;

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'student_id': studentId,
    'email': email,
    'phone': phone,
    'role': role,
  };

  @override
  bool operator ==(Object other) =>
      other is User &&
      other.id == id &&
      other.fullName == fullName &&
      other.studentId == studentId &&
      other.email == email &&
      other.phone == phone &&
      other.role == role;

  @override
  int get hashCode => Object.hash(id, fullName, studentId, email, phone, role);
}

/// Result of a successful sign in.
typedef AuthSession = ({AuthTokens tokens, User user});
