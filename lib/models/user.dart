class AppUser {
  final String username;
  final String role;
  String password;

  AppUser({
    required this.username,
    required this.role,
    required this.password,
  });

  AppUser copyWith({String? username, String? role, String? password}) {
    return AppUser(
      username: username ?? this.username,
      role: role ?? this.role,
      password: password ?? this.password,
    );
  }
}