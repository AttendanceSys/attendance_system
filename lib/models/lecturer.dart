class Lecturer {
  final String id;
  final String name;
  final String password;

  Lecturer({required this.id, required this.name, required this.password});

  Lecturer copyWith({String? id, String? name, String? password}) {
    return Lecturer(
      id: id ?? this.id,
      name: name ?? this.name,
      password: password ?? this.password,
    );
  }
}
