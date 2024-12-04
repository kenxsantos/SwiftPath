import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GoogleDirectionsService {
  final String apiKey;

  GoogleDirectionsService(this.apiKey);

  Future<List<Map<String, dynamic>>> fetchRoutes({
    required LatLng origin,
    required LatLng destination,
    bool alternatives = true,
  }) async {
    final String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&alternatives=$alternatives&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          return data['routes'].map<Map<String, dynamic>>((route) {
            return {
              'summary': route['summary'],
              'distance': route['legs'][0]['distance']['text'],
              'duration': route['legs'][0]['duration']['text'],
              'start_address': route['legs'][0]['start_address'],
              'end_address': route['legs'][0]['end_address'],
              'overview_polyline': route['overview_polyline']['points'],
              'steps':
                  route['legs'][0]['steps'].map<Map<String, dynamic>>((step) {
                return {
                  'instruction': step['html_instructions'],
                  'distance': step['distance']['text'],
                  'duration': step['duration']['text'],
                  'polyline': step['polyline']['points'],
                };
              }).toList(),
            };
          }).toList();
        } else {
          throw Exception(
              'Error fetching directions: ${data['error_message']}');
        }
      } else {
        throw Exception(
            'Failed to fetch directions. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching routes: $e');
    }
  }

  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}
