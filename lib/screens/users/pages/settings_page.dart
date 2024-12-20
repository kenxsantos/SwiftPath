import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swiftpath/components/validation.dart';
import 'package:http/http.dart' as http;
import 'package:swiftpath/screens/users/pages/edit_profile_page.dart';
import 'package:swiftpath/screens/users/pages/location_settings.dart';
import 'package:swiftpath/screens/users/pages/report_history_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  String _userName = '';
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _setupUserDataListener();
  }

  void _fetchUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final snapshot = await _dbRef.child('users').child(user.uid).get();
      if (snapshot.exists) {
        setState(() {
          _userName = snapshot.child('name').value as String? ?? '';
          _userEmail = snapshot.child('email').value as String? ?? user.email!;
        });
      } else {
        setState(() {
          _userName = user.displayName ?? 'Unknown User';
          _userEmail = user.email ?? 'Unknown Email';
        });
      }
    }
  }

  void _setupUserDataListener() {
    final user = _auth.currentUser;
    if (user != null) {
      _dbRef.child('users').child(user.uid).onValue.listen((event) {
        final snapshot = event.snapshot;
        if (snapshot.exists) {
          setState(() {
            _userName = snapshot.child('name').value as String? ?? '';
            _userEmail =
                snapshot.child('email').value as String? ?? user.email!;
          });
        }
      });
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    return name.split(' ').map((word) => word[0]).take(2).join().toUpperCase();
  }

  final TextStyle _circleAvatarTextStyle = const TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Colors.redAccent,
  );

  @override
  void dispose() {
    super.dispose();
    final user = _auth.currentUser;
    if (user != null) {
      _dbRef.child('users').child(user.uid).onValue.drain();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.red.shade400,
                      Colors.red.shade800,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Text(
                        _getInitials(_userName),
                        style: _circleAvatarTextStyle,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(_userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        )),
                    Text(
                      _userEmail,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: Text(
                      'Account Settings',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  _buildSettingsCard([
                    _buildSettingsTile(
                      icon: Icons.person,
                      title: 'Profile',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfilePage(),
                        ),
                      ),
                    ),
                    _buildSettingsTile(
                      icon: Icons.pending_actions_outlined,
                      title: 'Report History',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReportHistoryPage(),
                        ),
                      ),
                    ),
                    ListTile(
                      onTap: () => _showLogoutDialog(context),
                      leading: const Icon(Icons.logout,
                          color: Color.fromARGB(255, 224, 59, 59)),
                      title: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: Text(
                      'App Settings',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  _buildSettingsCard([
                    _buildSettingsTile(
                      icon: Icons.more_horiz_outlined,
                      title: 'Location Settings',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LocationSettings(),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> tiles) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: tiles,
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: textColor ?? Colors.red.shade400),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                AuthValidation.signOut(
                  context: context,
                  auth: _auth,
                  googleSignIn: _googleSignIn,
                ); // Perform the logout action
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }
}
