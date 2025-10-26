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
    url: 'https://eitslpixcfsxyfdvuclb.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVpdHNscGl4Y2ZzeHlmZHZ1Y2xiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyOTE3NDIsImV4cCI6MjA3Njg2Nzc0Mn0.UTQoWGFaMaTY2KUi9PH_8GqPRsmeHy_GsR4DmZSXBA8',
  );
  runApp(const MyApp());
}