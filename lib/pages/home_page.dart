import 'package:flutter/material.dart';
import 'package:swiftpath/components/components.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:swiftpath/components/validation.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});
  static String id = 'home_page';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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
                                onPressed: () =>
                                    AuthValidation.signInWithGoogle(
                                        context: context,
                                        auth: _auth,
                                        googleSignIn: _googleSignIn),
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
