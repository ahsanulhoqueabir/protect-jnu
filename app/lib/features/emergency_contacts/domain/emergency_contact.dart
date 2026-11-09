import 'package:flutter/foundation.dart';

/// A student's emergency contact (table `emergency_contacts`: name + phone only, D-057).
@immutable
class EmergencyContact {
  const EmergencyContact({required this.id, required this.name, required this.phone});

  factory EmergencyContact.fromJson(Map<String, dynamic> json) => EmergencyContact(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
  );

  final String id;
  final String name;
  final String phone;

  /// PRD 5.1 / DB trigger: a student keeps between [minRequired] and [max] contacts.
  static const minRequired = 2;
  static const max = 3;

  @override
  bool operator ==(Object other) =>
      other is EmergencyContact && other.id == id && other.name == name && other.phone == phone;

  @override
  int get hashCode => Object.hash(id, name, phone);
}
