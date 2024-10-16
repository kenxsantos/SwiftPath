import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class IncidentReportPage extends StatefulWidget {
  const IncidentReportPage({super.key});

  @override
  _IncidentReportPageState createState() => _IncidentReportPageState();
}

class _IncidentReportPageState extends State<IncidentReportPage> {
  final LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 100,
  );
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController =
      TextEditingController(); // Email controller
  String? _imageUrl;
  File? _image;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserEmail();
  }

  // Fetch user email from Firebase Auth
  Future<void> _fetchUserEmail() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? "";
      _nameController.text = user.displayName ?? "";
    }
  }

  // Method to get the current location of the user
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
    return await Geolocator.getCurrentPosition(
        locationSettings: locationSettings);
  }

  // Method to upload the image to Firebase Storage
  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await showDialog<XFile>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          actions: [
            TextButton(
              child: const Text('Camera'),
              onPressed: () async {
                Navigator.of(context)
                    .pop(await picker.pickImage(source: ImageSource.camera));
              },
            ),
            TextButton(
              child: const Text('Gallery'),
              onPressed: () async {
                Navigator.of(context)
                    .pop(await picker.pickImage(source: ImageSource.gallery));
              },
            ),
          ],
        );
      },
    );

    if (pickedFile != null) {
      setState(() {
        _isUploading = true;
        _image = File(pickedFile.path); // Store the picked image
      });

      String fileName = pickedFile.path.split('/').last;
      Reference storageRef =
          FirebaseStorage.instance.ref().child('incident_images/$fileName');
      await storageRef.putFile(_image!);

      _imageUrl = await storageRef.getDownloadURL();
      setState(() {
        _isUploading = false;
      });
    }
  }

  // Method to report the incident and store it in Firebase Realtime Database
  bool _isLoading = false; // Loading state

  Future<void> _reportIncident() async {
    setState(() {
      _isLoading = true; // Start loading when the process begins
    });

    final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
    Position position;

    try {
      position = await _getCurrentLocation();
    } catch (e) {
      print(e.toString());
      setState(() {
        _isLoading = false; // Stop loading if there's an error
      });
      return;
    }

    String address =
        await _getAddressFromLatLng(position.latitude, position.longitude);
    final Random random = Random();
    int key1 = random.nextInt(900000) + 100000; // 6 digits
    int key2 = random.nextInt(9000) + 1000; // 4 digits
    int incidentKey =
        int.parse('$key1$key2'); // Combining both into a 10-digit key

    const String apiUrl = 'https://api.roam.ai/v1/api/geofence/';
    final String roamAiApiKey =
        dotenv.env['ROAM_AI_API_KEY'] ?? ''; // Firebase reference

    final Map<String, dynamic> geofenceData = {
      "coordinates": [
        position.longitude,
        position.latitude
      ], // Roam expects coordinates in [lon, lat] format
      "geometry_radius": 500, // Define your radius in meters
      "description": "Incident Location",
      "tag": "Incident Report",
      "metadata": {},
      "user_ids": ["6bda16edea01848b3b419163"], // Example user ID
      "group_ids": ["5cda16edea00845b3b419173"], // Example group ID
      "is_enabled": [true, "2021-06-10T18:45:00", "2021-06-10T19:29:00"]
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Api-Key': roamAiApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(geofenceData),
      );

      if (response.statusCode == 201) {
        // Parse the response body
        final Map<String, dynamic> responseData =
            jsonDecode(response.body)['data'];

        // Capture all the data from the response
        final Map<String, dynamic> firebaseGeofenceData = {
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
        };

        // Check if required fields are filled
        if (_nameController.text.isNotEmpty &&
            _emailController.text.isNotEmpty &&
            _detailsController.text.isNotEmpty &&
            _imageUrl != null) {
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

          // Store the geofence data in Firebase
          await dbRef.child('geofences').push().set(firebaseGeofenceData);

          print('Geofence created and stored in Firebase successfully!');

          // Show success dialog
          _showDialog('Success', 'Incident reported successfully!');

          // Clear form fields
          _detailsController.clear();
          _imageUrl = null;
          _image = null;
        } else {
          // Required fields are missing
          _showDialog('Required Fields', 'Please fill all required fields.');
        }
      } else {
        print('Failed to create geofence: ${response.body}');
        _showDialog('Error', 'Failed to create geofence. Please try again.');
      }
    } catch (e) {
      print('Error creating geofence: $e');
      _showDialog('Error', 'An error occurred while creating the geofence.');
    } finally {
      setState(() {
        _isLoading = false; // Stop loading when done
      });
    }
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
      print(e);
      return "Address not available";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Incident')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    labelStyle: TextStyle(fontSize: 16),
                    suffix: Text('*', style: TextStyle(color: Colors.red)),
                  ),
                ),
                TextField(
                  controller: _emailController,
                  readOnly: true, // Set email field to read-only
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: TextStyle(fontSize: 16),
                    suffix: Text('*', style: TextStyle(color: Colors.red)),
                  ),
                ),
                TextField(
                  controller: _detailsController,
                  maxLines: 3, // Make the incident details a textarea
                  decoration: const InputDecoration(
                    labelText: 'Incident Details',
                    labelStyle: TextStyle(fontSize: 16),
                    suffix: Text('*', style: TextStyle(color: Colors.red)),
                  ),
                ),
                GestureDetector(
                  onTap: _uploadImage,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    margin: const EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(5.0),
                      color: _image == null ? Colors.white : Colors.transparent,
                    ),
                    child: _image == null
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, size: 40),
                                SizedBox(height: 8),
                                Text('Upload Image'),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.file(
                              _image!,
                              fit: BoxFit
                                  .cover, // Ensures the image fits within the rectangle
                              width: double.infinity, // Fill the width
                              height: double.infinity, // Fill the height
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : _reportIncident, // Disable button while loading
                  child: const Text('Report Incident'),
                ),
              ],
            ),
          ),
          if (_isLoading) // Show loader and overlay when loading
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
