class Student {
  final String id;
  final String fullName;
  final String gender;
  final String department;
  final String className;
  final String password;

  Student({
    required this.id,
    required this.fullName,
    required this.gender,
    required this.department,
    required this.className,
    required this.password,
  });

  Student copyWith({String? id, String? fullName, String? gender, String? department, String? className, String? password}) {
    return Student(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      department: department ?? this.department,
      className: className ?? this.className,
      password: password ?? this.password,
    );
  }
}