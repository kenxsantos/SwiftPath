import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthValidation {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  static void showAlert({
    required BuildContext context,
    required String title,
    required String desc,
    VoidCallback? onPressed,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(desc),
          actions: [
            TextButton(
              onPressed: onPressed ?? () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  static bool validateFields({
    required BuildContext context,
    required String email,
    required String password,
    String? confirmPassword,
  }) {
    if (email.isEmpty ||
        password.isEmpty ||
        (confirmPassword?.isEmpty ?? false)) {
      showAlert(
        context: context,
        title: 'Empty Fields',
        desc: 'Please fill out all fields.',
      );
      return false;
    }

    if (confirmPassword != null && password != confirmPassword) {
      showAlert(
        context: context,
        title: 'Password Mismatch',
        desc: 'Make sure that you write the same password twice.',
      );
      return false;
    }

    return true;
  }

  static Future<void> handleFirebaseSignUp({
    required BuildContext context,
    required FirebaseAuth auth,
    required String email,
    required String password,
    required VoidCallback onSuccess,
    required VoidCallback onFailure,
  }) async {
    final Map<String, String> signUpErrorMessages = {
      'invalid-email': 'The email address is not valid.',
      'email-already-in-use': 'The email address is already in use.',
      'weak-password': 'The password is too weak.',
      'operation-not-allowed': 'Email/password sign up is not enabled.',
      'invalid-credential': 'The credentials are invalid or expired.',
    };

    try {
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // String hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

      // Store user details in Realtime Database
      final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

      // final String roamAiApiKey = dotenv.env['ROAM_AI_API_KEY'] ?? '';
      // // Replace with your Roam.ai API Key
      // var response = await http.post(
      //   Uri.parse('https://api.roam.ai/v1/api/user/'),
      //   headers: {
      //     'Api-Key': roamAiApiKey,
      //     'Content-Type': 'application/json',
      //   },
      //   body: jsonEncode({
      //     "app_type": 1,
      //     "device_token": "token",
      //     "description": "Device description",
      //     "metadata": {}
      //   }),
      // );

      // if (response.statusCode == 201) {
      //   final Map<String, dynamic> responseData =
      //       jsonDecode(response.body)['data'];

      //   final Map<String, dynamic> createUserAPI = {
      //     'email': email,
      //     'password': password,
      //     "user_id": responseData["user_id"],
      //     "app_id": responseData["app_id"],
      //     "geofence_events": responseData["geofence_events"],
      //     "location_events": responseData["location_events"],
      //     "trips_events": responseData["trips_events"],
      //     "nearby_events": responseData["nearby_events"],
      //     "location_listener": responseData["location_listener"],
      //     "event_listener": responseData["event_listener"],
      //     "metadata": {},
      //     "sdk_version": responseData["sdk_version"],
      //     "project_id": responseData["project_id"],
      //     "account_id": responseData["account_id"],
      //   };
      //   await dbRef
      //       .child('users/${userCredential.user?.uid}')
      //       .set(createUserAPI);

      //   print('Roam.ai user created successfully.');
      //   onSuccess();
      // } else {
      //   print('Failed to create Roam.ai user: ${response.body}');
      //   onFailure(); // Call the failure function
      // }

      onSuccess();
    } catch (e) {
      String errorMessage = 'An error occurred. Please try again.';

      if (e is FirebaseAuthException) {
        errorMessage = signUpErrorMessages[e.code] ??
            'An unexpected error occurred: ${e.message}.';
      } else {
        errorMessage = 'An unknown error occurred: ${e.toString()}';
      }
      showAlert(
        context: context,
        title: 'Sign Up Error',
        desc: errorMessage,
      );
      onFailure();
    }
  }

  static Future<void> handleFirebaseLogin({
    required BuildContext context,
    required FirebaseAuth auth,
    required String email,
    required String password,
    required VoidCallback onSuccess,
    required VoidCallback onFailure,
  }) async {
    final Map<String, String> errorMessages = {
      'user-not-found': 'No user found for this email.',
      'wrong-password': 'Wrong password provided.',
      'invalid-email': 'The email address is not valid.',
      'user-disabled': 'The user account has been disabled.',
      'too-many-requests': 'Too many login attempts. Please try again later.',
      'operation-not-allowed': 'Email and password sign-in is not enabled.',
      'invalid-credential': 'The supplied credentials are invalid or expired.',
    };

    try {
      await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      onSuccess();
    } catch (e) {
      String errorMessage = 'An error occurred. Please try again.';

      if (e is FirebaseAuthException) {
        errorMessage = errorMessages[e.code] ??
            'An unexpected error occurred: ${e.message}.';
      } else {
        errorMessage = 'An unknown error occurred: ${e.toString()}';
      }
      showAlert(
        context: context,
        title: 'Login Error',
        desc: errorMessage,
      );
      onFailure();
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      if (_auth.currentUser?.providerData.any((provider) =>
              provider.providerId == GoogleAuthProvider.PROVIDER_ID) ??
          false) {
        await _googleSignIn.signOut();
      }

      await _auth.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print('Sign out failed: $e');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Failed to sign out. Please try again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
