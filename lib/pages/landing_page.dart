import 'package:flutter/material.dart';
import 'package:swiftpath/pages/signup_page.dart';

void main() => runApp(const MaterialApp(home: LandingPage()));

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
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

          // Semi-transparent overlay at the bottom
          Container(
            alignment: Alignment.bottomCenter,
            color: Colors.black.withOpacity(0.5),
          ),

          // Center circle with an overlapping ambulance image
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Circle container
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(1),
                  ),
                ),
                // Ambulance image
                Positioned(
                  // Adjust this value to control the overlap
                  child: Image.asset(
                    'assets/images/ambulance.png',
                    width: 250, // Adjust the size of the image
                    height: 200, // Adjust the size of the image
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
          ),

          // Bottom-aligned text with click functionality
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {
                // Navigate to the new page when tapped
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignUpPage()),
                );
              },
              child: Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(183, 255, 0, 0).withOpacity(1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.all(10.0),
                child: const Center(
                  child: Text(
                    "GET STARTED",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Montserrat",
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
