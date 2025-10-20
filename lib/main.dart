import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // <-- Add this import!
import 'screens/login_screen.dart';

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