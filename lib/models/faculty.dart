class Faculty {
  final String code;
  final String name;
  final DateTime createdAt;
  final DateTime establishmentDate;

  Faculty({
    required this.code,
    required this.name,
    required this.createdAt,
    required this.establishmentDate,
  });

  Faculty copyWith({
    String? code,
    String? name,
    DateTime? createdAt,
    DateTime? establishmentDate,
  }) {
    return Faculty(
      code: code ?? this.code,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      establishmentDate: establishmentDate ?? this.establishmentDate,
    );
  }
}
