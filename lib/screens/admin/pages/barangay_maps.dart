import 'dart:async';
import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:swiftpath/screens/admin/pages/emergency_vehicle.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BarangayMaps extends ConsumerStatefulWidget {
  const BarangayMaps({super.key});

  @override
  _BarangayMapsState createState() => _BarangayMapsState();
}

class _BarangayMapsState extends ConsumerState<BarangayMaps> {
  final Completer<GoogleMapController> _controller = Completer();

  Set<Marker> _markers = <Marker>{};
  Set<Marker> _markersDupe = <Marker>{};
  Set<Circle> _circles = <Circle>{};
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
    _fetchUserReports(120.9901827, 14.5965241);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(120.9901827, 14.5965241),
              zoom: 13.5,
            ),
            mapType: MapType.normal,
            onMapCreated: (controller) => _controller.complete(controller),
            markers: _markers,
            circles: _circles,
          ),
          Positioned(
            bottom: 20.0,
            left: 20.0,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const EmergencyVehicles()),
                );
              },
              backgroundColor: Colors.red,
              child: const Icon(Icons.report, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchUserReports(double latitude, double longitude) async {
    final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
    setState(() {
      _loading = true;
    });

    final String roamAiApiKey = dotenv.env['ROAM_AI_API_KEY'] ?? '';
    final int radiusInMeters = (10 * 10000).toInt();
    var response = await http.get(
      Uri.parse(
          'https://api.roam.ai/v1/api/search/geofences/?radius=$radiusInMeters&location=$latitude,$longitude&page_limit=15'),
      headers: {
        'Api-key': roamAiApiKey,
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      List<String> roamGeofenceIds = [];
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> geofences = data['data']['geofences'];

      if (geofences.isNotEmpty) {
        roamGeofenceIds =
            geofences.map((geofence) => geofence['id'].toString()).toList();
      }

      // Step 2: Fetch Firebase data
      try {
        final DataSnapshot snapshot =
            await dbRef.child('incident-reports').get();
        List<Map<String, dynamic>> coordinatesList = [];

        if (snapshot.exists) {
          Map<String, dynamic> reports =
              Map<String, dynamic>.from(snapshot.value as Map);

          // Step 3: Filter reports by matching Roam.ai geofence IDs
          reports.forEach((key, value) {
            final reportData = Map<String, dynamic>.from(value);
            final latitude = reportData['latitude'];
            final longitude = reportData['longitude'];
            final geofenceId = reportData['geofence_id'];

            if (latitude != null &&
                longitude != null &&
                roamGeofenceIds.contains(geofenceId)) {
              coordinatesList.add({
                'latitude': latitude,
                'longitude': longitude,
              });
              // Add marker for each matching report
              setMarker(LatLng(latitude, longitude), info: "Incident Report");
            }
          });
        }

        // Set map circle around the user's location
        setCircle(LatLng(latitude, longitude));

        setState(() {
          _reports =
              coordinatesList; // Update _reports to contain only coordinates
          _loading = false;
        });

        logger.i(
            'Fetched coordinates successfully: ${_reports.length} locations found.');
      } catch (e) {
        logger.e('Failed to fetch coordinates from Firebase: $e');
        setState(() {
          _loading = false;
        });
      }
    } else {
      logger.e('Failed to fetch geofences from Roam.ai: ${response.body}');
      setState(() {
        _loading = false;
      });
    }
  }

  void setCircle(LatLng point) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: point, zoom: 12)));
    setState(() {
      _circles.add(Circle(
        circleId: const CircleId('circle_1'),
        center: point,
        fillColor: Colors.blue.withOpacity(0.1),
        radius: 10000,
        strokeColor: Colors.blue,
        strokeWidth: 1,
      ));
    });
  }

  void setMarker(LatLng point, {String? info}) {
    var counter = markerIdCounter++;
    final Marker marker = Marker(
        markerId: MarkerId('marker_$counter'),
        position: point,
        infoWindow: InfoWindow(title: info),
        onTap: () {},
        icon: BitmapDescriptor.defaultMarker);

    setState(() {
      _markers.add(marker);
    });
  }
}
