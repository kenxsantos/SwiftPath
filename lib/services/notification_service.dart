import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initNotifications() async {
    await _messaging.requestPermission();
    await _messaging.subscribeToTopic('geofence_entry_notifications');
    await _messaging.subscribeToTopic('geofence_exit_notifications');
    await _messaging.subscribeToTopic('geofence_dwell_notifications');
    await _messaging.subscribeToTopic('moving_geofence_nearby_notifications');
    // await _messaging.subscribeToTopic('location_change_notifications');
  }

  void listenToMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        print('Message Title: ${message.notification!.title}');
        print('Message Body: ${message.notification!.body}');
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification Clicked: ${message.data}');
    });
  }
}
