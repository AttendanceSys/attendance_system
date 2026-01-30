import 'package:cloud_firestore/cloud_firestore.dart';

class Teacher {
  final String id; // Auto-generated document ID
  final String teacherName;
  final String username; // Reference to user_handling
  final String password;
  final String facultyId; // Reference to Faculties collection
  final DateTime createdAt;

  Teacher({
    required this.id,
    required this.teacherName,
    required this.username,
    required this.password,
    required this.facultyId,
    required this.createdAt,
  });

  Teacher copyWith({
    String? id,
    String? teacherName,
    String? username,
    String? password,
    String? facultyId,
    DateTime? createdAt,
  }) {
    return Teacher(
      id: id ?? this.id,
      teacherName: teacherName ?? this.teacherName,
      username: username ?? this.username,
      password: password ?? this.password,
      facultyId: facultyId ?? this.facultyId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Teacher.fromFirestore(Map<String, dynamic> data, String docId) {
    return Teacher(
      id: docId,
      teacherName: data['teacher_name'] ?? '',
      username: data['username'] ?? '',
      password: data['password'] ?? '',
      facultyId: (data['faculty_id'] as DocumentReference?)?.id ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'teacher_name': teacherName,
      'username': username,
      'password': password,
      'faculty_id': facultyId,
      'created_at': createdAt,
    };
  }
}
