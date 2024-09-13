import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: SignUpPage()));

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool _savePassword = false; // State variable for "Save Password" checkbox

  @override
  Widget build(BuildContext context) {
    // Get screen width and height

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
          // Background color overlay
          Container(
            color: const Color.fromARGB(255, 43, 39, 39).withOpacity(0.4),
          ),
          // Semi-transparent overlay for further dimming
          Container(
            color: Colors.black.withOpacity(0.7),
          ),
          // Sign-up form
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ambulance Icon and SwiftPath Text
                  Positioned(
                  // Adjust this value to control the overlap
                  child: Image.asset(
                    'assets/images/Ambulance_icon.png',
                    width: 190, // Adjust the size of the image
                    height: 90, // Adjust the size of the image
                    fit: BoxFit.cover,
                  ),
                ),       
                  const SizedBox(height: 10), // Spacing between SwiftPath text and form
                  // Form content
                  const Text(
                    'Emergency Responders',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // White text color
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    style:
                        const TextStyle(color: Color.fromARGB(255, 43, 43, 43)),
                    decoration: InputDecoration(
                      filled: true, // Enable background filling
                      fillColor:
                          Colors.white, // Set the background color to white
                      labelText: 'Name',
                      labelStyle: const TextStyle(
                          color: Color.fromARGB(255, 43, 43, 43)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.person,
                          color: Color.fromARGB(255, 43, 43, 43)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    style:
                        const TextStyle(color: Color.fromARGB(255, 43, 43, 43)),
                    decoration: InputDecoration(
                      filled: true, // Enable background filling
                      fillColor:
                          Colors.white, // Set the background color to white
                      labelText: 'Hospital/Clinic Name',
                      labelStyle: const TextStyle(
                          color: Color.fromARGB(255, 43, 43, 43)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.local_hospital,
                          color: Color.fromARGB(255, 43, 43, 43)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    style:
                        const TextStyle(color: Color.fromARGB(255, 43, 43, 43)),
                    decoration: InputDecoration(
                      filled: true, // Enable background filling
                      fillColor:
                          Colors.white, // Set the background color to white
                      labelText: 'Password',
                      labelStyle: const TextStyle(
                          color: Color.fromARGB(255, 43, 43, 43)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.lock,
                          color: Color.fromARGB(255, 43, 43, 43)),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
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
                            checkColor: Colors.white, // White checkbox tick
                            activeColor:
                                Colors.red, // Checkbox background color
                          ),
                          const Text(
                            "Save Password",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          // Handle "Forgot Password?" action
                        },
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: Colors.white, // White link color
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
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
                      backgroundColor: const Color.fromARGB(
                          255, 143, 46, 39), // Button color
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
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}