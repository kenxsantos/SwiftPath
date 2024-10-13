import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftpath/pages/edit_profile_page.dart';
import 'package:swiftpath/pages/nearest_facility.dart';
import 'package:swiftpath/pages/report_history_page.dart';
import 'package:swiftpath/pages/route_history_page.dart';
import 'package:swiftpath/views/maps_page.dart';
import 'package:swiftpath/views/splash_screen.dart';
import 'package:swiftpath/pages/incident_report.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swiftpath/pages/landing_page.dart';
import 'package:swiftpath/pages/home_page.dart';
import 'package:swiftpath/pages/login_page.dart';
import 'package:swiftpath/pages/signup_page.dart';
import 'package:swiftpath/pages/dashboard_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:roam_flutter/roam_flutter.dart';

SharedPreferences? prefs;
final String roam_ai_api_key = dotenv.env['ROAM_AI_API_KEY'] ?? '';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  Roam.initialize(publishKey: roam_ai_api_key);

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
        '/incident-report': (context) => const IncidentReportPage(),
        '/nearest-facility': (context) => const NearestFacility(
              latitude: 40.712776, // Replace with dynamic latitude
              longitude: -74.005974, // Replace with dynamic longitude
            ),
      },
    );
  }
}
