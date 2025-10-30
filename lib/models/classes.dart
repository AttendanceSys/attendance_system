class SchoolClass {
  final String id;
  final String name;
  final String department; // department id (uuid) or code depending on schema
  final String section;
  final String facultyId;
  bool isActive;

  SchoolClass({
    this.id = '',
    required this.name,
    required this.department,
    this.section = '',
    this.facultyId = '',
    this.isActive = true,
  });
}
