class User {
  final String username;
  final String role;
  final String password;

  User({required this.username, required this.role, required this.password});

  User copyWith({String? username, String? role, String? password}) {
    return User(
      username: username ?? this.username,
      role: role ?? this.role,
      password: password ?? this.password,
    );
  }
}
