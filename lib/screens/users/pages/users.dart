import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geofencing_api/geofencing_api.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:swiftpath/screens/users/pages/google_map_view.dart';
import 'dart:developer' as dev;

class UserMapPage extends StatefulWidget {
  @override
  _UserMapPageState createState() => _UserMapPageState();
}

class _UserMapPageState extends State<UserMapPage> {
  final LatLng _userLocation = const LatLng(14.501900, 120.997013);
  final LatLng _geofenceCenter = const LatLng(14.501900, 120.997013);
  final double _geofenceRadius = 300.0; // in meters

  final Set<GeofenceRegion> _regions = {
    GeofenceRegion.circular(
      id: 'Incident Area',
      data: {
        'name': 'TIP Manila',
      },
      center: const LatLng(14.501900, 120.997013),
      radius: 250,
      loiteringDelay: 60 * 1000,
    ),
  };
  late final FlutterLocalNotificationsPlugin _notifications;
  bool _isNotificationsInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestLocationPermission();
      _setupGeofencing();
      _startGeofencing();
      _notifications = FlutterLocalNotificationsPlugin();
      _initializeNotifications();
    });
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings(
            '@mipmap/ic_launcher'); // Use your app icon

    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidSettings);

    await _notifications.initialize(initializationSettings);

    // Set the initialization flag
    setState(() {
      _isNotificationsInitialized = true;
    });
  }

  Future<bool> _requestLocationPermission({bool background = false}) async {
    if (!await Geofencing.instance.isLocationServicesEnabled) {
      return false;
    }
    LocationPermission permission =
        await Geofencing.instance.getLocationPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geofencing.instance.requestLocationPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    if (kIsWeb || kIsWasm) {
      return true;
    }
    if (Platform.isAndroid &&
        background &&
        permission == LocationPermission.whileInUse) {
      permission = await Geofencing.instance.requestLocationPermission();
      if (permission != LocationPermission.always) {
        return false;
      }
    }

    return true;
  }

  void _setupGeofencing() {
    try {
      Geofencing.instance.setup(
        interval: 1000,
        accuracy: 100,
        statusChangeDelay: 1000,
        allowsMockLocation: true,
        printsDebugLog: true,
      );
    } catch (e, s) {
      _onError(e, s);
    }
  }

  void _stopGeofencing() async {
    try {
      Geofencing.instance
          .removeGeofenceStatusChangedListener(_onGeofenceStatusChanged);
      Geofencing.instance.removeGeofenceErrorCallbackListener(_onError);
      await Geofencing.instance.stop();
      _refreshPage();
    } catch (e, s) {
      _onError(e, s);
    }
  }

  void _refreshPage() {
    if (mounted) {
      setState(() {});
    }
  }

  void _startGeofencing() async {
    try {
      Geofencing.instance
          .addGeofenceStatusChangedListener(_onGeofenceStatusChanged);
      Geofencing.instance.addGeofenceErrorCallbackListener(_onError);
      await Geofencing.instance.start(regions: _regions);
      _refreshPage();
    } catch (e, s) {
      _onError(e, s);
    }
  }

  Future<void> _onGeofenceStatusChanged(
    GeofenceRegion geofenceRegion,
    GeofenceStatus geofenceStatus,
    Location location,
  ) async {
    final String regionId = geofenceRegion.id;
    final String statusName = geofenceStatus.name;
    dev.log('region(id: $regionId) $statusName');

    if (geofenceStatus == GeofenceStatus.enter) {
      _notifyUser(
          'You $statusName $regionId. Take Alternative Route to avoid delays');
    } else if (geofenceStatus == GeofenceStatus.exit) {
      _notifyUser('You $statusName $regionId.');
    } else if (geofenceStatus == GeofenceStatus.dwell) {
      _notifyUser('You $statusName $regionId');
    }
    _refreshPage();
  }

  void _onError(Object error, StackTrace stackTrace) {
    dev.log('error: $error\n$stackTrace');
  }

  void _notifyUser(String message) {
    if (!_isNotificationsInitialized) {
      debugPrint('Notifications are not yet initialized!');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5)));
    _notifications.show(
      0,
      "Geofence Alert",
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'geofence_channel',
          'Geofence Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("User Map")),
      body: GoogleMapView(
        regions: Geofencing.instance.regions,
      ),
    );
  }
}
