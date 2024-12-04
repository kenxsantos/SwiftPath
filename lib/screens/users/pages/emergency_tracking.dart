import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class EmergencyMap extends StatefulWidget {
  const EmergencyMap({Key? key}) : super(key: key);

  @override
  _EmergencyMapState createState() => _EmergencyMapState();
}

class _EmergencyMapState extends State<EmergencyMap> {
  late GoogleMapController _mapController;
  LatLng? _currentLocation;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final Set<Marker> _markers = {};
  BitmapDescriptor emergencyIcon = BitmapDescriptor.defaultMarker;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _listenToAllEmergencyVehicleLocations();
    setCustomMarkerIcon();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services are disabled.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Location permissions are denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print("Location permissions are permanently denied.");
      return;
    }

    // Get the current location
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _updateCurrentLocationMarker();
      });
    });
  }

  void _updateCurrentLocationMarker() {
    if (_currentLocation != null) {
      _markers
          .removeWhere((marker) => marker.markerId.value == "currentLocation");
      _markers.add(Marker(
        markerId: const MarkerId("currentLocation"),
        position: _currentLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: "Your Location"),
      ));
      _moveCameraToIncludeLocations();
    }
  }

  void _listenToAllEmergencyVehicleLocations() {
    _dbRef
        .child('emergency-vehicle-location')
        .onValue
        .listen((DatabaseEvent event) {
      if (event.snapshot.exists) {
        final vehicles = event.snapshot.value as Map;

        setState(() {
          // Clear previous markers
          _markers.removeWhere(
              (marker) => marker.markerId.value.startsWith("emergencyVehicle"));

          // Add new markers based on the updated data
          vehicles.forEach((userId, vehicleData) {
            final isTracking = vehicleData['is_tracking'] == true ||
                vehicleData['is_tracking'] == "true";

            if (isTracking) {
              final origin = vehicleData['origin'];
              if (origin != null &&
                  origin['lat'] != null &&
                  origin['lng'] != null) {
                final vehicleLocation = LatLng(
                  origin['lat'] is int
                      ? origin['lat'].toDouble()
                      : origin['lat'],
                  origin['lng'] is int
                      ? origin['lng'].toDouble()
                      : origin['lng'],
                );

                print(
                    "Vehicle updated: $userId, Location: ${origin['lat']}, ${origin['lng']}");

                _markers.add(Marker(
                  markerId: MarkerId("emergencyVehicle_$userId"),
                  position: vehicleLocation,
                  icon: emergencyIcon,
                  infoWindow: InfoWindow(title: " $userId"),
                ));
              }
            }
          });
        });

        // Optionally, you can force the camera to move to include all markers
        // _moveCameraToIncludeLocations();
      } else {
        print("No emergency vehicle locations found in the database.");
      }
    });
  }

  void setCustomMarkerIcon() {
    BitmapDescriptor.asset(const ImageConfiguration(size: Size(48, 48)),
            'assets/images/icons/emergency_icon.png')
        .then((icon) {
      emergencyIcon = icon;
    });
  }

  void _moveCameraToIncludeLocations() {
    if (_markers.isNotEmpty) {
      final allLatLngs = _markers.map((marker) => marker.position).toList();

      final latitudes = allLatLngs.map((latLng) => latLng.latitude);
      final longitudes = allLatLngs.map((latLng) => latLng.longitude);

      final southwest = LatLng(
        latitudes.reduce((a, b) => a < b ? a : b),
        longitudes.reduce((a, b) => a < b ? a : b),
      );

      final northeast = LatLng(
        latitudes.reduce((a, b) => a > b ? a : b),
        longitudes.reduce((a, b) => a > b ? a : b),
      );

      _mapController.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: southwest, northeast: northeast),
          50.0, // Padding
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Emergency Vehicle Tracker"),
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(14.59519, 120.90894), // Default position
          zoom: 10,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        markers: _markers,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
      ),
    );
  }
}
