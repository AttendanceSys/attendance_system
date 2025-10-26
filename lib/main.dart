import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/login_screen.dart'; // Correct import for LoginScreen

// Add a method to initialize Firebase
Future<void> initializeFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "AIzaSyBeSSiJHWeh8Www64JQKx6LhcjfT7zTlrI",
        authDomain: "attendancesystem-9350f.firebaseapp.com",
        projectId: "attendancesystem-9350f",
        storageBucket: "attendancesystem-9350f.appspot.com",
        messagingSenderId: "15742427682",
        appId: "1:15742427682:web:2534bdb5287500318fe07b",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
}

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

// Update the main entry point to initialize Firebase
void main() async {
  await initializeFirebase(); // Ensure Firebase is initialized
  runApp(const MyApp());
}
