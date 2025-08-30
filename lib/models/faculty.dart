class Faculty {
  final String code;
  final String name;
  final DateTime createdAt;

  Faculty({required this.code, required this.name, required this.createdAt});

  Faculty copyWith({String? code, String? name, DateTime? createdAt}) {
    return Faculty(
      code: code ?? this.code,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
