class Student {
  final String? id;
  final String fullname;
  final String username;
  final String password;
  final String? classRef;
  final String? departmentRef;
  final String? facultyRef;
  final String gender;
  final DateTime? createdAt;

  Student({
    this.id,
    required this.fullname,
    required this.username,
    required this.password,
    this.classRef,
    this.departmentRef,
    this.facultyRef,
    required this.gender,
    this.createdAt,
  });

  Student copyWith({
    String? id,
    String? fullname,
    String? username,
    String? password,
    String? classRef,
    String? departmentRef,
    String? facultyRef,
    String? gender,
    DateTime? createdAt,
  }) {
    return Student(
      id: id ?? this.id,
      fullname: fullname ?? this.fullname,
      username: username ?? this.username,
      password: password ?? this.password,
      classRef: classRef ?? this.classRef,
      departmentRef: departmentRef ?? this.departmentRef,
      facultyRef: facultyRef ?? this.facultyRef,
      gender: gender ?? this.gender,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
