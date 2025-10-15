import 'package:flutter/material.dart';
import '../../screens/login_screen.dart'; // Make sure this import path is correct for your project!

class StudentProfilePopup extends StatelessWidget {
  final String name;
  final String className;
  final String semester;
  final String gender;
  final String id;
  final String avatarLetter;

  const StudentProfilePopup({
    super.key,
    required this.name,
    required this.className,
    required this.semester,
    required this.gender,
    required this.id,
    required this.avatarLetter,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.lightBlue[400],
              child: Text(
                avatarLetter,
                style: TextStyle(fontSize: 72, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 18),
            Text(
              name,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            infoRow("Class:", className),
            infoRow("Semester:", semester),
            infoRow("Gender:", gender),
            infoRow("ID:", id),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logout button on the left
                SizedBox(
                  width: 96,
                  height: 38,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.logout, size: 20, color: Colors.white),
                    label: Text("Logout", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the popup
                      // Navigate to login screen and remove all previous routes
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                  ),
                ),
                // OK button on the right
                SizedBox(
                  width: 72,
                  height: 38,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2196F3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text("OK", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          text: "$label ",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 17),
          children: [
            TextSpan(
              text: value,
              style: TextStyle(fontWeight: FontWeight.normal, color: Colors.black87, fontSize: 17),
            ),
          ],
        ),
      ),
    );
  }
}