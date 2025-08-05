import 'package:flutter/material.dart';
import '../components/cards/searchBar.dart';

class DepartmentScreen extends StatefulWidget {
  const DepartmentScreen({super.key});

  @override
  State<DepartmentScreen> createState() => _DepartmentScreenState();
}

class _DepartmentScreenState extends State<DepartmentScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Departments"),
        backgroundColor: Colors.indigo.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SearchAddBar(
              hintText: "Search departments...",
              buttonText: "Add Departments",
              onAddPressed: () {
                // Handle add department action
              },
              onChanged: (query) {
                // Handle search
              },
            ),
            // Add the rest of your UI here (ListView, etc.)
          ],
        ),
      ),
    );
  }
}
