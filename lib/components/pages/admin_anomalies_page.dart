import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/location_service.dart';
import '../../config.dart';

class AdminAnomaliesPage extends StatefulWidget {
  const AdminAnomaliesPage({super.key});

  @override
  State<AdminAnomaliesPage> createState() => _AdminAnomaliesPageState();
}

class _AnomalyEntry {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Map<String, dynamic>? sessionData;
  final double? distanceMeters;
  final List<String> flags;

  _AnomalyEntry({
    required this.doc,
    this.sessionData,
    this.distanceMeters,
    required this.flags,
  });
}

class _AdminAnomaliesPageState extends State<AdminAnomaliesPage> {
  bool _loading = true;
  List<_AnomalyEntry> _items = [];
  bool _onlyFlagged = true;
  // Filters
  String _sortBy = 'Date (newest)';
  String? _selectedSubject;
  String? _selectedClass;
  String? _selectedFraudType;
  bool _showOnlyUnreviewed = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    setState(() {
      _loading = true;
    });

    try {
      final col = FirebaseFirestore.instance.collection('attendance_records');
      final q = await col
          .orderBy('scannedAt', descending: true)
          .limit(200)
          .get();

      // collect unique session ids
      final sessionIds = <String>{};
      for (final d in q.docs) {
        final sid = (d.data()['session_id'] ?? d.data()['sessionId'] ?? '')
            .toString();
        if (sid.isNotEmpty) sessionIds.add(sid);
      }

      // fetch session docs by id
      final sessionMap = <String, Map<String, dynamic>>{};
      for (final sid in sessionIds) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('qr_generation')
              .doc(sid)
              .get();
          if (snap.exists) {
            sessionMap[sid] = snap.data() ?? {};
          }
        } catch (_) {}
      }

      // detect duplicates locally (same username + session)
      final pairCounts = <String, int>{};
      for (final d in q.docs) {
        final data = d.data();
        final uname = (data['username'] ?? '').toString();
        final sid = (data['session_id'] ?? data['sessionId'] ?? '').toString();
        final key = '$uname|$sid';
        pairCounts[key] = (pairCounts[key] ?? 0) + 1;
      }

      final entries = <_AnomalyEntry>[];
      for (final d in q.docs) {
        final data = d.data();
        final uname = (data['username'] ?? '').toString();
        final sid = (data['session_id'] ?? data['sessionId'] ?? '').toString();
        final session = sid.isNotEmpty ? sessionMap[sid] : null;

        List<String> flags = [];

        // flag: duplicate
        final dupKey = '$uname|$sid';
        if ((pairCounts[dupKey] ?? 0) > 1) flags.add('double_scan');

        // flag: no location
        final loc = data['location'];
        if (loc == null) {
          flags.add('no_location');
        } else {
          final lat = _toDouble(loc['lat']);
          final lng = _toDouble(loc['lng']);
          final acc = _toDouble(loc['accuracy']) ?? 10000.0;
          if (acc > kGpsAccuracyThresholdMeters) flags.add('low_accuracy');

          // check off-campus using session.allowed_location if present
          if (session != null && session['allowed_location'] != null) {
            final al = session['allowed_location'];
            final aLat = _toDouble(al['lat']);
            final aLng = _toDouble(al['lng']);
            final aRad = _toDouble(al['radius']) ?? kDefaultCampusRadiusMeters;
            double? dist;
            if (lat != null && lng != null && aLat != null && aLng != null) {
              dist = LocationService.distanceMeters(lat, lng, aLat, aLng);
              if (dist > aRad) flags.add('off_campus');
            }
            entries.add(
              _AnomalyEntry(
                doc: d,
                sessionData: session,
                distanceMeters: dist,
                flags: flags,
              ),
            );
            continue;
          }
        }

        entries.add(
          _AnomalyEntry(
            doc: d,
            sessionData: session,
            distanceMeters: null,
            flags: flags,
          ),
        );
      }

      setState(() {
        _items = entries;
      });
    } catch (e) {
      debugPrint('Error loading anomalies: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    try {
      return double.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  Future<void> _markReviewed(
    DocumentReference ref, {
    required bool cleared,
    bool showUndo = true,
  }) async {
    try {
      await ref.update({
        'admin_reviewed': true,
        'admin_flag_cleared': cleared,
        'admin_reviewed_at': FieldValue.serverTimestamp(),
      });

      if (showUndo) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cleared ? 'Marked OK' : 'Marked Fraud'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await _undoReview(ref);
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleared ? 'Marked OK' : 'Marked Fraud')),
        );
      }

      await _loadRecent();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }
  }

  Future<void> _undoReview(DocumentReference ref) async {
    try {
      await ref.update({
        'admin_reviewed': false,
        'admin_flag_cleared': FieldValue.delete(),
        'admin_reviewed_at': FieldValue.delete(),
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Review undone')));
      await _loadRecent();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to undo: $e')));
    }
  }

  Future<void> _confirmAndMark(
    DocumentReference ref, {
    required bool cleared,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(cleared ? 'Confirm Mark OK' : 'Confirm Mark Fraud'),
        content: Text(
          cleared
              ? 'Mark this record as OK? This will mark it reviewed.'
              : 'Mark this record as Fraud? This will mark it reviewed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _markReviewed(ref, cleared: cleared, showUndo: true);
    }
  }

  String _formatTimestamp(dynamic v) {
    if (v == null) return '';
    try {
      DateTime dt;
      if (v is Timestamp) {
        dt = v.toDate();
      } else if (v is DateTime)
        dt = v;
      else
        dt = DateTime.parse(v.toString());
      return '${dt.toLocal()}';
    } catch (_) {
      return v.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anomaly / Flagged Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecent,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  child: _buildFilters(),
                ),
                Expanded(child: _buildList()),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    final frauds = _availableFraudTypes();

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Only flagged'),
            Switch(
              value: _onlyFlagged,
              onChanged: (v) => setState(() => _onlyFlagged = v),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Unreviewed'),
            Switch(
              value: _showOnlyUnreviewed,
              onChanged: (v) => setState(() => _showOnlyUnreviewed = v),
            ),
          ],
        ),
        DropdownButton<String>(
          value: _sortBy,
          items: const [
            DropdownMenuItem(
              value: 'Date (newest)',
              child: Text('Date (newest)'),
            ),
            DropdownMenuItem(
              value: 'Date (oldest)',
              child: Text('Date (oldest)'),
            ),
          ],
          onChanged: (v) => setState(() => _sortBy = v ?? 'Date (newest)'),
          hint: const Text('Sort'),
        ),
        // Subject filter dropdown
        DropdownButton<String?>(
          value: _selectedSubject,
          items:
              <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All subjects'),
                    ),
                  ]
                  .followedBy(
                    _availableSubjects().map(
                      (s) =>
                          DropdownMenuItem<String?>(value: s, child: Text(s)),
                    ),
                  )
                  .toList(),
          onChanged: (String? v) => setState(() => _selectedSubject = v),
        ),
        // Class filter dropdown
        DropdownButton<String?>(
          value: _selectedClass,
          items:
              <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All classes'),
                    ),
                  ]
                  .followedBy(
                    _availableClasses().map(
                      (s) =>
                          DropdownMenuItem<String?>(value: s, child: Text(s)),
                    ),
                  )
                  .toList(),
          onChanged: (String? v) => setState(() => _selectedClass = v),
        ),
        DropdownButton<String?>(
          value: _selectedFraudType,
          items:
              <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All fraud types'),
                    ),
                  ]
                  .followedBy(
                    frauds.map(
                      (s) =>
                          DropdownMenuItem<String?>(value: s, child: Text(s)),
                    ),
                  )
                  .toList(),
          onChanged: (String? v) => setState(() => _selectedFraudType = v),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _selectedSubject = null;
              _selectedClass = null;
              _selectedFraudType = null;
              _sortBy = 'Date (newest)';
              _onlyFlagged = true;
              _showOnlyUnreviewed = false;
            });
          },
          child: const Text('Reset'),
        ),
      ],
    );
  }

  List<String> _availableSubjects() {
    final set = <String>{};
    for (final e in _items) {
      final data = e.doc.data();
      final session = e.sessionData;
      final subject = session != null
          ? (session['subject'] ?? '')
          : (data['subject'] ?? '');
      if ((subject ?? '').toString().isNotEmpty) set.add(subject.toString());
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> _availableClasses() {
    final set = <String>{};
    for (final e in _items) {
      final data = e.doc.data();
      final session = e.sessionData;
      final cls = session != null
          ? (session['class'] ?? session['className'] ?? '')
          : (data['class'] ?? '');
      if ((cls ?? '').toString().isNotEmpty) set.add(cls.toString());
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> _availableFraudTypes() {
    final set = <String>{};
    for (final e in _items) {
      for (final f in e.flags) {
        set.add(f);
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  Widget _buildList() {
    // apply filters
    var filtered = _items.where((e) {
      final data = e.doc.data();

      // Only flagged option: when enabled show only flagged records
      if (_onlyFlagged) {
        if (e.flags.isEmpty) return false;
      }

      // only unreviewed
      if (_showOnlyUnreviewed) {
        if ((data['admin_reviewed'] ?? false) == true) return false;
      }

      // subject filter
      if (_selectedSubject != null && _selectedSubject!.isNotEmpty) {
        final session = e.sessionData;
        final subject = session != null
            ? (session['subject'] ?? '')
            : (data['subject'] ?? '');
        if ((subject ?? '').toString() != _selectedSubject) return false;
      }

      // class filter
      if (_selectedClass != null && _selectedClass!.isNotEmpty) {
        final session = e.sessionData;
        final cls = session != null
            ? (session['class'] ?? session['className'] ?? '')
            : (data['class'] ?? '');
        if ((cls ?? '').toString() != _selectedClass) return false;
      }

      // fraud type filter
      if (_selectedFraudType != null && _selectedFraudType!.isNotEmpty) {
        if (!e.flags.contains(_selectedFraudType)) return false;
      }

      return true;
    }).toList();

    // sorting (only date newest/oldest)
    filtered.sort((a, b) {
      if (_sortBy == 'Date (newest)') {
        return _scannedMillis(b).compareTo(_scannedMillis(a));
      } else if (_sortBy == 'Date (oldest)') {
        return _scannedMillis(a).compareTo(_scannedMillis(b));
      }
      return 0;
    });

    if (filtered.isEmpty) {
      return const Center(child: Text('No flagged records found.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 12),
      itemBuilder: (context, index) {
        final e = filtered[index];
        final data = e.doc.data();
        final session = e.sessionData;
        final subject = session != null
            ? (session['subject'] ?? '')
            : (data['subject'] ?? '');
        final scannedAt = data['scannedAt'];
        final username = data['username'] ?? 'unknown';
        final flags = e.flags;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$username',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(subject.toString()),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Session: ${data['session_id'] ?? data['sessionId'] ?? 'n/a'}',
                ),
                const SizedBox(height: 6),
                Text('Scanned at: ${scannedAt ?? data['timestamp'] ?? ''}'),
                const SizedBox(height: 6),
                if (data['location'] != null) ...[
                  Text(
                    'Location: lat=${data['location']['lat']}, lng=${data['location']['lng']}, accuracy=${data['location']['accuracy']}',
                  ),
                  if (e.distanceMeters != null)
                    Text(
                      'Distance to allowed center: ${e.distanceMeters!.toStringAsFixed(1)} m',
                    ),
                ] else ...[
                  const Text('Location: (not provided)'),
                ],
                const SizedBox(height: 8),
                // review status
                if (data['admin_reviewed'] == true) ...[
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          data['admin_flag_cleared'] == true
                              ? 'Reviewed: OK'
                              : 'Reviewed: Fraud',
                        ),
                        backgroundColor: data['admin_flag_cleared'] == true
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                      ),
                      const SizedBox(width: 8),
                      Text(_formatTimestamp(data['admin_reviewed_at'])),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: flags.isEmpty
                      ? [
                          Chip(
                            label: Text(
                              data['admin_reviewed'] == true
                                  ? 'Reviewed'
                                  : 'No flags',
                            ),
                          ),
                        ]
                      : flags
                            .map(
                              (f) => Chip(
                                label: Text(f),
                                backgroundColor: Colors.orange.shade100,
                              ),
                            )
                            .toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: (data['admin_reviewed'] == true)
                          ? null
                          : () => _markReviewed(e.doc.reference, cleared: true),
                      child: const Text('Mark OK'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: (data['admin_reviewed'] == true)
                          ? null
                          : () =>
                                _markReviewed(e.doc.reference, cleared: false),
                      child: const Text('Mark Fraud'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        // show raw doc
                        await showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Raw record'),
                            content: SingleChildScrollView(
                              child: Text(e.doc.data().toString()),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('Inspect'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _scannedMillis(_AnomalyEntry e) {
    final data = e.doc.data();
    final v = data['scannedAt'] ?? data['timestamp'];
    if (v == null) return 0;
    try {
      if (v is Timestamp) return v.toDate().millisecondsSinceEpoch;
      if (v is DateTime) return v.millisecondsSinceEpoch;
      return DateTime.parse(v.toString()).millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }
}
