import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';

import 'package:location/location.dart' as loc;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

class IncidentReportPage extends StatefulWidget {
  const IncidentReportPage({super.key});

  @override
  _IncidentReportPageState createState() => _IncidentReportPageState();
}

class _IncidentReportPageState extends State<IncidentReportPage> {
  LocationData? _locationData;
  String? _address;
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String? _imageUrl;
  bool _isUploading = false;

  // Method to get the current location of the user
  Future<void> _getCurrentLocation() async {
    final location = loc.Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    _locationData = await location.getLocation();
    setState(() {});
  }

  // Method to upload the image to Firebase Storage
  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _isUploading = true;
      });

      // Upload image to Firebase Storage
      String fileName = pickedFile.path.split('/').last;
      Reference storageRef =
          FirebaseStorage.instance.ref().child('incident_images/$fileName');
      await storageRef.putFile(File(pickedFile.path));

      // Get the image URL
      _imageUrl = await storageRef.getDownloadURL();
      setState(() {
        _isUploading = false;
      });
    }
  }

  // Method to report the incident and store it in Firebase Realtime Database
  Future<void> _reportIncident() async {
    final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

    // Get the location if not already fetched
    if (_locationData == null) {
      await _getCurrentLocation();
    }

    if (_imageUrl != null && _locationData != null) {
      // Push the incident data to the Realtime Database
      await dbRef.child('incident-report/').push().set({
        'image_url': _imageUrl,
        'latitude': _locationData!.latitude,
        'longitude': _locationData!.longitude,
        'address': _address, // Optionally get address using reverse geocoding
        'details': _detailsController.text,
        'reporter_name': _nameController.text,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Incident reported successfully!'),
      ));

      // Clear the form after submission
      _nameController.clear(); // Reset reporter name
      _detailsController.clear(); // Reset incident details
      _imageUrl = null; // Reset image URL
      _locationData = null; // Optionally reset location data
      _address = null; // Optionally reset address

      setState(() {});
    } else {
      // Show an error message if details are missing
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to report incident. Please fill all details.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Incident')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Your Name'),
            ),
            TextField(
              controller: _detailsController,
              decoration: const InputDecoration(labelText: 'Incident Details'),
            ),
            ElevatedButton(
              onPressed: _uploadImage,
              child: _isUploading
                  ? const CircularProgressIndicator()
                  : const Text('Upload Image'),
            ),
            ElevatedButton(
              onPressed: _reportIncident,
              child: const Text('Report Incident'),
            ),
          ],
        ),
      ),
    );
  }
}
