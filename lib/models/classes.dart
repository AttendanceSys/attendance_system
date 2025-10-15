class SchoolClass {
  final String name;
  final String department;
  final String section;
  bool isActive;

  SchoolClass({
    required this.name,
    required this.department,
    required this.section,
    this.isActive = true,
  });
}