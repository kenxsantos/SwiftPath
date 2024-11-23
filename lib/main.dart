import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

// Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:swiftpath/screens/users/pages/google_map_view.dart';
import 'package:swiftpath/views/landing_page.dart';
import 'firebase_options.dart';

// Roam SDK import
import 'package:roam_flutter/roam_flutter.dart';

SharedPreferences? prefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  prefs = await SharedPreferences.getInstance();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await initializeRoam();
  runApp(const ProviderScope(child: MyApp()));
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background Message: ${message.messageId}');
}

Future<void> initializeRoam() async {
  const String roamKeyEnv = 'ROAM_AI_PUBLISHABLE_KEY';
  final String roamAiPublishableKey = dotenv.env[roamKeyEnv] ?? '';

  final logger = Logger(printer: PrettyPrinter());

  if (roamAiPublishableKey.isEmpty) {
    logger.e('Roam SDK initialization failed: API key is missing');
    return;
  }

  try {
    Roam.initialize(publishKey: roamAiPublishableKey);

    // final User? user = FirebaseAuth.instance.currentUser;
    // await Roam.createUser(
    //   description: user?.email ?? '',
    //   callBack: ({user}) {
    //     logger.d('Roam User Created: $user');
    //     Roam.offlineTracking(true);
    //     Roam.allowMockLocation(allow: true);
    //   },
    // );

    logger.d('Roam SDK initialized successfully');
  } catch (e) {
    logger.e('Roam SDK initialization failed: $e');
  }
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
      home: const MyHomePage(
        title: "a",
      ), // Replace with the initial page of your app
    );
  }
}
