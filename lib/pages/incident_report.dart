import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final TextEditingController _emailController =
      TextEditingController(); // Email controller
  String? _imageUrl;
  File? _image; // Store the selected image file
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserEmail(); // Fetch email when the page initializes
  }

  // Fetch user email from Firebase Auth
  Future<void> _fetchUserEmail() async {
    User? user =
        FirebaseAuth.instance.currentUser; // Get the currently logged-in user
    if (user != null) {
      _emailController.text = user.email ?? "";
      _nameController.text =
          user.displayName ?? ""; // Set the email in the text field
    }
  }

  // Method to get the current location of the user
  Future<void> _getCurrentLocation() async {
    final location = Location();

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
    // Allow user to choose directly from camera or gallery
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

      // Upload image to Firebase Storage
      String fileName = pickedFile.path.split('/').last;
      Reference storageRef =
          FirebaseStorage.instance.ref().child('incident_images/$fileName');
      await storageRef.putFile(_image!);

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

    if (_nameController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _detailsController.text.isNotEmpty &&
        _imageUrl != null) {
      // Push the incident data to the Realtime Database
      await dbRef.child('incident-reports/').push().set({
        'image_url': _imageUrl,
        'latitude': _locationData!.latitude,
        'longitude': _locationData!.longitude,
        'address': _address, // Optionally get address using reverse geocoding
        'details': _detailsController.text,
        'reporter_name': _nameController.text,
        'reporter_email': _emailController.text, // Include email in the report
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Show a success message
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Success'),
            content: const Text('Incident reported successfully!'),
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

      // Clear the form after submission
      _nameController.clear(); // Reset reporter name
      _detailsController.clear(); // Reset incident details
      _imageUrl = null; // Reset image URL
      _image = null; // Reset image file
      _locationData = null; // Optionally reset location data
      _address = null; // Optionally reset address

      setState(() {});
    } else {
      // Show an alert dialog if required fields are missing
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Required Fields'),
            content: const Text('Please fill all required fields.'),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                labelStyle: TextStyle(
                  fontSize: 16,
                ),
                suffix: Text(
                  '*',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            ),
            TextField(
              controller: _emailController,
              readOnly: true, // Set email field to read-only
              decoration: const InputDecoration(
                labelText: 'Email Address',
                labelStyle: TextStyle(
                  fontSize: 16,
                ),
                suffix: Text(
                  '*',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            ),
            TextField(
              controller: _detailsController,
              maxLines: 3, // Make the incident details a textarea
              decoration: const InputDecoration(
                labelText: 'Incident Details',
                labelStyle: TextStyle(
                  fontSize: 16,
                ),
                suffix: Text(
                  '*',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
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
              onPressed:
                  _reportIncident, // Always allow the button to be pressed
              child: const Text('Report Incident'),
            ),
          ],
        ),
      ),
    );
  }
}
