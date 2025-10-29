class Course {
  final String? id;
  final String courseCode;
  final String courseName;
  final String? teacherRef;
  final String? classRef;
  final String? facultyRef;
  final String? semester;
  final DateTime? createdAt;

  Course({
    this.id,
    required this.courseCode,
    required this.courseName,
    this.teacherRef,
    this.classRef,
    this.facultyRef,
    this.semester,
    this.createdAt,
  });

  Course copyWith({
    String? id,
    String? courseCode,
    String? courseName,
    String? teacherRef,
    String? classRef,
    String? facultyRef,
    String? semester,
    DateTime? createdAt,
  }) {
    return Course(
      id: id ?? this.id,
      courseCode: courseCode ?? this.courseCode,
      courseName: courseName ?? this.courseName,
      teacherRef: teacherRef ?? this.teacherRef,
      classRef: classRef ?? this.classRef,
      facultyRef: facultyRef ?? this.facultyRef,
      semester: semester ?? this.semester,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
