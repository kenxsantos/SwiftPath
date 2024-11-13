import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftpath/screens/admin/pages/barangay_maps.dart';
import 'package:swiftpath/screens/super_admin/pages/incident_reports.dart';
import 'package:swiftpath/screens/users/pages/edit_profile_page.dart';
import 'package:swiftpath/screens/users/pages/report_history_page.dart';
import 'package:swiftpath/screens/users/pages/report_incident.dart';
import 'package:swiftpath/screens/users/pages/show_routes.dart';
import 'package:swiftpath/screens/admin/pages/emergency_vehicle.dart';
import 'package:swiftpath/views/maps_page.dart';
import 'package:swiftpath/views/splash_screen.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swiftpath/views/landing_page.dart';
import 'package:swiftpath/views/home_page.dart';
import 'package:swiftpath/views/login_page.dart';
import 'package:swiftpath/views/signup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:roam_flutter/roam_flutter.dart';
import 'package:logger/logger.dart';

SharedPreferences? prefs;

void main() async {
  var logger = Logger(
    printer: PrettyPrinter(),
  );
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final String roamAiPublishableKey =
      dotenv.env['ROAM_AI_PUBLISHABLE_KEY'] ?? '';
  if (roamAiPublishableKey.isNotEmpty) {
    Roam.initialize(publishKey: roamAiPublishableKey);
    logger.d('Roam SDK initialized');
  } else {
    logger.e('Roam SDK initialization failed: API key is missing');
  }
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
        '/edit-profile': (context) => const EditProfilePage(),
        '/report-history': (context) => const ReportHistoryPage(),
        '/maps': (context) => const MapScreen(),
        '/splash-screen': (context) => const SplashScreen(),
        '/incident-report': (context) => const ReportIncidentPage(),
        '/emergency-vehicles': (context) => const EmergencyVehicles(),
        '/show-routes': (context) => const ShowRoutes(
              incidentReport: {
                'latitude': 37.7749, // Example latitude (San Francisco)
                'longitude': -122.4194, // Example longitude (San Francisco)
              },
            ),
        '/incident-reports': (context) => const IncidentReportsScreen()
      },
    );
  }
}
