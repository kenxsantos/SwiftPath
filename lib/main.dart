import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftpath/pages/edit_profile_page.dart';
import 'package:swiftpath/pages/my_location_tracking_page.dart';
import 'package:swiftpath/pages/my_subscription_page.dart';
import 'package:swiftpath/pages/my_trips_location.dart';
import 'package:swiftpath/pages/my_user_page.dart';
import 'package:swiftpath/pages/nearest_facility.dart';
import 'package:swiftpath/pages/report_history_page.dart';
import 'package:swiftpath/pages/route_history_page.dart';
import 'package:swiftpath/views/emergency_vehicle.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final String roamAiPublishableKey =
      dotenv.env['ROAM_AI_PUBLISHABLE_KEY'] ?? '';
  if (roamAiPublishableKey.isNotEmpty) {
    Roam.initialize(publishKey: roamAiPublishableKey);
    print('Roam SDK initialized');
  } else {
    print('Roam SDK initialization failed: API key is missing');
  }
  // Roam.initialize(publishKey: roam_ai_api_key);
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
        '/maps': (context) =>
            const MapScreen(origin: 'Manila', destination: 'Quezon City'),
        '/splash-screen': (context) => const SplashScreen(),
        '/incident-report': (context) => const IncidentReportPage(),
        '/emergency-vehicles': (context) => const EmergencyVehicles(),
        '/my-user': (context) => const MyUsersPage(),
        '/my-location-tracking': (context) =>
            const MyLocationTrackingPage(title: "Location Tracking"),
        '/my-subscription': (context) =>
            const MySubcriptionPage(title: "Subscription Page"),
        '/my-trips': (context) => const MyItemsPage(
              title: "My Trips Page",
            ),
        '/nearest-facility': (context) => const NearestFacility(
              latitude: 40.712776, // Replace with dynamic latitude
              longitude: -74.005974, // Replace with dynamic longitude
            ),
      },
    );
  }
}
