import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swiftpath/components/custom_switch_tile.dart';
import 'dart:convert';
import 'package:roam_flutter/roam_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

class LocationSettings extends StatefulWidget {
  const LocationSettings({super.key});

  @override
  State<LocationSettings> createState() => _LocationSettingsState();
}

class _LocationSettingsState extends State<LocationSettings> {
  bool isToggleListener = false;
  bool isToggleEvents = false;
  bool isSubscribeLocations = false;
  bool isSubscribeUserLocations = false;
  bool isSubscribeEvents = false;
  bool isStartTrackingLocation = false;
  String? myUserId;
  User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadToggleStates(); // Load the saved toggle states
    _fetchListenerStatus();
  }

  void _fetchListenerStatus() {
    Roam.getListenerStatus(
      callBack: ({user}) {
        setState(() {
          final userData = jsonDecode(user!);
          myUserId = userData["userId"];
        });
      },
    );
  }

  void _loadToggleStates() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isToggleListener = prefs.getBool('isToggleListener') ?? false;
      isToggleEvents = prefs.getBool('isToggleEvents') ?? false;
      isSubscribeLocations = prefs.getBool('isSubscribeLocations') ?? false;
      isSubscribeUserLocations =
          prefs.getBool('isSubscribeUserLocations') ?? false;
      isSubscribeEvents = prefs.getBool('isSubscribeEvents') ?? false;
      isStartTrackingLocation =
          prefs.getBool('isStartTrackingLocation') ?? false;
    });
  }

  void _saveToggleStates() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isToggleListener', isToggleListener);
    prefs.setBool('isToggleEvents', isToggleEvents);
    prefs.setBool('isSubscribeLocations', isSubscribeLocations);
    prefs.setBool('isSubscribeUserLocations', isSubscribeUserLocations);
    prefs.setBool('isSubscribeEvents', isSubscribeEvents);
    prefs.setBool('isStartTrackingLocation', isStartTrackingLocation);
  }

  void _copyUserId() {
    Clipboard.setData(ClipboardData(text: myUserId ?? "User ID"));
    toastification.show(
      context: context,
      type: ToastificationType.info,
      description: RichText(
        text: TextSpan(
          text: 'User ID copied to clipboard',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
      icon: const Icon(Icons.check),
      autoCloseDuration: const Duration(seconds: 2),
    );
  }

  void _startTrackingLocation(bool value) {
    setState(() => isStartTrackingLocation = value);
    value ? Roam.startTracking(trackingMode: "active") : Roam.stopTracking();
    _saveToggleStates(); // Save state when toggle changes

    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.fillColored,
      title: Text(
          'Tracking Location ${isStartTrackingLocation ? 'enabled' : 'disabled'}'),
      icon: const Icon(Icons.location_on),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  void createUserId() {
    Roam.createUser(
      description: user?.email ?? "anonymous",
      callBack: ({user}) {
        setState(() {
          final userData = jsonDecode(user!);
          myUserId = userData["userId"];
        });
      },
    );
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: const Text('User ID created successfully!'),
      icon: const Icon(Icons.check),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  void _toggleListener(bool value) {
    setState(() => isToggleListener = value);
    Roam.toggleListener(
      locations: value,
      events: value,
      callBack: ({user}) {
        final userData = jsonDecode(user!);
        toastification.show(
          context: context,
          type: ToastificationType.info,
          style: ToastificationStyle.fillColored,
          description: RichText(
            text: TextSpan(
              text: 'Listener Status Updated:\n'
                  'User ID: ${userData["userId"]}\n'
                  'Events: ${userData["events"]}\n'
                  'Locations: ${userData["locations"]}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          icon: const Icon(Icons.check),
          autoCloseDuration: const Duration(seconds: 2),
        );
      },
    );
    _saveToggleStates();
  }

  void _toggleEvents(bool value) {
    setState(() => isToggleEvents = value);
    Roam.toggleEvents(
      location: value,
      geofence: value,
      trips: value,
      movingGeofence: value,
      callBack: ({user}) {
        final userData = jsonDecode(user!);
        toastification.show(
          context: context,
          type: ToastificationType.info,
          style: ToastificationStyle.fillColored,
          description: RichText(
            text: TextSpan(
              text: 'Events Status Updated:\n'
                  'User ID: ${userData["userId"]}\n'
                  'Location Events: ${userData["locationEvents"]}\n'
                  'Trips Events: ${userData["tripsEvents"]}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          icon: const Icon(Icons.check),
          autoCloseDuration: const Duration(seconds: 2),
        );
      },
    );
    _saveToggleStates();
  }

  void _subscribeLocations(bool value) {
    setState(() => isSubscribeLocations = value);
    Roam.subscribeLocation();
    _saveToggleStates();
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.fillColored,
      description: RichText(
        text: TextSpan(
          text:
              'Subscribe Location ${isSubscribeLocations ? 'enabled' : 'disabled'}',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
      icon: const Icon(Icons.check),
      autoCloseDuration: const Duration(seconds: 2),
    );
  }

  void _subscribeUserLocations(bool value) {
    setState(() => isSubscribeUserLocations = value);
    Roam.subscribeUserLocation(userId: myUserId ?? "User ID");
    _saveToggleStates();
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.fillColored,
      description: RichText(
        text: TextSpan(
          text:
              'Subscribe User Location ${isSubscribeUserLocations ? 'enabled' : 'disabled'}',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
      icon: const Icon(Icons.check),
      autoCloseDuration: const Duration(seconds: 2),
    );
  }

  void _subscribeEvents(bool value) {
    setState(() => isSubscribeEvents = value);
    Roam.subscribeEvents();
    _saveToggleStates();
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.fillColored,
      description: RichText(
        text: TextSpan(
          text:
              'Subscribe Events ${isSubscribeEvents ? 'enabled' : 'disabled'}',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
      icon: const Icon(Icons.check),
      autoCloseDuration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Settings'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle, color: Colors.blue),
            title: Text(
              myUserId?.isEmpty ?? true ? 'User ID' : myUserId!,
              style: const TextStyle(color: Colors.black87),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.copy, color: Colors.grey),
              onPressed: _copyUserId,
            ),
            subtitle: const Text(
              'Your unique user ID',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const Divider(),
          ListTile(
            onTap: () => createUserId(),
            title: const Text(
              'Create New UserID',
              style: TextStyle(color: Colors.black87),
            ),
          ),
          const Divider(),
          CustomSwitchTile(
            title: 'Toggle Listener',
            subtitle: 'Enable or disable location listener',
            value: isToggleListener,
            onChanged: _toggleListener,
          ),
          const Divider(),
          CustomSwitchTile(
            title: 'Toggle Events',
            subtitle: 'Enable or disable event updates',
            value: isToggleEvents,
            onChanged: _toggleEvents,
          ),
          const Divider(),
          CustomSwitchTile(
            title: 'Subscribe Locations',
            subtitle: 'Subscribe to own location updates',
            value: isSubscribeLocations,
            onChanged: _subscribeLocations,
          ),
          const Divider(),
          CustomSwitchTile(
            title: 'Subscribe User Locations',
            subtitle: 'Subscribe to user location updates',
            value: isSubscribeUserLocations,
            onChanged: _subscribeUserLocations,
          ),
          const Divider(),
          CustomSwitchTile(
            title: 'Subscribe Events',
            subtitle: 'Subscribe to events updates',
            value: isSubscribeEvents,
            onChanged: _subscribeEvents,
          ),
          const Divider(),
          CustomSwitchTile(
            title: 'Start Tracking Location',
            subtitle: 'Enable location tracking',
            value: isStartTrackingLocation,
            onChanged: _startTrackingLocation,
          ),
        ],
      ),
    );
  }
}
