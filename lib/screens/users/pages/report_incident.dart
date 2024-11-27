import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ReportIncidentPage extends StatefulWidget {
  const ReportIncidentPage({super.key});

  @override
  _ReportIncidentPageState createState() => _ReportIncidentPageState();
}

class _ReportIncidentPageState extends State<ReportIncidentPage> {
  final LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 100,
  );
  var logger = Logger(
    printer: PrettyPrinter(),
  );

  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController =
      TextEditingController(); // Email controller
  String? _imageUrl;
  File? _image;
  bool _isUploading = false;
  bool _isLoading = false;
  bool _isRequestInProgress = false;

  @override
  void initState() {
    super.initState();
    _fetchUserEmail();
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
    return await Geolocator.getCurrentPosition(
        locationSettings: locationSettings);
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

  Future<void> _submitReport() async {
    final Position position = await _getCurrentLocation();
    String address =
        await _getAddressFromLatLng(position.latitude, position.longitude);

    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      if (!_validateInputs()) {
        _showDialog('Errors', 'Please fill in all fields.');
        return;
      }
      final payload = {
        "latitude": position.latitude,
        "longitude": position.longitude,
        "address": address,
        "details": _detailsController.text,
        "status": 'Pending',
        "reporter_email": _emailController.text,
        "reporter_name": _nameController.text,
        "timestamp": DateTime.now().toIso8601String(),
        "image_url": _imageUrl ?? "No Image",
      };

      // Send to backend
      final String backendUrl = dotenv.env['SOCKET_URL'] ?? '';
      final response = await http.post(
        Uri.parse('$backendUrl/report-incident'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );
      print("Response: ${response.body}");

      if (response.statusCode == 200) {
        print("Report submitted successfully: ${response.body}");
        _onReportSuccess();
      } else {
        print(
            "Failed to submit report: ${response.body} ${response.statusCode}");
        _showDialog('Error', 'Failed to submit the report. Please try again.');
      }
    } catch (e) {
      print("Error submitting report: $e");
      _showDialog('Error', 'An error occurred. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onReportSuccess() {
    _showDialog('Success', 'Incident reported successfully!');
    _resetForm();
  }

  bool _validateInputs() {
    return _emailController.text.isNotEmpty && _imageUrl != null;
  }

  void _resetForm() {
    setState(() {
      _imageUrl = null;
      _image = null;
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
                    onPressed: _isLoading ? null : _submitReport,
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
