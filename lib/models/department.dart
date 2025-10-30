class Department {
  final String id;
  final String code;
  final String name;
  final String head;
  final String status;
  final String facultyId;

  Department({
    this.id = '',
    required this.code,
    required this.name,
    required this.head,
    required this.status,
    this.facultyId = '',
  });

  Department copyWith({
    String? id,
    String? code,
    String? name,
    String? head,
    String? status,
    String? facultyId,
  }) {
    return Department(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      head: head ?? this.head,
      status: status ?? this.status,
      facultyId: facultyId ?? this.facultyId,
    );
  }
}
