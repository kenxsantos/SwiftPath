import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

void main() => runApp(const MaterialApp(home: SignUserPage()));

class SignUserPage extends StatefulWidget {
  const SignUserPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUserPage> {
  bool _savePassword = false;
  String _selectedRole = "Emergency Respondents"; // State variable for selected role

  @override
  Widget build(BuildContext context) {
    // Get screen width and height
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Background image container
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/mapbg.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Semi-transparent overlay for dimming
          Container(
            color: Colors.black.withOpacity(0.7),
          ),
          // Sign-up form content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // SwiftPath logo and name
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FontAwesomeIcons.truckMedical,
                        size: screenHeight * 0.07,
                        color: const Color.fromARGB(255, 228, 46, 46),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'SWIFTPATH',
                        style: TextStyle(
                          fontSize: screenWidth * 0.07,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Heading Text
                  const Text(
                    "Choose Your Path: Everyday Explorer or Emergency Hero",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Toggle buttons for user selection
                  ToggleButtons(
                    borderRadius: BorderRadius.circular(8),
                    fillColor: Colors.redAccent,
                    selectedColor: Colors.white,
                    color: Colors.white,
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Text("Emergency Respondents"),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Text("General User"),
                      ),
                    ],
                    isSelected: [
                      _selectedRole == "Emergency Respondents",
                      _selectedRole == "General User"
                    ],
                    onPressed: (int index) {
                      setState(() {
                        _selectedRole = (index == 0)
                            ? "Emergency Respondents"
                            : "General User";
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Email text field
                  TextField(
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.black),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.email, color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Password text field
                  TextField(
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.black),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.lock, color: Colors.black),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  // Save password checkbox and forgot password link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _savePassword,
                            onChanged: (bool? value) {
                              setState(() {
                                _savePassword = value ?? false;
                              });
                            },
                            activeColor: Colors.red,
                            checkColor: Colors.white,
                          ),
                          const Text(
                            "Save password",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          // Handle forgot password
                        },
                        child: const Text(
                          "Forgot password?",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Create account button
                  ElevatedButton(
                    onPressed: () {
                      // Handle sign-up logic here
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Divider with 'Or'
                  Row(
                    children: const [
                      Expanded(
                        child: Divider(
                          color: Colors.white,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          "Or",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.white,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Google sign-in button
                  ElevatedButton.icon(
                    onPressed: () {
                      // Handle Google sign-in
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: Colors.white,
                    ),
                    icon: const Icon(
                      FontAwesomeIcons.google,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Sign up using your Google Account',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
