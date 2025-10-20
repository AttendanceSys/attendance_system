class Course {
  final String code;
  final String name;
  final String teacher;
  final String className;
  final int semester;

  final String id;

  Course({
    this.id = '',
    required this.code,
    required this.name,
    required this.teacher,
    required this.className,
    required this.semester,
  });

  factory Course.fromMap(Map<String, dynamic> map) {
    int sem = 1;
    try {
      final s = map['semister'] ?? map['semester'];
      if (s is int) sem = s;
      if (s is String) sem = int.tryParse(s) ?? 1;
    } catch (_) {
      sem = 1;
    }
    // Extract teacher display (may be nested object, list, or id string)
    String teacherDisplay = '';
    try {
      final t = map['teacher_assigned'] ?? map['teacher'];
      if (t is Map) {
        teacherDisplay =
            (t['teacher_name'] ?? t['username'] ?? t['name'] ?? '')
                ?.toString() ??
            '';
      } else if (t is List && t.isNotEmpty) {
        final first = t.first;
        if (first is Map)
          teacherDisplay =
              (first['teacher_name'] ??
                      first['username'] ??
                      first['name'] ??
                      '')
                  ?.toString() ??
              '';
        else if (first != null)
          teacherDisplay = first.toString();
      } else if (t != null) {
        teacherDisplay = t.toString();
      }
    } catch (_) {
      teacherDisplay = '';
    }

    String classDisplay = '';
    try {
      final c = map['class'] ?? map['class_name'];
      if (c is Map) {
        classDisplay = (c['class_name'] ?? c['name'] ?? '')?.toString() ?? '';
      } else if (c is List && c.isNotEmpty) {
        final first = c.first;
        if (first is Map)
          classDisplay =
              (first['class_name'] ?? first['name'] ?? '')?.toString() ?? '';
        else if (first != null)
          classDisplay = first.toString();
      } else if (c != null) {
        classDisplay = c.toString();
      }
    } catch (_) {
      classDisplay = '';
    }

    return Course(
      id: (map['id'] ?? '')?.toString() ?? '',
      code: (map['course_code'] ?? map['code'] ?? '')?.toString() ?? '',
      name: (map['course_name'] ?? map['name'] ?? '')?.toString() ?? '',
      teacher: teacherDisplay,
      className: classDisplay,
      semester: sem,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (code.isNotEmpty) 'course_code': code,
      if (name.isNotEmpty) 'course_name': name,
      if (teacher.isNotEmpty) 'teacher_assigned': teacher,
      if (className.isNotEmpty) 'class': className,
      'semister': semester.toString(),
    };
  }
}
