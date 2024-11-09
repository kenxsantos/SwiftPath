import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NearestFacility extends StatelessWidget {
  final double latitude;
  final double longitude;

  const NearestFacility(
      {super.key, required this.latitude, required this.longitude});

  Future<void> findNearestHospital() async {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    String url =
        "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=5000&type=hospital&key=$apiKey";

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      var results = jsonResponse['results'];
      if (results.isNotEmpty) {
        var nearestHospital = results[0];
        var name = nearestHospital['name'];
        var address = nearestHospital['vicinity'];
        print("Nearest Hospital: $name, Address: $address");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearest Emergency Facility')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(latitude, longitude),
          zoom: 14.0,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('incidentLocation'),
            position: LatLng(latitude, longitude),
          ),
        },
      ),
    );
  }
}
