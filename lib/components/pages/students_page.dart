import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../popup/add_student_popup.dart';
import '../cards/searchBar.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({Key? key}) : super(key: key);

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final List<Student> _students = [
    Student(id: 'B3SC600', fullName: 'Cali', gender: 'Male', department: 'CS', className: 'B1SC CS', password: '*******'),
    Student(id: 'B3SC600', fullName: 'Cali', gender: 'Male', department: 'GEO', className: 'B2SC GEO', password: '*******'),
    Student(id: 'B3SC600', fullName: 'Cali', gender: 'Male', department: 'Math', className: 'B2SC math', password: '*******'),
  ];

  final List<String> _genders = ['Male', 'Female'];
  final List<String> _departments = ['CS', 'GEO', 'Math', 'BIO', 'CHEM'];
  final List<String> _classes = ['B1SC CS', 'B2SC GEO', 'B2SC math', 'B3SC BIO', 'B4SC CHEM'];

  String _searchText = '';
  int? _selectedIndex;

  List<Student> get _filteredStudents => _students
      .where((student) =>
          student.id.toLowerCase().contains(_searchText.toLowerCase()) ||
          student.fullName.toLowerCase().contains(_searchText.toLowerCase()) ||
          student.gender.toLowerCase().contains(_searchText.toLowerCase()) ||
          student.department.toLowerCase().contains(_searchText.toLowerCase()) ||
          student.className.toLowerCase().contains(_searchText.toLowerCase()))
      .toList();

  Future<void> _showAddStudentPopup() async {
    final result = await showDialog<Student>(
      context: context,
      builder: (context) => AddStudentPopup(
        genders: _genders,
        departments: _departments,
        classes: _classes,
      ),
    );
    if (result != null) {
      setState(() {
        _students.add(result);
        _selectedIndex = null;
      });
    }
  }

  Future<void> _showEditStudentPopup() async {
    if (_selectedIndex == null) return;
    final student = _filteredStudents[_selectedIndex!];
    final result = await showDialog<Student>(
      context: context,
      builder: (context) => AddStudentPopup(
        student: student,
        genders: _genders,
        departments: _departments,
        classes: _classes,
      ),
    );
    if (result != null) {
      int mainIndex = _students.indexOf(student);
      setState(() {
        _students[mainIndex] = result;
      });
    }
  }

  Future<void> _confirmDeleteStudent() async {
    if (_selectedIndex == null) return;
    final student = _filteredStudents[_selectedIndex!];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Student"),
        content: Text("Are you sure you want to delete '${student.fullName}'?"),
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
        _students.remove(student);
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
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            "Students",
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
                      hintText: "Search students...",
                      buttonText: "Add Students",
                      onAddPressed: _showAddStudentPopup,
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
                              padding: const EdgeInsets.symmetric(
                                vertical: 0,
                                horizontal: 0,
                              ),
                            ),
                            onPressed: _selectedIndex == null
                                ? null
                                : _showEditStudentPopup,
                            child: const Text(
                              "Edit",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
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
                              padding: const EdgeInsets.symmetric(
                                vertical: 0,
                                horizontal: 0,
                              ),
                            ),
                            onPressed: _selectedIndex == null
                                ? null
                                : _confirmDeleteStudent,
                            child: const Text(
                              "Delete",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
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

  // Desktop/tablet: clean, wide fixed column design (like Departments screenshot)
  Widget _buildDesktopTable() {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(50),   // No
        1: FixedColumnWidth(120),  // ID
        2: FixedColumnWidth(160),  // Name
        3: FixedColumnWidth(100),  // Gender
        4: FixedColumnWidth(120),  // Department
        5: FixedColumnWidth(120),  // Class
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("No"),
            _tableHeaderCell("ID"),
            _tableHeaderCell("Student name"),
            _tableHeaderCell("Gender"),
            _tableHeaderCell("Department"),
            _tableHeaderCell("Class"),
          ],
        ),
        for (int index = 0; index < _filteredStudents.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index ? Colors.blue.shade50 : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredStudents[index].id, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredStudents[index].fullName, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredStudents[index].gender, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredStudents[index].department, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredStudents[index].className, onTap: () => _handleRowTap(index)),
            ],
          ),
      ],
    );
  }

  // Mobile: keep existing scrollable table
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
            _tableHeaderCell("ID"),
            _tableHeaderCell("Student name"),
            _tableHeaderCell("Gender"),
            _tableHeaderCell("Department"),
            _tableHeaderCell("Class"),
          ],
        ),
        for (int index = 0; index < _filteredStudents.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index ? Colors.blue.shade50 : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredStudents[index].id, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredStudents[index].fullName, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredStudents[index].gender, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredStudents[index].department, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredStudents[index].className, onTap: () => _handleRowTap(index)),
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