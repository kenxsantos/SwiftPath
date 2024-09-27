
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:swiftpath/pages/edit_profile_page.dart';
import 'package:swiftpath/pages/report_history_page.dart';
import 'package:swiftpath/pages/route_history_page.dart';
import 'firebase_options.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swiftpath/pages/landing_page.dart';
import 'package:swiftpath/pages/home_page.dart';
import 'package:swiftpath/pages/login_page.dart';
import 'package:swiftpath/pages/signup_page.dart';
import 'package:swiftpath/pages/dashboard_page.dart';
import 'package:swiftpath/pages/maps_page.dart';
import 'package:swiftpath/common/globs.dart';
import 'package:swiftpath/common/location_manager.dart';
import 'package:swiftpath/common/my_http_overrides.dart';
import 'package:swiftpath/common/service_call.dart';
import 'package:swiftpath/common/socket_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

SharedPreferences? prefs;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  prefs = await SharedPreferences.getInstance();

  ServiceCall.userUUID = Globs.udValueString("uuid");

  if (ServiceCall.userUUID == "") {
    ServiceCall.userUUID = const Uuid().v6();
    Globs.udStringSet(ServiceCall.userUUID, "uuid");
  }

  SocketManager.shared.initSocket();
  LocationManager.shared.initLocation();
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
          Theme.of(context).textTheme,
        ),
      ),
      home: const LandingPage(),
      routes: {
        '/landing': (context) => const LandingPage(),
        '/homepage': (context) => HomePage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/dashboard': (context) =>const DashboardPage(),
        '/edit-profile': (context) => const EditProfilePage(),
        '/route-history': (context) => const RouteHistoryPage(),
        '/report-history': (context) => const ReportHistoryPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/maps': (context) => const MapScreen()
      },
    );
  }
}
