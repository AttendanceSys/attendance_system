import 'package:flutter/material.dart';
import 'main_layout.dart'; // Correct import

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
      home: const MainLayout(),
    );
  }
}

// Add this entry point:
void main() {
  runApp(const MyApp());
}