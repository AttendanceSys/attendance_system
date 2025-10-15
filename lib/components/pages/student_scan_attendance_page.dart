import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'student_view_attendance_page.dart'; // <-- Import your View Attendance page!

class StudentScanAttendancePage extends StatefulWidget {
  const StudentScanAttendancePage({Key? key}) : super(key: key);

  @override
  State<StudentScanAttendancePage> createState() =>
      _StudentScanAttendancePageState();
}

class _StudentScanAttendancePageState extends State<StudentScanAttendancePage> {
  final MobileScannerController _controller = MobileScannerController();
  String? scanResult;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: MobileScanner(
                controller: _controller,
                onDetect: (barcode) {
                  if (barcode.barcodes.isNotEmpty) {
                    final String? code = barcode.barcodes.first.rawValue;
                    if (scanResult == null && code != null) {
                      setState(() {
                        scanResult = code;
                      });
                      // TODO: Add your logic here (mark attendance, show popup, etc.)
                      _controller.stop();
                    }
                  }
                },
              ),
            ),
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // View Attendance button: wrap with GestureDetector for navigation!
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const StudentViewAttendanceMobile(),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Text(
                          "View  Attendance",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 2),
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.lightBlue[400],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.table_chart,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        "Scan  Attendance",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: 2),
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.lightBlue[400],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.qr_code_scanner,
                          size: 38,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
