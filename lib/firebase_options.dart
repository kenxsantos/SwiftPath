// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBFG1_ND-QuZWiLsp1OWONY3n440u07ogM',
    appId: '1:153593255012:web:55474bb149c6d336e7bb71',
    messagingSenderId: '153593255012',
    projectId: 'swiftpath-77a56',
    authDomain: 'swiftpath-77a56.firebaseapp.com',
    storageBucket: 'swiftpath-77a56.appspot.com',
    measurementId: 'G-2DC21KLGCJ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAwC9GuZmD43n6-acpj48dSEQAtOnBko_o',
    appId: '1:153593255012:android:522565c90e3cd35be7bb71',
    messagingSenderId: '153593255012',
    projectId: 'swiftpath-77a56',
    storageBucket: 'swiftpath-77a56.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAF_DK6PjjUZb_QHQbs3bfsAhORrlXPJz8',
    appId: '1:153593255012:ios:526e05b49f36c539e7bb71',
    messagingSenderId: '153593255012',
    projectId: 'swiftpath-77a56',
    storageBucket: 'swiftpath-77a56.appspot.com',
    iosClientId: '153593255012-d39dptt41o3b31kveetls5dq3oif5loh.apps.googleusercontent.com',
    iosBundleId: 'com.example.swiftpath',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAF_DK6PjjUZb_QHQbs3bfsAhORrlXPJz8',
    appId: '1:153593255012:ios:526e05b49f36c539e7bb71',
    messagingSenderId: '153593255012',
    projectId: 'swiftpath-77a56',
    storageBucket: 'swiftpath-77a56.appspot.com',
    iosClientId: '153593255012-d39dptt41o3b31kveetls5dq3oif5loh.apps.googleusercontent.com',
    iosBundleId: 'com.example.swiftpath',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBFG1_ND-QuZWiLsp1OWONY3n440u07ogM',
    appId: '1:153593255012:web:ddbd59dfb517276ce7bb71',
    messagingSenderId: '153593255012',
    projectId: 'swiftpath-77a56',
    authDomain: 'swiftpath-77a56.firebaseapp.com',
    storageBucket: 'swiftpath-77a56.appspot.com',
    measurementId: 'G-T83K0KMCPP',
  );
}