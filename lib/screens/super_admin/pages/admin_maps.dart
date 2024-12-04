import 'dart:async';
import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:swiftpath/screens/admin/pages/emergency_vehicle.dart';
import 'package:logger/logger.dart';
import 'package:swiftpath/screens/super_admin/pages/incident_reports.dart';

class AdminMaps extends ConsumerStatefulWidget {
  const AdminMaps({super.key});

  @override
  _AdminMapsState createState() => _AdminMapsState();
}

class _AdminMapsState extends ConsumerState<AdminMaps> {
  final Completer<GoogleMapController> _controller = Completer();

  final Set<Marker> _markers = <Marker>{};
  List<Map<String, dynamic>> _reports = [];
//initial marker count value
  int markerIdCounter = 1;
  bool _loading = true;

  var logger = Logger(
    printer: PrettyPrinter(),
  );

  @override
  void initState() {
    super.initState();
    _fetchUserReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          "Incident Monitoring",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: _fetchUserReports,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Google Map with custom styling
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(14.5965241, 120.9901827),
              zoom: 13.5,
            ),
            mapType: MapType.normal,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              controller.setMapStyle(_mapStyle);
            },
            markers: _markers,
          ),

          // Loading indicator
          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.1),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),

          // Stats Card
          Positioned(
            top: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Incidents',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_markers.length}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Action Buttons
          Positioned(
            bottom: 20.0,
            right: 20.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'reports',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IncidentReportsScreen(),
                      ),
                    );
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.report_outlined, color: Colors.red),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'filter',
                  onPressed: () {
                    // Add filter functionality
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.filter_list, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchUserReports() async {
    setState(() {
      _loading = true;
    });
    final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

    try {
      final DataSnapshot snapshot = await dbRef.child('incident-reports').get();

      if (snapshot.exists) {
        // Iterate through geofence IDs
        Map<String, dynamic> geofenceGroups =
            Map<String, dynamic>.from(snapshot.value as Map);

        geofenceGroups.forEach((geofenceId, reports) {
          // Iterate through reports under each geofence ID
          Map<String, dynamic> incidentReports =
              Map<String, dynamic>.from(reports as Map);

          incidentReports.forEach((reportKey, reportValue) {
            final reportData = Map<String, dynamic>.from(reportValue);
            final latitude = reportData['latitude'];
            final longitude = reportData['longitude'];
            final reporterName = reportData['reporter_name'];

            if (latitude != null && longitude != null) {
              setMarker(
                LatLng(latitude, longitude),
                info: "Reported by $reporterName",
              );
            }
          });
        });

        setState(() {
          _loading = false;
        });
        print(
            'Fetched coordinates successfully: ${_markers.length} locations found.');
      } else {
        setState(() {
          _loading = false;
        });
        print("No incident reports found.");
      }
    } catch (e) {
      print('Failed to fetch coordinates from Firebase: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  void setMarker(LatLng point, {String? info}) {
    var counter = markerIdCounter++;
    final Marker marker = Marker(
        markerId: MarkerId('marker_$counter'),
        position: point,
        infoWindow: InfoWindow(title: info),
        icon: BitmapDescriptor.defaultMarker);

    setState(() {
      _markers.add(marker);
    });
  }

  // Add this variable for custom map styling
  final String _mapStyle = '''
    [
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#e9e9e9"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#ffffff"
          }
        ]
      }
    ]
  ''';
}
