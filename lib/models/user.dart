import 'package:cloud_firestore/cloud_firestore.dart';
class AppUser {
  final String id;
  final String username;
  final String role;
  String password;
  final String facultyId;
  final String status; // active, inactive, or disabled
  final DateTime createdAt;
  final DateTime updatedAt;

  AppUser({
    required this.id,
    required this.username,
    required this.role,
    required this.password,
    required this.facultyId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  AppUser copyWith({
    String? id,
    String? username,
    String? role,
    String? password,
    String? facultyId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      role: role ?? this.role,
      password: password ?? this.password,
      facultyId: facultyId ?? this.facultyId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AppUser.fromFirestore(Map<String, dynamic> data, String docId) {
    return AppUser(
      id: docId,
      username: data['username'] ?? '',
      role: data['role'] ?? '',
      password: data['password'] ?? '',
      facultyId: data['faculty_id'] ?? '',
      status: data['status'] ?? 'active',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'role': role,
      'password': password,
      'faculty_id': facultyId,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}