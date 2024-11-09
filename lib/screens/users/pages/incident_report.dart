import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;

class IncidentReportPage extends StatefulWidget {
  const IncidentReportPage({super.key});

  @override
  _IncidentReportPageState createState() => _IncidentReportPageState();
}

class _IncidentReportPageState extends State<IncidentReportPage> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  Marker? _userMarker;

  final LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 100,
  );
  var logger = Logger(
    printer: PrettyPrinter(),
  );
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  File? _image;
  bool _isLoading = false;
  bool _isRequestInProgress = false;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserEmail();
    _getCurrentLocation();
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      _updateUserLocation(position);
    });
  }

  Future<Position> _getCurrentLocation() async {
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
        return Future.error('Location permissions are denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: locationSettings,
    );
    _updateUserLocation(position);
    return await Geolocator.getCurrentPosition(
        locationSettings: locationSettings);
  }

  void _updateUserLocation(Position position) {
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _userMarker = Marker(
        markerId: MarkerId('userLocation'),
        position: _currentLocation!,
        infoWindow: InfoWindow(title: 'Your Location'),
      );
    });

    // Move the map camera to the new location
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(_currentLocation!),
    );
  }

  Future<void> _fetchUserEmail() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? "";
      _nameController.text = user.displayName ?? "";
    }
  }

  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _reportIncident() async {
    if (_isRequestInProgress) {
      return;
    }

    setState(() {
      _isLoading = true; // Start loading when the process begins
      _isRequestInProgress = true; // Indicate a request is in progress
    });

    final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
    Position position;

    try {
      position = await _getCurrentLocation();
    } catch (e) {
      logger.e('Error getting location: $e');
      _handleError();
      return;
    }

    String address;
    try {
      address =
          await _getAddressFromLatLng(position.latitude, position.longitude);
    } catch (e) {
      logger.e('Error getting address: $e');
      _handleError();
      return;
    }

    // Check if required fields are filled
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _detailsController.text.isEmpty ||
        _imageUrl == null) {
      _showDialog('Required Fields', 'Please fill all required fields.');
      _handleError();
      return;
    }

    final int incidentKey = _generateIncidentKey();
    final String roamAiApiKey = dotenv.env['ROAM_AI_API_KEY'] ?? '';
    try {
      final bool isGeofenceCreated = await _createGeofence(
        position,
        roamAiApiKey,
        dbRef,
        incidentKey,
        address,
      );

      if (isGeofenceCreated) {
        logger.i('Geofence created and stored in Firebase successfully!');
        _showDialog('Success', 'Incident reported successfully!');

        // Clear form fields
        _detailsController.clear();
        _imageUrl = null;
        _image = null;
      }
    } catch (e) {
      logger.e('Error creating geofence: $e');
      _showDialog('Error', 'An error occurred while creating the geofence.');
    } finally {
      _handleError(); // Reset loading state
    }
  }

  Future<bool> _createGeofence(Position position, String apiKey,
      DatabaseReference dbRef, int incidentKey, String address) async {
    final Map<String, dynamic> geofenceData = {
      "coordinates": [position.longitude, position.latitude],
      "geometry_radius": 500,
      "description": "Incident Location",
      "tag": "Incident Report",
      "metadata": {},
      "user_ids": ["6bda16edea01848b3b419163"], // Example user ID
      "group_ids": ["5cda16edea00845b3b419173"], // Example group ID
      "is_enabled": [true, "2021-06-10T18:45:00", "2021-06-10T19:29:00"]
    };

    final response = await http.post(
      Uri.parse('https://api.roam.ai/v1/api/geofence/'),
      headers: {
        'Api-Key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(geofenceData),
    );

    if (response.statusCode == 201) {
      final Map<String, dynamic> responseData =
          jsonDecode(response.body)['data'];

      // Store geofence data in Firebase
      await dbRef.child('geofences').push().set({
        "geofence_id": responseData["geofence_id"],
        "geometry_type": responseData["geometry_type"],
        "geometry_radius": responseData["geometry_radius"],
        "geometry_center": responseData["geometry_center"],
        "is_enabled": responseData["is_enabled"],
        "description": responseData["description"],
        "tag": responseData["tag"],
        "metadata": responseData["metadata"],
        "user_ids": responseData["user_ids"],
        "group_ids": responseData["group_ids"],
        "is_deleted": responseData["is_deleted"],
        "created_at": responseData["created_at"],
        "updated_at": responseData["updated_at"],
      });

      // Push incident report data to Firebase
      await dbRef.child('incident-reports/').push().set({
        'geofence_id': responseData["geofence_id"],
        'incident_key': incidentKey,
        'image_url': _imageUrl,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address,
        'details': _detailsController.text,
        'reporter_name': _nameController.text,
        'reporter_email': _emailController.text,
        'status': 'Pending',
        'timestamp': DateTime.now().toIso8601String(),
      });

      return true;
    } else {
      logger.e('Failed to create geofence: ${response.body}');
      return false;
    }
  }

  int _generateIncidentKey() {
    final Random random = Random();
    int key1 = random.nextInt(900000) + 100000;
    int key2 = random.nextInt(9000) + 1000;
    return int.parse('$key1$key2');
  }

  void _handleError() {
    setState(() {
      _isLoading = false;
      _isRequestInProgress = false;
    });
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Incident')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title for the Form
                const Text(
                  "Incident Details",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 225, 59, 59),
                  ),
                ),
                const SizedBox(height: 16),

                // Name Field
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color.fromARGB(255, 224, 59, 59)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Your Name',
                      labelStyle:
                          TextStyle(color: Color.fromARGB(255, 224, 59, 59)),
                      suffix: Text('*', style: TextStyle(color: Colors.red)),
                      border: InputBorder.none,
                    ),
                  ),
                ),

                // Email Field
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color.fromARGB(255, 224, 59, 59)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _emailController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      labelStyle:
                          TextStyle(color: Color.fromARGB(255, 224, 59, 59)),
                      suffix: Text('*', style: TextStyle(color: Colors.red)),
                      border: InputBorder.none,
                    ),
                  ),
                ),

                // Details Field
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color.fromARGB(255, 224, 59, 59)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _detailsController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Incident Details',
                      labelStyle:
                          TextStyle(color: Color.fromARGB(255, 224, 59, 59)),
                      suffix: Text('*', style: TextStyle(color: Colors.red)),
                      border: InputBorder.none,
                    ),
                  ),
                ),

                // Image Upload Area
                GestureDetector(
                  onTap: _uploadImage,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    margin: const EdgeInsets.only(top: 16, bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border.all(
                          color: const Color.fromARGB(
                        255,
                        224,
                        59,
                        59,
                      )),
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _image == null
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo,
                                    color: Color.fromARGB(255, 224, 59, 59),
                                    size: 40),
                                SizedBox(height: 8),
                                Text('Upload Image',
                                    style: TextStyle(
                                        color:
                                            Color.fromRGBO(255, 59, 59, 59))),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.file(
                              _image!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                  ),
                ),

                // Report Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _reportIncident,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color.fromARGB(
                          255, 224, 59, 59), // Button background color
                      foregroundColor: const Color.fromARGB(
                          255, 255, 255, 255), // Text color
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Report Incident'),
                  ),
                ),
              ],
            ),
          ),

          // Loader Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  semanticsLabel: 'Reporting Incident, Please wait...',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
