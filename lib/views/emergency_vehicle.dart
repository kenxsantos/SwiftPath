import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
// import 'package:location/location.dart';

class EmergencyVehicles extends StatefulWidget {
  const EmergencyVehicles({super.key});

  @override
  State<EmergencyVehicles> createState() => _EmergencyVehiclesState();
}

class _EmergencyVehiclesState extends State<EmergencyVehicles> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  List<Map<String, dynamic>> _geofences = [];
  late Position position;

  final LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 100,
  );

  @override
  void initState() {
    super.initState();

    _getUserLocationAndFetchReports();
  }

  Future<void> _getUserLocationAndFetchReports() async {
    // Get the current position of the user
    position = await _determinePosition();

    // Fetch reports based on the user's current location
    _fetchReports(
        position.longitude, position.latitude, 10); // Radius in kilometers
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    // Check for location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    return await Geolocator.getCurrentPosition(
        locationSettings: locationSettings);
  }

  // Fetch user's reports from Firebase and Roam.ai
  Future<void> _fetchReports(
      double latitude, double longitude, double radius) async {
    setState(() {
      _loading = true;
    });

    final String roamAiApiKey = dotenv.env['ROAM_AI_API_KEY'] ?? '';
    final int radiusInMeters = (radius * 100).toInt();
    var response = await http.get(
      Uri.parse(
          'https://api.roam.ai/v1/api/search/geofences/?radius=$radiusInMeters&location=$latitude,$longitude&page_limit=15'),
      headers: {
        'Api-key': roamAiApiKey,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      List<Map<String, dynamic>> roamGeofences = [];
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> geofences =
          data['data']['geofences']; // Get the list of geofences

      if (geofences.isNotEmpty) {
        roamGeofences = geofences.map((geofence) {
          return {
            'id': geofence['id'],
          };
        }).toList();
      }

      // Step 3: Fetch all incident reports from Firebase Realtime Database
      final DataSnapshot snapshot =
          await _dbRef.child('incident-reports').get();
      List<Map<String, dynamic>> matchingReports = [];

      if (snapshot.exists) {
        Map<String, dynamic> firebaseGeofences =
            Map<String, dynamic>.from(snapshot.value as Map);

        firebaseGeofences.forEach((key, value) {
          final firebaseGeofence = Map<String, dynamic>.from(value);
          final geofenceId = firebaseGeofence['geofence_id'];
          if (geofenceId != null &&
              roamGeofences.any((geofence) => geofence['id'] == geofenceId)) {
            matchingReports.add(firebaseGeofence);
          }
        });
      }
      setState(() {
        _reports = matchingReports;
        _loading = false;
      });
      print(
          'Matching incident reports fetched successfully: ${_reports.length} reports found.');
    } else {
      print('Failed to fetch geofences from Roam.ai: ${response.body}');
      setState(() {
        _loading = false;
      });
    }
  }

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
                          _createMovingGeofence();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          backgroundColor: Colors.red, // Set the button color
                        ),
                        child: const Text(
                          'Take Action',
                          style: TextStyle(
                            color: Colors.white, // Set the text color
                          ),
                        ),
                      ),
                    )
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
            )
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
                                      child: Text('${report['status']}',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white)),
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

  Future<void> _createMovingGeofence() async {
    final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
    final String roamAiApiKey =
        dotenv.env['ROAM_AI_API_KEY'] ?? ''; // Roam API key

    // Geofence data to be sent to the Roam AI API
    final Map<String, dynamic> geofenceData = {
      "geometry_type": "circle",
      "geometry_radius": 500,
      "color_code": "FF0000",
      "is_enabled": true,
      "only_once": true,
      "users": [
        "67160e2fc45da22ca9d0f61f",
        "6718a906acae090b0ad82ebf",
        "6718a93a8d38d6102302fb9b"
      ]
    };

    // Send a request to the Roam AI API
    try {
      final response = await http.post(
        Uri.parse('https://api.roam.ai/v1/api/moving-geofence/'),
        headers: {
          'Api-Key': roamAiApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(geofenceData),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData =
            jsonDecode(response.body)['data'];

        // Store geofence data in Firebase
        final Map<String, dynamic> firebaseGeofenceData = {
          "geofence_id": responseData["id"],
          "account_id": responseData["account_id"],
          "project_id": responseData["project_id"],
          "geometry_type": responseData["geometry_type"],
          "geometry_radius": responseData["geometry_radius"],
          "is_enabled": responseData["is_enabled"],
          "is_deleted": responseData["is_deleted"],
          "only_once": responseData["only_once"],
          "users": responseData["users"],
          "created_at": responseData["created_at"],
          "updated_at": responseData["updated_at"],
        };

        await dbRef.child('moving-geofences').push().set(firebaseGeofenceData);
        print('Moving geofence created and data stored successfully.');
        _showDialog('Success', 'Geofence created successfully.');
      } else {
        print('Error creating moving geofence: ${response.body}');
        _showDialog('Error', 'Failed to create geofence.');
      }
    } catch (e) {
      print('Error creating moving geofence: $e');
      _showDialog('Error', 'An error occurred while creating the geofence.');
    }
  }

  void _showDialog(String title, String message) {
    // Implement a dialog function to show success/error messages
    print('$title: $message'); // Simple console print for now
  }
}
