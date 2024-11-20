import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AdminMapPage extends StatefulWidget {
  @override
  _AdminMapPageState createState() => _AdminMapPageState();
}

class _AdminMapPageState extends State<AdminMapPage> {
  final LatLng _geofenceCenter = const LatLng(14.501900, 120.997013);
  final double _geofenceRadius = 500.0; // in meters

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Map")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _geofenceCenter,
          zoom: 16.0,
        ),
        circles: {
          Circle(
            circleId: const CircleId("geofence_circle"),
            center: _geofenceCenter,
            radius: _geofenceRadius,
            strokeColor: Colors.blue,
            fillColor: Colors.blue.withOpacity(0.2),
          ),
        },
      ),
    );
  }
}
