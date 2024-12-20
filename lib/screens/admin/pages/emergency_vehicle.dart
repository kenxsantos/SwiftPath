import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:roam_flutter/roam_flutter.dart';
import 'package:roam_flutter/trips_v2/RoamTrip.dart';
import 'package:roam_flutter/trips_v2/request/RoamTripStops.dart';
import 'package:logger/logger.dart';
import 'package:swiftpath/screens/users/pages/show_routes.dart';

class EmergencyVehicles extends StatefulWidget {
  const EmergencyVehicles({super.key});

  @override
  State<EmergencyVehicles> createState() => _EmergencyVehiclesState();
}

class _EmergencyVehiclesState extends State<EmergencyVehicles> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  String? myTrip;
  String? tripId;
  String? response;
  String? myUserId;

  var logger = Logger(
    printer: PrettyPrinter(),
  );

  final List<Map<String, dynamic>> _geofences = [];
  late Position position;
  final Set<Polyline> _polylines = <Polyline>{};
  int polylineIdCounter = 1;
  final Completer<GoogleMapController> _controller = Completer();

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
    position = await _getCurrentPosition();
    _fetchReports(120.985560, 14.598317);
  }

  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }
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
  Future<void> _fetchReports(double latitude, double longitude) async {
    setState(() {
      _loading = true;
    });

    final String roamAiApiKey = dotenv.env['ROAM_AI_API_KEY'] ?? '';
    const int radiusInMeters = 650;
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
      logger.i(
          'Matching incident reports fetched successfully: ${_reports.length} reports found.');
    } else {
      logger.e('Failed to fetch geofences from Roam.ai: ${response.body}');
      setState(() {
        _loading = false;
      });
    }
  }

//initial marker count value

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
                        onPressed: report['status'] == 'Pending'
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ShowRoutes(
                                      geofenceId: report['geofence_id'],
                                      destination: {
                                        'lat': report['latitude'],
                                        'lng': report['longitude'],
                                      },
                                      origin: {
                                        'lat': position.latitude,
                                        'lng': position.longitude,
                                      },
                                    ),
                                  ),
                                );
                              }
                            : null, // No action for statuses other than 'Pending'
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          backgroundColor: report['status'] == 'Done'
                              ? Colors.grey // Disabled state color
                              : Colors.red, // Active state color
                        ),
                        child: const Text(
                          'Take Action',
                          style: TextStyle(
                            color: Colors.white,
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
        title: const Text('Barangay Incident Reports'),
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

  Future<String> _getAddressFromLatLng(
      double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      Placemark place = placemarks[0];

      // Construct a readable address from the placemark data
      String address =
          "${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}";
      return address;
    } catch (e) {
      logger.e(e);
      return "Address not available";
    }
  }
}
