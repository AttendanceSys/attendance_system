class Course {
  final String code;
  final String name;
  final String teacher;
  final String className;
  final int semester;
  final String department;

  Course({
    required this.code,
    required this.name,
    this.teacher = '',
    required this.className,
    required this.semester,
    this.department = '',
  });
}
