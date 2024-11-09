import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:swiftpath/models/auto_complete_result.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;

class MapServices {
  final String key = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  final String types = 'geocode';

  Future<List<AutoCompleteResult>> searchPlaces(String searchInput) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$searchInput&types=$types&key=$key';

    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var json = convert.jsonDecode(response.body);
      var results = json['predictions'] as List;
      return results.map((e) => AutoCompleteResult.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load predictions');
    }
  }

  Future<Map<String, dynamic>> getPlace(String? input) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$input&key=$key';

    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var json = convert.jsonDecode(response.body);
      var results = json['result'] as Map<String, dynamic>;
      return results;
    } else {
      throw Exception('Failed to load place details');
    }
  }

  Future<Map<String, dynamic>> getDirections(
      String origin, String destination) async {
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$key';

    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var json = convert.jsonDecode(response.body);
      var results = {
        'bounds_ne': json['routes'][0]['bounds']['northeast'],
        'bounds_sw': json['routes'][0]['bounds']['southwest'],
        'start_location': json['routes'][0]['legs'][0]['start_location'],
        'end_location': json['routes'][0]['legs'][0]['end_location'],
        'polyline': json['routes'][0]['overview_polyline']['points'],
        'polyline_decoded': PolylinePoints()
            .decodePolyline(json['routes'][0]['overview_polyline']['points'])
      };

      return results;
    } else {
      throw Exception('Failed to load directions');
    }
  }

  Future<dynamic> getPlaceDetails(LatLng coords, int radius) async {
    var lat = coords.latitude;
    var lng = coords.longitude;

    final String url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?&location=$lat,$lng&radius=$radius&key=$key';

    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var json = convert.jsonDecode(response.body);
      return json;
    } else {
      throw Exception('Failed to load place details');
    }
  }

  Future<dynamic> getMorePlaceDetails(String token) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?&pagetoken=$token&key=$key';

    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var json = convert.jsonDecode(response.body);
      return json;
    } else {
      throw Exception('Failed to load more place details');
    }
  }
}
