import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: ThankyouPage()));

class ThankyouPage extends StatelessWidget {
  const ThankyouPage({super.key});

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
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.9),
                  ),
                ),
                // Ambulance image
                Positioned(
                  child: Image.asset(
                    'assets/images/ambulance.png',
                    width: 270, // Adjust the size of the image
                    height: 200, // Adjust the size of the image
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
          ),

          // Bottom-aligned text
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 80.0), // Adjusted bottom padding
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Thank you for your coordination.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Your report can save a life!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      
                    ),
                    textAlign: TextAlign.center,
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
