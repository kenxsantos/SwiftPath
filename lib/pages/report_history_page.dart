import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportHistoryPage extends StatefulWidget {
  const ReportHistoryPage({super.key});

  @override
  _ReportHistoryPageState createState() => _ReportHistoryPageState();
}

class _ReportHistoryPageState extends State<ReportHistoryPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  // Fetch user's reports from Firebase
  Future<void> _fetchReports() async {
    final User? user = FirebaseAuth.instance.currentUser; // Get current user

    if (user != null) {
      final DataSnapshot snapshot =
          await _dbRef.child('incident-reports').get();
      List<Map<String, dynamic>> tempReports = [];

      if (snapshot.exists) {
        Map<String, dynamic> reports =
            Map<String, dynamic>.from(snapshot.value as Map);
        reports.forEach((key, value) {
          // Check if the report's email matches the user's email
          if (value['reporter_email'] == user.email) {
            tempReports.add(Map<String, dynamic>.from(value));
          }
        });
      }

      setState(() {
        _reports = tempReports;
        _loading = false;
      });
    }
  }

  // Method to show the modal dialog with all details
  void _showReportDetailsModal(
      BuildContext context, Map<String, dynamic> report) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      report['image_url'] != null
                          ? Image.network(
                              report['image_url'],
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.image_not_supported, size: 100),
                      const SizedBox(height: 20),
                      Text('${report['details']}',
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 8),
                      Text('${report['reporter_name']}',
                          style: const TextStyle(fontSize: 12)),
                      Text('${report['reporter_email']}',
                          style: const TextStyle(fontSize: 12)),
                      Text('${report['address']}',
                          style: const TextStyle(fontSize: 12)),
                      Text('${report['timestamp']}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report History'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            ) // Show loader while fetching data
          : _reports.isEmpty
              ? const Center(child: Text('No reports found.'))
              : ListView.builder(
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    final String detailsSnippet = report['details'] != null
                        ? (report['details'].length > 50
                            ? report['details'].substring(0, 50) + '...'
                            : report['details'])
                        : 'No Details';
                    final String addressSnippet = report['address'] != null
                        ? (report['address'].length > 60
                            ? report['address'].substring(0, 60) + '...'
                            : report['address'])
                        : 'No Address';
                    return GestureDetector(
                      onTap: () {
                        _showReportDetailsModal(context, report);
                      },
                      child: SizedBox(
                        height: 150,
                        width: double.infinity,
                        child: Card(
                          elevation:
                              4.0, // Set the elevation for the drop shadow
                          margin: const EdgeInsets.all(10.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: report['image_url'] != null
                                    ? Image.network(
                                        report['image_url'],
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(Icons.image_not_supported,
                                        size: 50),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 20.0, horizontal: 20.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        detailsSnippet,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w400,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        addressSnippet,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        '${report['timestamp']}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
