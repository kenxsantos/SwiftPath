import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class EmergencyVehicles extends StatefulWidget {
  const EmergencyVehicles({super.key});

  @override
  State<EmergencyVehicles> createState() => _EmergencyVehiclesState();
}

class _EmergencyVehiclesState extends State<EmergencyVehicles> {
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
    final DataSnapshot snapshot = await _dbRef.child('incident-reports').get();
    List<Map<String, dynamic>> tempReports = [];

    if (snapshot.exists) {
      Map<String, dynamic> reports =
          Map<String, dynamic>.from(snapshot.value as Map);
      reports.forEach((key, value) {
        tempReports.add(Map<String, dynamic>.from(value));
      });
    }

    setState(() {
      _reports = tempReports;
      _loading = false;
    });
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
                padding: const EdgeInsets.all(10.0),
                child: SingleChildScrollView(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          iconSize: 20,
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
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

                    const SizedBox(height: 20), // Add space before the button

                    Center(
                      child: TextButton(
                        onPressed: () {
                          print('Take Action button pressed');
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          backgroundColor: Colors.red, // Set the button color
                        ),
                        child: const Text(
                          'Take Action',
                          style: TextStyle(
                              color: Colors.white), // Set the text color
                        ),
                      ),
                    ),
                  ],
                )),
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
        title: const Text('Incident Reports'),
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
                        height:
                            200, // Adjusted height to accommodate status row
                        width: double.infinity,
                        child: Card(
                          elevation:
                              4.0, // Set the elevation for the drop shadow
                          margin: const EdgeInsets.all(10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 5.0, horizontal: 5.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors
                                            .red, // Badge background color
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                      child: const Text(
                                        'Pending', // Dynamic status
                                        style: TextStyle(
                                          color:
                                              Colors.white, // Badge text color
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                          Text(
                                            '${report['timestamp']}',
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
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
