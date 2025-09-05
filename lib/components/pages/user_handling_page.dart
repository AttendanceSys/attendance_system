import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../popup/edit_user_popup.dart';
import '../cards/searchBar.dart';

class UserHandlingPage extends StatefulWidget {
  const UserHandlingPage({Key? key}) : super(key: key);

  @override
  State<UserHandlingPage> createState() => _UserHandlingPageState();
}

class _UserHandlingPageState extends State<UserHandlingPage> {
  final List<User> _users = [
    User(username: 'SNU1234', role: 'F admin', password: '*******'),
    User(username: 'MWE299', role: 'teacher', password: '*******'),
    User(username: 'SNU1234', role: 'F admin', password: '*******'),
    User(username: 'SNU1234', role: 'F admin', password: '*******'),
  ];

  String _searchText = '';

  List<User> get _filteredUsers => _users
      .where(
        (user) =>
            user.username.toLowerCase().contains(_searchText.toLowerCase()) ||
            user.role.toLowerCase().contains(_searchText.toLowerCase()),
      )
      .toList();

  Future<void> _showEditUserPopup(int index) async {
    final user = _filteredUsers[index];
    final result = await showDialog<User>(
      context: context,
      builder: (context) => EditUserPopup(user: user),
    );
    if (result != null) {
      int mainIndex = _users.indexOf(user);
      setState(() {
        _users[mainIndex] = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            "User Handling",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          SearchAddBar(
            hintText: "Search users...",
            buttonText: "",
            onAddPressed: () {}, // No add button for users
            onChanged: (value) => setState(() => _searchText = value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.transparent,
              child: isMobile
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 24,
                        headingRowHeight: 48,
                        dataRowHeight: 44,
                        columns: const [
                          DataColumn(
                            label: Text(
                              "NO",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Username",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Role",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Password",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(label: Text("")),
                        ],
                        rows: List.generate(_filteredUsers.length, (index) {
                          final user = _filteredUsers[index];
                          return DataRow(
                            cells: [
                              DataCell(Text('${index + 1}')),
                              DataCell(Text(user.username)),
                              DataCell(Text(user.role)),
                              DataCell(Text(user.password)),
                              DataCell(
                                Row(
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        minimumSize: const Size(32, 28),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _showEditUserPopup(index),
                                      child: const Text(
                                        "Edit",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columnSpacing: 24,
                        headingRowHeight: 48,
                        dataRowHeight: 44,
                        columns: const [
                          DataColumn(
                            label: Text(
                              "NO",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Username",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Role",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Password",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(label: Text("")),
                        ],
                        rows: List.generate(_filteredUsers.length, (index) {
                          final user = _filteredUsers[index];
                          return DataRow(
                            cells: [
                              DataCell(Text('${index + 1}')),
                              DataCell(Text(user.username)),
                              DataCell(Text(user.role)),
                              DataCell(Text(user.password)),
                              DataCell(
                                Row(
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        minimumSize: const Size(32, 28),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _showEditUserPopup(index),
                                      child: const Text(
                                        "Edit",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
