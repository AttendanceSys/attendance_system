import 'package:flutter/material.dart';
import 'main_layout.dart'; // Correct import
import 'faculty_admin_layout.dart';
import 'teacher_layout.dart';
import 'components/popup/success_popup.dart';
// add error popup import
import 'components/popup/error_popup.dart'; // Import for error popup


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const ErrorPopupDemoPage(),
    );
  }
}

// Add this entry point:
void main() {
  runApp(const MyApp());
}