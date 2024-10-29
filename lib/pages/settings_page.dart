import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swiftpath/components/validation.dart';
import 'package:http/http.dart' as http;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255), // Background color for AppBar
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 50),
          Center(
            child: Text(
              'SWIFTPATH ${_auth.currentUser?.displayName ?? ''}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 28,
                color: Color.fromARGB(255, 224, 59, 59), // Title color
              ),
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            onTap: () {
              Navigator.pushNamed(context, '/edit-profile');
            },
            leading: const Icon(Icons.person, color: Color.fromARGB(255, 224, 59, 59)),
            title: const Text(
              'Profile',
              style: TextStyle(color: Colors.black87),
            ),
          ),
          ListTile(
            onTap: () {
              Navigator.pushNamed(context, '/route-history');
            },
            leading: const Icon(Icons.history, color: Color.fromARGB(255, 224, 59, 59)),
            title: const Text(
              'Route History',
              style: TextStyle(color: Colors.black87),
            ),
          ),
          ListTile(
            onTap: () {
              Navigator.pushNamed(context, '/report-history');
            },
            leading: const Icon(Icons.pending_actions_outlined, color:Color.fromARGB(255, 224, 59, 59)),
            title: const Text(
              'Report History',
              style: TextStyle(color: Colors.black87),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Color.fromARGB(255, 224, 59, 59)),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.black87),
            ),
            onTap: () => AuthValidation.signOut(
              context: context, auth: _auth, googleSignIn: _googleSignIn),
          ),
          ListTile(
            leading: const Icon(Icons.more, color: Color.fromARGB(255, 224, 59, 59)),
            title: const Text(
              'My User',
              style: TextStyle(color: Colors.black87),
            ),
            onTap: () {
              Navigator.pushNamed(context, '/my-user');
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_on, color: Color.fromARGB(255, 224, 59, 59)),
            title: const Text(
              'My Location Tracking',
              style: TextStyle(color: Colors.black87),
            ),
            onTap: () {
              Navigator.pushNamed(context, '/my-location-tracking');
            },
          ),
          ListTile(
            leading: const Icon(Icons.subscriptions, color: Color.fromARGB(255, 224, 59, 59)),
            title: const Text(
              'My Subscription',
              style: TextStyle(color: Colors.black87),
            ),
            onTap: () {
              Navigator.pushNamed(context, '/my-subscription');
            },
          ),
          ListTile(
            leading: const Icon(Icons.trip_origin, color: Color.fromARGB(255, 224, 59, 59)),
            title: const Text(
              'My Trips',
              style: TextStyle(color: Colors.black87),
            ),
            onTap: () {
              Navigator.pushNamed(context, '/my-trips');
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Color.fromARGB(255, 224, 59, 59)),
            title: const Text(
              'Create Trip',
              style: TextStyle(color: Colors.black87),
            ),
            onTap: () {
              _createTrip();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _createTrip() async {
    final Map<String, dynamic> geofenceData = {
      "user_id": "67160b86c45da22b6c686977",
      "is_started": true,
      "origins": [
        [120.9980341, 14.4960702]
      ],
      "destinations": [
        [120.993528, 14.483879]
      ]
    };

    final response = await http.post(
      Uri.parse('https://api.roam.ai/v1/api/trips/'),
      headers: {
        'Api-key': "10f984325931446ea8e54d6a76c44037",
        'Content-Type': 'application/json',
      },
      body: jsonEncode(geofenceData),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      print("Trip created successfully: ${response.body}");
    } else {
      print("Failed to create trip: ${response.statusCode}, ${response.body}");
    }
  }
}
