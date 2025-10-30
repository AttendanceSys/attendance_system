import 'package:flutter/material.dart';
import '../hooks/use_departments.dart';
import '../hooks/use_courses.dart';
import '../hooks/use_classes.dart';
import '../hooks/use_students.dart';

class DashboardStatsGrid extends StatefulWidget {
  final String? facultyId;

  const DashboardStatsGrid({super.key, this.facultyId});

  @override
  State<DashboardStatsGrid> createState() => _DashboardStatsGridState();
}

class _DashboardStatsGridState extends State<DashboardStatsGrid> {
  int departmentCount = 0;
  int courseCount = 0;
  int classCount = 0;
  int studentCount = 0;
  bool loading = true;

  final _departments = UseDepartments();
  final _courses = UseCourses();
  final _classes = UseClasses();
  final _students = UseStudents();

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final deps = await _departments.fetchDepartments(
        facultyId: widget.facultyId,
      );
      final courses = await _courses.fetchCourses(facultyId: widget.facultyId);
      final classes = await _classes.fetchClasses(facultyId: widget.facultyId);
      final students = await _students.fetchStudents(
        facultyId: widget.facultyId,
      );
      if (!mounted) return;
      setState(() {
        departmentCount = deps.length;
        courseCount = courses.length;
        classCount = classes.length;
        studentCount = students.length;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        departmentCount = 0;
        courseCount = 0;
        classCount = 0;
        studentCount = 0;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const int crossAxisCount = 2;
    const double crossAxisSpacing = 16.0;
    const double mainAxisSpacing = 16.0;

    final String depsValue = loading ? '...' : departmentCount.toString();
    final String coursesValue = loading ? '...' : courseCount.toString();
    final String classesValue = loading ? '...' : classCount.toString();
    final String studentsValue = loading ? '...' : studentCount.toString();

    return GridView.count(
      padding: const EdgeInsets.symmetric(vertical: 8),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      childAspectRatio: screenWidth < 500 ? 1.2 : 2.2,
      children: [
        _StatsCard(
          icon: Icons.account_tree_outlined,
          label: "Departments",
          value: depsValue,
          color: const Color(0xFFD23CA7),
        ),
        _StatsCard(
          icon: Icons.menu_book_outlined,
          label: "Courses",
          value: coursesValue,
          color: const Color(0xFFF7B345),
        ),
        _StatsCard(
          icon: Icons.show_chart_outlined,
          label: "Classes",
          value: classesValue,
          color: const Color(0xFF31B9C1),
        ),
        _StatsCard(
          icon: Icons.people_alt_outlined,
          label: "Students",
          value: studentsValue,
          color: const Color(0xFFB9EEB6),
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatsCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double labelFont = screenWidth < 500 ? 15 : 18;
    double numberFont = screenWidth < 500 ? 40 : 56;

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: labelFont,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: numberFont,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
