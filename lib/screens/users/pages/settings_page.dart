import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swiftpath/components/validation.dart';
import 'package:http/http.dart' as http;
import 'package:swiftpath/screens/users/pages/edit_profile_page.dart';
import 'package:swiftpath/screens/users/pages/history_logs.dart';
import 'package:swiftpath/screens/users/pages/location_settings.dart';
import 'package:swiftpath/screens/users/pages/my_users_page.dart';
import 'package:swiftpath/screens/users/pages/report_history_page.dart';
import 'package:swiftpath/screens/users/pages/sample_map.dart';

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
        backgroundColor: const Color.fromARGB(
            255, 255, 255, 255), // Background color for AppBar
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 50),
          Center(
              child: Column(
            children: [
              const Text(
                'SWIFTPATH',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  color: Color.fromARGB(255, 224, 59, 59), // Title color
                ),
              ),
              Text(_auth.currentUser?.displayName ?? '',
                  style: const TextStyle(
                      fontSize: 18,
                      color: Color.fromARGB(255, 224, 59, 59) // Subtitle color
                      )),
            ],
          )),
          const SizedBox(height: 20),
          ListTile(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const EditProfilePage()));
            },
            leading: const Icon(Icons.person,
                color: Color.fromARGB(255, 224, 59, 59)),
            title: const Text(
              'Profile',
              style: TextStyle(color: Colors.black87),
            ),
          ),
          ListTile(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ReportHistoryPage()));
            },
            leading: const Icon(Icons.pending_actions_outlined,
                color: Color.fromARGB(255, 224, 59, 59)),
            title: const Text(
              'Report History',
              style: TextStyle(color: Colors.black87),
            ),
          ),
          ListTile(
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const HistoryLogs()));
            },
            leading: const Icon(Icons.history,
                color: Color.fromARGB(255, 224, 59, 59)),
            title: const Text(
              'Logs',
              style: TextStyle(color: Colors.black87),
            ),
          ),
          ListTile(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LocationSettings(
                            userId: '67160b86c45da22b6c686977',
                          )));
            },
            leading: const Icon(Icons.more_horiz_outlined,
                color: Color.fromARGB(255, 224, 59, 59)),
            title: const Text(
              'More',
              style: TextStyle(color: Colors.black87),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout,
                color: Color.fromARGB(255, 224, 59, 59)),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.black87),
            ),
            onTap: () => AuthValidation.signOut(
                context: context, auth: _auth, googleSignIn: _googleSignIn),
          ),
          ListTile(
            leading: const Icon(Icons.logout,
                color: Color.fromARGB(255, 224, 59, 59)),
            title: const Text(
              'My Users',
              style: TextStyle(color: Colors.black87),
            ),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const MyUsersPage(
                          title: "Users",
                        ))),
          ),
          ListTile(
            leading: const Icon(Icons.logout,
                color: Color.fromARGB(255, 224, 59, 59)),
            title: const Text(
              'Sample Map',
              style: TextStyle(color: Colors.black87),
            ),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => SampleMapScreen())),
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
