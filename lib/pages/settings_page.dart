import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _signOut(BuildContext context) async {
    try {
      // Check if the user signed in using Google
      if (_auth.currentUser?.providerData.any((provider) =>
              provider.providerId == GoogleAuthProvider.PROVIDER_ID) ??
          false) {
        await _googleSignIn.signOut(); // Sign out from Google
      }

      // Sign out from Firebase
      await _auth.signOut();

      // Redirect to the login screen after sign-out
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      // Handle sign-out errors
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 50),
          Center(
            child: Text(
              'SWIFTPATH ${_auth.currentUser?.displayName ?? ''}!',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 30,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            onTap: () {
              Navigator.pushNamed(context, '/edit-profile');
            },
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
          ),
          ListTile(
            onTap: () {
              Navigator.pushNamed(context, '/route-history');
            },
            leading: const Icon(Icons.history),
            title: const Text('Route History'),
          ),
          ListTile(
            onTap: () {
              Navigator.pushNamed(context, '/report-history');
            },
            leading: const Icon(Icons.pending_actions_outlined),
            title: const Text('Report History'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => _signOut(context), // Logout action
          ),
          ListTile(
            leading: const Icon(Icons.more),
            title: const Text('My User'),
            onTap: () {
              Navigator.pushNamed(context, '/my-user');
            },
          ),
          ListTile(
            leading: const Icon(Icons.more),
            title: const Text('My Location Tracking'),
            onTap: () {
              Navigator.pushNamed(context, '/my-location-tracking');
            },
          ),
          ListTile(
            leading: const Icon(Icons.more),
            title: const Text('My Subscription'),
            onTap: () {
              Navigator.pushNamed(context, '/my-subscription');
            },
          ),
        ],
      ),
    );
  }
}
