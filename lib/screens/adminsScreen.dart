import 'package:flutter/material.dart';
import '../components/cards/searchBar.dart';
import '../components/popup/add_admin_popup.dart';

class AdminsScreen extends StatefulWidget {
  const AdminsScreen({Key? key}) : super(key: key);

  @override
  State<AdminsScreen> createState() => _AdminsScreenState();
}

class _AdminsScreenState extends State<AdminsScreen> {
  int? selectedRow;
  List<Map<String, String>> admins = [
    {
      'adminId': 'SNU1234',
      'fullName': 'Cali',
      'faculty': 'ENG',
      'password': '*******',
    },
    {
      'adminId': 'SNU1234',
      'fullName': 'Cali',
      'faculty': 'ENG',
      'password': '*******',
    },
    {
      'adminId': 'SNU1234',
      'fullName': 'Cali',
      'faculty': 'ENG',
      'password': '*******',
    },
    {
      'adminId': 'SNU1234',
      'fullName': 'Cali',
      'faculty': 'ENG',
      'password': '*******',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(color: Colors.black, fontSize: 18);
    final headerStyle = const TextStyle(
      color: Colors.black,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    );
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Admins',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.logout, size: 28),
                onPressed: () {
                  // TODO: Add logout logic here
                },
                tooltip: 'Logout',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SearchAddBar(
                  hintText: 'Search Admin...',
                  buttonText: ' Add Admin',
                  onAddPressed: () async {
                    final result = await showDialog(
                      context: context,
                      builder: (context) => AddAdminPopup(
                        faculties: [
                          "Science",
                          "Arts",
                          "Commerce",
                          "Engineering",
                        ],
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        admins.add({
                          'adminId': result['adminId'] ?? '',
                          'fullName': result['fullName'] ?? '',
                          'faculty': result['faculty'] ?? '',
                          'password': result['password'] ?? '',
                        });
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Admin Added: " +
                                (result['adminId'] ?? '') +
                                " (" +
                                (result['fullName'] ?? '') +
                                ")",
                          ),
                        ),
                      );
                    }
                  },
                  onChanged: (value) {},
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 40),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'Edit',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 40),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 700),
                child: DataTable(
                  showCheckboxColumn: false,
                  columnSpacing: 18,
                  headingRowHeight: 80,
                  dataRowHeight: 50,
                  columns: [
                    DataColumn(label: Text('No', style: headerStyle)),
                    DataColumn(label: Text('Admin ID', style: headerStyle)),
                    DataColumn(label: Text('Full Name', style: headerStyle)),
                    DataColumn(label: Text('Faculty Name', style: headerStyle)),
                    DataColumn(label: Text('Password', style: headerStyle)),
                  ],
                  rows: List.generate(admins.length, (index) {
                    final admin = admins[index];
                    final bool isSelected = selectedRow == index;
                    final rowColor = isSelected
                        ? Colors.indigo.shade50
                        : Colors.transparent;
                    return DataRow(
                      selected: isSelected,
                      color: MaterialStateProperty.resolveWith<Color?>(
                        (states) => rowColor,
                      ),
                      onSelectChanged: (selected) {
                        setState(() {
                          selectedRow = selected == true ? index : null;
                        });
                      },
                      cells: [
                        DataCell(Text('${index + 1}', style: textStyle)),
                        DataCell(
                          Text(admin['adminId'] ?? '', style: textStyle),
                        ),
                        DataCell(
                          Text(admin['fullName'] ?? '', style: textStyle),
                        ),
                        DataCell(
                          Text(admin['faculty'] ?? '', style: textStyle),
                        ),
                        DataCell(
                          Text(admin['password'] ?? '', style: textStyle),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
