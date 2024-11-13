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
      appBar: AppBar(title: const Text("Admin Maps Page")),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(14.5965241, 120.9901827),
              zoom: 13.5,
            ),
            mapType: MapType.normal,
            onMapCreated: (controller) => _controller.complete(controller),
            markers: _markers,
          ),
          Positioned(
            bottom: 20.0,
            left: 20.0,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const IncidentReportsScreen()),
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

  Future<void> _fetchUserReports() async {
    setState(() {
      _loading = true;
    });
    final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

    try {
      final DataSnapshot snapshot = await dbRef.child('incident-reports').get();

      if (snapshot.exists) {
        Map<String, dynamic> reports =
            Map<String, dynamic>.from(snapshot.value as Map);

        reports.forEach((key, value) {
          final reportData = Map<String, dynamic>.from(value);
          final latitude = reportData['latitude'];
          final longitude = reportData['longitude'];

          if (latitude != null && longitude != null) {
            setMarker(LatLng(latitude, longitude), info: "Incident Report");
          }
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
        onTap: () {},
        icon: BitmapDescriptor.defaultMarker);

    setState(() {
      _markers.add(marker);
    });
  }
}
