import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _profilePictureUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchUserEmail();
  }

  Future<void> _fetchUserEmail() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      List<String> nameParts = user.displayName!.split(' ');

      String firstName = nameParts.isNotEmpty ? nameParts[0] : '';
      String lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      _emailController.text = user.email ?? "";
      _fullNameController.text = user.displayName ?? "";
    }
  }

  // Function to validate email format using RegExp
  bool _isValidEmail(String email) {
    // Basic email validation
    final RegExp emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return emailRegex.hasMatch(email);
  }

  Future<void> _reauthenticateAndUpdateProfile(
      String email, String password) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        // Re-authenticate
        AuthCredential credential =
            EmailAuthProvider.credential(email: email, password: password);
        await user.reauthenticateWithCredential(credential);

        // Update email if it's different from current email
        if (_emailController.text.isNotEmpty &&
            _emailController.text != user.email) {
          // Update Firebase Authentication email
          await user.verifyBeforeUpdateEmail(_emailController.text);
          // Optionally, verify the new email with Firebase's verifyBeforeUpdateEmail()
          // await user.verifyBeforeUpdateEmail(_emailController.text);
        }

        // Update password if it's not empty
        if (_passwordController.text.isNotEmpty) {
          await user.updatePassword(_passwordController.text);
        }

        // Update the Realtime Database (excluding password)
        DatabaseReference userRef = _dbRef.child('users/${user.uid}');
        await userRef.update({
          'fullname': _fullNameController.text,
          'email': _emailController.text, // Also update email in the database
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      } catch (e) {
        print('Error updating profile: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _showReauthDialog() async {
    TextEditingController emailController = TextEditingController();
    TextEditingController passwordController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Re-authenticate'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Re-authenticate'),
              onPressed: () async {
                // Attempt re-authentication with the provided email and password
                await _reauthenticateAndUpdateProfile(
                    emailController.text, passwordController.text);
                Navigator.of(context)
                    .pop(); // Close the dialog after successful re-authentication
              },
            ),
          ],
        );
      },
    );
  }

  void _onSavePressed() {
    String email = _emailController.text;

    // Check if email is valid before proceeding
    if (_isValidEmail(email)) {
      // If email is valid, show re-authentication dialog
      _showReauthDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid email format')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context); // Cancel button action
          },
          icon: const Icon(
            Icons.arrow_back_ios_outlined,
            color: Colors.blue,
            size: 24,
          ),
        ),
        title: const Center(
          child: Text('Edit Profile'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9.0),
            child: TextButton(
              onPressed: _onSavePressed, // Save button action
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Picture Section
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundImage: _profilePictureUrl != null
                          ? NetworkImage(_profilePictureUrl!)
                          : const AssetImage('assets/images/imgdefault.png')
                              as ImageProvider,
                      backgroundColor: Colors.grey.shade300,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          // Implement picture upload/change logic here
                        },
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey.shade800,
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Form Fields for user information
              const SizedBox(height: 10),
              TextField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: const TextStyle(fontSize: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(fontSize: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(fontSize: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      // Load user data from Firebase Database
      DatabaseReference userRef = _dbRef.child('users/${user.uid}');
      DataSnapshot snapshot = (await userRef.once()) as DataSnapshot;
      if (snapshot.exists) {
        var data = snapshot.value as Map<dynamic, dynamic>;
        _fullNameController.text = data['fullname'] ?? '';
        _emailController.text = user.email ?? '';
        _profilePictureUrl = data['profilePictureUrl'];
        setState(() {});
      }
    }
  }
}
