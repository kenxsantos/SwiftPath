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
                        _auth.currentUser?.displayName
                                ?.substring(0, 1)
                                .toUpperCase() ??
                            'U',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _auth.currentUser?.displayName ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _auth.currentUser?.email ?? '',
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
            child: Column(
              children: [
                const SizedBox(height: 20),
                ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfilePage(),
                      ),
                    );
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
                        builder: (context) => const ReportHistoryPage(),
                      ),
                    );
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HistoryLogs(),
                      ),
                    );
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
                        builder: (context) => const LocationSettings(),
                      ),
                    );
                  },
                  leading: const Icon(Icons.more_horiz_outlined,
                      color: Color.fromARGB(255, 224, 59, 59)),
                  title: const Text(
                    'More',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
                ListTile(
                  onTap: () => AuthValidation.signOut(
                    context: context,
                    auth: _auth,
                    googleSignIn: _googleSignIn,
                  ),
                  leading: const Icon(Icons.logout,
                      color: Color.fromARGB(255, 224, 59, 59)),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ],
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
                      icon: Icons.history,
                      title: 'Logs',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HistoryLogs(),
                        ),
                      ),
                    ),
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
                    _buildSettingsTile(
                      icon: Icons.group,
                      title: 'My Users',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const MyUsersPage(title: "Users"),
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
}
