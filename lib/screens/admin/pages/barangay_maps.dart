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
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

class BarangayMaps extends ConsumerStatefulWidget {
  const BarangayMaps({super.key});

  @override
  _BarangayMapsState createState() => _BarangayMapsState();
}

class _BarangayMapsState extends ConsumerState<BarangayMaps> {
  final Completer<GoogleMapController> _controller = Completer();

  final Set<Marker> _markers = <Marker>{};
  List<Map<String, dynamic>> _reports = [];
//initial marker count value
  int markerIdCounter = 1;
  bool _loading = true;

  var logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
    ),
  );

  final List<LatLng> polygonCoordinates = [
    const LatLng(14.603723, 120.981973),
    const LatLng(14.596761, 120.980702),
    const LatLng(14.594853, 120.982842),
    const LatLng(14.595495, 120.984411),
    const LatLng(14.595278, 120.985546),
    const LatLng(14.595347, 120.985927),
    const LatLng(14.595034, 120.987186),
    const LatLng(14.593315, 120.989588),
    const LatLng(14.593480, 120.990356),
    const LatLng(14.595507, 120.991074),
    const LatLng(14.596340, 120.990907),
    const LatLng(14.597527, 120.990640),
    const LatLng(14.598568, 120.991062),
    const LatLng(14.600145, 120.991415),
    const LatLng(14.603147, 120.985040),
    const LatLng(14.603723, 120.981973), // Close the polygon
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserReports(120.985560, 14.598317);
    _listenToDatabaseChanges();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Barangay Maps Page")),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(14.598317, 120.985560),
              zoom: 15,
            ),
            mapType: MapType.normal,
            onMapCreated: (GoogleMapController controller) {
              if (!_controller.isCompleted) {
                _controller.complete(controller);
              }
            },
            markers: _markers,
            polygons: _createPolygon(),
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
              Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
              Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
              Factory<VerticalDragGestureRecognizer>(
                () => VerticalDragGestureRecognizer(),
              ),
            },
          ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(),
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

  void _listenToDatabaseChanges() {
    final DatabaseReference dbRef =
        FirebaseDatabase.instance.ref("incident-reports");

    dbRef.onChildAdded.listen((DatabaseEvent event) {
      // _showSnackbar("An incident report was added!");
      _fetchUserReports(120.985560, 14.598317);
    });

    dbRef.onChildChanged.listen((DatabaseEvent event) {
      _showSnackbar("An incident report was updated!");
      _fetchUserReports(120.985560, 14.598317);
    });

    dbRef.onChildRemoved.listen((DatabaseEvent event) {
      _showSnackbar("An incident report was deleted!");
      _fetchUserReports(120.985560, 14.598317);
    });
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _fetchUserReports(double latitude, double longitude) async {
    final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
    setState(() {
      _loading = true;
      _markers.clear();
    });
    // setCircle(const LatLng(120.9859236, 14.6006512));
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

          reports.forEach((key, value) {
            final reportData = Map<String, dynamic>.from(value);
            final latitude = reportData['latitude'];
            final longitude = reportData['longitude'];
            final geofenceId = reportData['geofence_id'];
            final status = reportData['status'];

            if (latitude != null &&
                longitude != null &&
                roamGeofenceIds.contains(geofenceId) &&
                status == 'Pending') {
              coordinatesList.add({
                'latitude': latitude,
                'longitude': longitude,
              });
              setMarker(LatLng(latitude, longitude), info: "Incident Report");
            }
          });
        }
        setState(() {
          _reports = coordinatesList;
          _loading = false;
        });

        _showSnackbar("${_reports.length} incident reports found.");

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

  Set<Polygon> _createPolygon() {
    return {
      Polygon(
        polygonId: const PolygonId('santo_nino_polygon'),
        points: polygonCoordinates, // Use the converted coordinates
        fillColor: Colors.red.withOpacity(0.3),
        strokeColor: Colors.red,
        strokeWidth: 2,
      ),
    };
  }

  void setMarker(LatLng point, {String? info}) {
    var counter = markerIdCounter++;
    final Marker marker = Marker(
        markerId: MarkerId('marker_$counter'),
        position: point,
        infoWindow: InfoWindow(title: info),
        onTap: () => showBottomSheet(),
        icon: BitmapDescriptor.defaultMarker);

    setState(() {
      _markers.add(marker);
    });
  }

  void showBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: Colors.white,
          ),
          height: 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('Incident Report'),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
