class Admin {
  final String id;
  final String fullName;
  final String facultyId; // Reference to Faculties collection
  final String password;
  final String username;
  final DateTime createdAt;

  Admin({
    required this.id,
    required this.fullName,
    required this.facultyId,
    required this.password,
    required this.username,
    required this.createdAt,
  });

  Admin copyWith({
    String? id,
    String? fullName,
    String? facultyId,
    String? password,
    String? username,
    DateTime? createdAt,
  }) {
    return Admin(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      facultyId: facultyId ?? this.facultyId,
      password: password ?? this.password,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}