class SchoolClass {
  final String? id;
  final String className;
  final String departmentRef; // department document id or ref id
  final String? facultyRef; // optional faculty id
  final String section; // A,B,C,D or NONE
  final bool status; // true = active
  final DateTime? createdAt;

  SchoolClass({
    this.id,
    required this.className,
    required this.departmentRef,
    this.facultyRef,
    required this.section,
    this.status = true,
    this.createdAt,
  });

  SchoolClass copyWith({
    String? id,
    String? className,
    String? departmentRef,
    String? facultyRef,
    String? section,
    bool? status,
    DateTime? createdAt,
  }) {
    return SchoolClass(
      id: id ?? this.id,
      className: className ?? this.className,
      departmentRef: departmentRef ?? this.departmentRef,
      facultyRef: facultyRef ?? this.facultyRef,
      section: section ?? this.section,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
