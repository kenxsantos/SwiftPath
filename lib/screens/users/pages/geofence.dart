import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GeofenceArea extends StatefulWidget {
  const GeofenceArea({super.key});

  @override
  State<GeofenceArea> createState() => _GeofenceAreaState();
}

class _GeofenceAreaState extends State<GeofenceArea> {
  late FirebaseMessaging messaging;

  @override
  void initState() {
    super.initState();
    messaging = FirebaseMessaging.instance;

    // Request notification permissions
    messaging.requestPermission();
    messaging.getToken().then((token) {
      print("Device Token: $token");
      // Send this token to your backend to register the user for notifications
    });

    // Listen for incoming messages while the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Message received: ${message.notification?.title}");
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(message.notification?.title ?? "Notification"),
          content: Text(
              message.notification?.body ?? "You entered a geofence area."),
        ),
      );
    });
  }

  // Define the path to your service account JSON file
  String serviceAccountKeyPath = 'path/to/service-account.json';
  String projectId = 'your-firebase-project-id';

  // Get an access token from the Firebase service account
  Future<String> getAccessToken() async {
    final serviceAccount = ServiceAccountCredentials.fromJson(
        json.decode(File(serviceAccountKeyPath).readAsStringSync()));
    final authClient = await clientViaServiceAccount(
        serviceAccount, ['https://www.googleapis.com/auth/cloud-platform']);
    final accessToken = await authClient.credentials.accessToken;
    return accessToken.data;
  }

  // Send a push notification to a specific device
  Future<void> sendPushNotification(
      String deviceToken, String title, String body) async {
    final accessToken = await getAccessToken();
    final url = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "message": {
          "token": deviceToken,
          "notification": {
            "title": title,
            "body": body,
          }
        }
      }),
    );

    if (response.statusCode == 200) {
      print("Notification sent successfully");
    } else {
      print("Failed to send notification: ${response.body}");
    }
  }

  // Webhook endpoint to receive geofence events from Roam.ai
  Future<void> handleGeofenceEvent(HttpRequest request) async {
    if (request.method == 'POST') {
      final data = await utf8.decoder.bind(request).join();
      final jsonData = jsonDecode(data);

      // Check if the event is a geofence entry event
      if (jsonData['event_type'] == 'enter') {
        final String deviceToken = jsonData['user_token'];
        await sendPushNotification(deviceToken, "Geofence Alert",
            "You have entered a restricted area.");
      }

      request.response
        ..statusCode = HttpStatus.ok
        ..write('Geofence event processed');
    } else {
      request.response
        ..statusCode = HttpStatus.methodNotAllowed
        ..write('Unsupported request: ${request.method}.');
    }
    await request.response.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Geofence Area")),
      body: Center(child: Text("Waiting for geofence entry...")),
    );
  }
}
