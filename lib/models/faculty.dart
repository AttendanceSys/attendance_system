class Faculty {
  final String code;
  final String name;
  final DateTime establishmentDate;
  final DateTime createdAt;

  Faculty({
    required this.code,
    required this.name,
    required this.establishmentDate,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'faculty_code': code,
        'faculty_name': name,
        'establishment_date': establishmentDate.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}
