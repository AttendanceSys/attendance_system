import 'package:flutter/material.dart';
import '../../models/course.dart';
import '../popup/add_course_popup.dart';
import '../cards/searchBar.dart';

class CoursesPage extends StatefulWidget {
  const CoursesPage({Key? key}) : super(key: key);

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  final List<Course> _courses = [
    Course(code: 'C101', name: 'cloud', teacher: 'maxamed', className: 'B3SC CS A', semester: 1),
    Course(code: 'C102', name: 'Arabic', teacher: 'yonis', className: 'B2SC Math', semester: 1),
    Course(code: 'C103', name: 'C#', teacher: 'ali', className: 'B1SC GEO', semester: 1),
    Course(code: 'C104', name: 'Python', teacher: 'madeey', className: 'B4SC CS B', semester: 1),
  ];

  final List<String> teachers = ['maxamed', 'yonis', 'ali', 'madeey'];
  final List<String> classes = ['B3SC CS A', 'B2SC Math', 'B1SC GEO', 'B4SC CS B'];

  String _searchText = '';
  int? _selectedIndex;

  List<Course> get _filteredCourses => _courses.where((course) =>
    course.code.toLowerCase().contains(_searchText.toLowerCase()) ||
    course.name.toLowerCase().contains(_searchText.toLowerCase()) ||
    course.teacher.toLowerCase().contains(_searchText.toLowerCase()) ||
    course.className.toLowerCase().contains(_searchText.toLowerCase()) ||
    course.semester.toString().contains(_searchText)
  ).toList();

  Future<void> _showAddCoursePopup() async {
    final result = await showDialog<Course>(
      context: context,
      builder: (context) => AddCoursePopup(
        teachers: teachers,
        classes: classes,
      ),
    );
    if (result != null) {
      setState(() {
        _courses.add(result);
        _selectedIndex = null;
      });
    }
  }

  Future<void> _showEditCoursePopup() async {
    if (_selectedIndex == null) return;
    final course = _filteredCourses[_selectedIndex!];
    final result = await showDialog<Course>(
      context: context,
      builder: (context) => AddCoursePopup(
        course: course,
        teachers: teachers,
        classes: classes,
      ),
    );
    if (result != null) {
      int mainIndex = _courses.indexOf(course);
      setState(() {
        _courses[mainIndex] = result;
      });
    }
  }

  Future<void> _confirmDeleteCourse() async {
    if (_selectedIndex == null) return;
    final course = _filteredCourses[_selectedIndex!];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Course"),
        content: Text("Are you sure you want to delete '${course.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        _courses.remove(course);
        _selectedIndex = null;
      });
    }
  }

  void _handleRowTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 800;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            "Courses",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SearchAddBar(
                      hintText: "Search Subjects...",
                      buttonText: "Add Subject",
                      onAddPressed: _showAddCoursePopup,
                      onChanged: (value) {
                        setState(() {
                          _searchText = value;
                          _selectedIndex = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 36,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                            ),
                            onPressed: _selectedIndex == null ? null : _showEditCoursePopup,
                            child: const Text("Edit", style: TextStyle(fontSize: 15, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          height: 36,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                            ),
                            onPressed: _selectedIndex == null ? null : _confirmDeleteCourse,
                            child: const Text("Delete", style: TextStyle(fontSize: 15, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.transparent,
              child: isDesktop
                  ? _buildDesktopTable()
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildMobileTable(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(64),   // No
        1: FixedColumnWidth(100),  // sub Code
        2: FixedColumnWidth(140),  // sub name
        3: FixedColumnWidth(140),  // Teach Assi
        4: FixedColumnWidth(120),  // Class
        5: FixedColumnWidth(90),   // Semester
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("No"),
            _tableHeaderCell("sub Code"),
            _tableHeaderCell("sub name"),
            _tableHeaderCell("Teach Assi"),
            _tableHeaderCell("Class"),
            _tableHeaderCell("Semester"),
          ],
        ),
        for (int index = 0; index < _filteredCourses.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index ? Colors.blue.shade50 : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredCourses[index].code, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredCourses[index].name, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredCourses[index].teacher, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredCourses[index].className, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredCourses[index].semester.toString(), onTap: () => _handleRowTap(index)),
            ],
          ),
      ],
    );
  }

  Widget _buildMobileTable() {
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("No"),
            _tableHeaderCell("sub Code"),
            _tableHeaderCell("sub name"),
            _tableHeaderCell("Teach Assi"),
            _tableHeaderCell("Class"),
            _tableHeaderCell("Semester"),
          ],
        ),
        for (int index = 0; index < _filteredCourses.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index ? Colors.blue.shade50 : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredCourses[index].code, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredCourses[index].name, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredCourses[index].teacher, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredCourses[index].className, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredCourses[index].semester.toString(), onTap: () => _handleRowTap(index)),
            ],
          ),
      ],
    );
  }

  Widget _tableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: TextAlign.left,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _tableBodyCell(String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}