class Department {
  final String code;
  final String name;
  final String head;
  final String status;

  Department({
    required this.code,
    required this.name,
    required this.head,
    required this.status,
  });

  Department copyWith({
    String? code,
    String? name,
    String? head,
    String? status,
  }) {
    return Department(
      code: code ?? this.code,
      name: name ?? this.name,
      head: head ?? this.head,
      status: status ?? this.status,
    );
  }
}