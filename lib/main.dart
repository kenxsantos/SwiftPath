import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftpath/pages/edit_profile_page.dart';
import 'package:swiftpath/pages/report_history_page.dart';
import 'package:swiftpath/pages/route_history_page.dart';
import 'package:swiftpath/views/maps_page.dart';
import 'package:swiftpath/views/splash_screen.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swiftpath/pages/landing_page.dart';
import 'package:swiftpath/pages/home_page.dart';
import 'package:swiftpath/pages/login_page.dart';
import 'package:swiftpath/pages/signup_page.dart';
import 'package:swiftpath/pages/dashboard_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

SharedPreferences? prefs;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwiftPath',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: const LandingPage(),
      routes: {
        '/landing': (context) => const LandingPage(),
        '/homepage': (context) => HomePage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/edit-profile': (context) => const EditProfilePage(),
        '/route-history': (context) => const RouteHistoryPage(),
        '/report-history': (context) => const ReportHistoryPage(),
        '/maps': (context) => const MapScreen(),
        '/splash-screen': (context) => const SplashScreen(),
      },
    );
  }
}
