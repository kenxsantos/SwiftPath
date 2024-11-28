import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class NotificationService {
  void listenToMessages() {
    if (kIsWeb) {
      // Web-specific implementation
      _listenToWebMessages();
    } else {
      // Mobile-specific implementation
      _listenToMobileMessages();
    }
  }

  void _listenToWebMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Received web message: ${message.notification?.title}");
      // Handle web message
    });
  }

  void _listenToMobileMessages() {
    FirebaseMessaging.instance.subscribeToTopic('all_users');
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Received mobile message: ${message.notification?.title}");
      // Handle mobile message
    });
  }

  Future<void> initNotifications() async {
    if (!kIsWeb) {
      // Only request permission on mobile
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }
}
