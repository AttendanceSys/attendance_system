class Admin {
  final String id;
  final String fullName;
  final String facultyName;
  final String password;

  Admin({
    required this.id,
    required this.fullName,
    required this.facultyName,
    required this.password,
  });

  Admin copyWith({String? id, String? fullName, String? facultyName, String? password}) {
    return Admin(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      facultyName: facultyName ?? this.facultyName,
      password: password ?? this.password,
    );
  }
}