import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'layouts/super_admin_layout.dart'; // Correct import
import 'layouts/faculty_admin_layout.dart';
import 'layouts/teacher_layout.dart';
import 'screens/departScreen.dart';
import 'components/popup/success_popup.dart';
import 'components/popup/error_popup.dart'; // Import for error popup
import 'screens/login_screen.dart';
import 'components/popup/add_class_popup.dart';
import 'components/popup/add_course_popup.dart';
import 'components/popup/add_student_popup.dart';
import 'components/popup/add_department_popup.dart';
import 'components/popup/add_admin_popup.dart';
import 'components/popup/add_teacher_popup.dart';
import 'components/popup/add_faculty_popup.dart';
import 'layouts/faculty_DashboardStatsGrid.dart';
import 'layouts/AdminDashboardStatsGrid .dart';
import 'screens/super_admin_page.dart';
// import 'screens/faculty_admin_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      home: const LoginScreen(),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://lramktivhjyjlvkhkost.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxyYW1rdGl2aGp5amx2a2hrb3N0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ5MjE0MTIsImV4cCI6MjA3MDQ5NzQxMn0.ZBi0t9LIAbWIPQtG0v7_NF5BRjvVcV6DClclJ-5e_TI',
  );
  runApp(const MyApp());
}
