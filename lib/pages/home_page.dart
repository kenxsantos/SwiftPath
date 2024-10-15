import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:swiftpath/components/components.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatelessWidget {
  HomePage({super.key});
  static String id = 'home_page';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final GoogleUser = await _googleSignIn.signIn();
      if (GoogleUser == null) {
        // User cancelled the sign-in
        return;
      }

      final GoogleAuth = await GoogleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: GoogleAuth.accessToken,
        idToken: GoogleAuth.idToken,
      );

      // Sign in to Firebase
      UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user == null) {
        print('Error: User credential is null.');
        return;
      }

      // Set up database reference
      final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
      final String roamAiApiKey = dotenv.env['ROAM_AI_API_KEY'] ?? '';

      // Make the API call to Roam.ai
      var response = await http.post(
        Uri.parse('https://api.roam.ai/v1/api/user/'),
        headers: {
          'Api-Key': roamAiApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "app_type": 1,
          "device_token": "token", // Consider using a real token
          "description": "Device description",
          "metadata": {}
        }),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData =
            jsonDecode(response.body)['data'];

        // Prepare user data to save in Firebase
        final Map<String, dynamic> createUserAPI = {
          'email': user.email,
          "user_id": responseData["user_id"],
          "app_id": responseData["app_id"],
          "geofence_events": responseData["geofence_events"],
          "location_events": responseData["location_events"],
          "trips_events": responseData["trips_events"],
          "nearby_events": responseData["nearby_events"],
          "location_listener": responseData["location_listener"],
          "event_listener": responseData["event_listener"],
          "metadata": {},
          "sdk_version": responseData["sdk_version"],
          "project_id": responseData["project_id"],
          "account_id": responseData["account_id"],
        };

        // Store user data using UID
        await dbRef.child('users/${user.uid}').set(createUserAPI);

        print('Roam.ai user created successfully.');
      } else {
        print('Failed to create Roam.ai user: ${response.body}');
      }

      // Navigate to the splash screen
      Navigator.pushReplacementNamed(context, '/splash-screen');
    } catch (e) {
      print('Sign in failed: $e');
      _showErrorDialog(context, e.toString());
    }
  }

  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign In Error'),
          content: Text('An error occurred: $error'),
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

  Future<bool> _checkIfLoggedIn() async {
    final user = _auth.currentUser;
    return user != null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkIfLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/splash-screen');
          });
        }
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TopScreenImage(screenImageName: 'ambulance.png'),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                          right: 15.0, left: 15, bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          const ScreenTitle(title: 'SwiftPath'),
                          Text(
                            'Speeding Aid to Save Lives',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 20),
                          ),
                          const SizedBox(height: 15),
                          Hero(
                            tag: 'login_btn',
                            child: CustomButton(
                              buttonText: 'Login',
                              onPressed: () {
                                Navigator.pushNamed(context, '/login');
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          Hero(
                            tag: 'signup_btn',
                            child: CustomButton(
                              buttonText: 'Sign Up',
                              isOutlined: true,
                              onPressed: () {
                                Navigator.pushNamed(context, '/signup');
                              },
                            ),
                          ),
                          const SizedBox(height: 25),
                          const Text(
                            'Sign up using',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed: () => _signInWithGoogle(context),
                                icon: CircleAvatar(
                                  radius: 25,
                                  backgroundColor: Colors.transparent,
                                  child: Image.asset(
                                      'assets/images/icons/google.png'),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
