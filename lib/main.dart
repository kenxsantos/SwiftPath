import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:swiftpath/pages/edit_profile_page.dart';
import 'firebase_options.dart'; // Import the generated file
import 'package:google_fonts/google_fonts.dart';

import 'package:swiftpath/pages/landing_page.dart';
import 'package:swiftpath/pages/home_page.dart';
import 'package:swiftpath/pages/login_page.dart';
import 'package:swiftpath/pages/signup_page.dart';
import 'package:swiftpath/pages/dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SwiftPath',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        textTheme: GoogleFonts.poppinsTextTheme(
          // Using Google Fonts throughout the app
          Theme.of(context).textTheme,
        ),
      ),
      home: const LandingPage(),
      routes: {
        '/landing': (context) => const LandingPage(),
        '/homepage': (context) => HomePage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/dashboard': (context) => DashboardPage(),
        '/edit_profile': (context) => const EditProfilePage()
      },
    );
  }
}
