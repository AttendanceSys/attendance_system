class Student {
  final String id;
  final String fullName;
  final String username;
  final String gender;
  final String department; // display name
  final String className; // display name
  final String departmentId; // FK id (uuid) for DB
  final String classId; // FK id (uuid) for DB
  final String password;

  Student({
    required this.id,
    required this.fullName,
    required this.username,
    required this.gender,
    required this.department,
    required this.className,
    this.departmentId = '',
    this.classId = '',
    required this.password,
  });

  Student copyWith({
    String? id,
    String? fullName,
    String? username,
    String? gender,
    String? department,
    String? className,
    String? departmentId,
    String? classId,
    String? password,
  }) {
    return Student(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      gender: gender ?? this.gender,
      department: department ?? this.department,
      className: className ?? this.className,
      departmentId: departmentId ?? this.departmentId,
      classId: classId ?? this.classId,
      password: password ?? this.password,
    );
  }
}
