class Attendance {
  final String id;
  final String name;
  final String department;
  final String className;
  final bool status;

  Attendance({
    required this.id,
    required this.name,
    required this.department,
    required this.className,
    required this.status,
  });

  Attendance copyWith({
    String? id,
    String? name,
    String? department,
    String? className,
    bool? status,
  }) {
    return Attendance(
      id: id ?? this.id,
      name: name ?? this.name,
      department: department ?? this.department,
      className: className ?? this.className,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'department': department,
      'className': className,
      'status': status,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'],
      name: map['name'],
      department: map['department'],
      className: map['className'],
      status: map['status'],
    );
  }
}
