import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swiftpath/components/custom_switch_tile.dart';
import 'dart:convert';
import 'package:roam_flutter/roam_flutter.dart';

class LocationSettings extends StatefulWidget {
  const LocationSettings({super.key, required this.userId});

  final String userId;

  @override
  State<LocationSettings> createState() => _LocationSettingsState();
}

class _LocationSettingsState extends State<LocationSettings> {
  bool isToggleListener = true;
  bool isToggleEvents = true;
  bool isSubscribeLocations = true;
  bool isSubscribeUserLocations = true;
  bool isSubscribeEvents = true;

  // Utility to copy User ID
  void _copyUserId() {
    Clipboard.setData(ClipboardData(text: widget.userId));
    _showSnackBar('User ID copied to clipboard!');
  }

  // Show Snackbar
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Toggle Listener
  void _toggleListener(bool value) {
    setState(() => isToggleListener = value);
    Roam.toggleListener(
      locations: value,
      events: value,
      callBack: ({user}) {
        final userData = jsonDecode(user!);
        _showSnackBar(
          'Listener Status Updated:\n'
          'User ID: ${userData["userId"]}\n'
          'Events: ${userData["events"]}\n'
          'Locations: ${userData["locations"]}',
        );
      },
    );
  }

  // Toggle Events
  void _toggleEvents(bool value) {
    setState(() => isToggleEvents = value);
    Roam.toggleEvents(
      location: value,
      geofence: value,
      trips: value,
      movingGeofence: value,
      callBack: ({user}) {
        final userData = jsonDecode(user!);
        _showSnackBar(
          'Events Status Updated:\n'
          'User ID: ${userData["userId"]}\n'
          'Location Events: ${userData["locationEvents"]}\n'
          'Trips Events: ${userData["tripsEvents"]}',
        );
      },
    );
  }

  // Subscribe Locations
  void _subscribeLocations(bool value) {
    setState(() => isSubscribeLocations = value);
    Roam.subscribeLocation();
    _showSnackBar(
      'Subscribe Location ${isSubscribeLocations ? 'enable' : 'disabled'}',
    );
  }

  // Subscribe User Locations
  void _subscribeUserLocations(bool value) {
    setState(() => isSubscribeUserLocations = value);
    Roam.subscribeUserLocation(userId: widget.userId);
    _showSnackBar(
      'Subscribe User Location ${isSubscribeUserLocations ? 'enable' : 'disabled'}',
    );
  }

  // Subscribe Events
  void _subscribeEvents(bool value) {
    setState(() => isSubscribeEvents = value);
    Roam.subscribeEvents();
    _showSnackBar(
      'Subscribe Events ${isSubscribeEvents ? 'enable' : 'disabled'}',
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
              widget.userId,
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
            subtitle: 'Subscribe to location updates',
            value: isSubscribeUserLocations,
            onChanged: _subscribeUserLocations,
          ),
          const Divider(),
          CustomSwitchTile(
            title: 'Subscribe User Locations',
            subtitle: 'Subscribe to location updates',
            value: isSubscribeEvents,
            onChanged: _subscribeEvents,
          ),
        ],
      ),
    );
  }
}
