import 'package:flutter/material.dart';
import '../components/cards/searchBar.dart'; // Import your component

class DepartmentScreen extends StatelessWidget {
  const DepartmentScreen({super.key});

  @override

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Departments")),
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

