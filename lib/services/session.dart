import 'package:cloud_firestore/cloud_firestore.dart';

class Session {
  static String? username;
  static String? name;
  static DocumentReference? facultyRef;

  /// Normalize a faculty field from Firestore into a DocumentReference.
  ///
  /// Accepts:
  /// - a DocumentReference (returned as-is),
  /// - a string containing the id (e.g. 'science'),
  /// - or a path string like '/faculties/science' or 'faculties/science'.
  ///
  /// Sets `Session.facultyRef` or null if it cannot be resolved.
  static void setFacultyFromField(dynamic facField) {
    if (facField == null) {
      facultyRef = null;
      return;
    }
    if (facField is DocumentReference) {
      facultyRef = facField;
      return;
    }
    if (facField is String) {
      String s = facField;
      // remove leading slash if present
      if (s.startsWith('/')) s = s.substring(1);
      // split path and take last segment as id
      final parts = s.split('/').where((p) => p.isNotEmpty).toList();
      final id = parts.isNotEmpty ? parts.last : s;
      facultyRef = FirebaseFirestore.instance.collection('faculties').doc(id);
      return;
    }

    facultyRef = null;
  }
}
