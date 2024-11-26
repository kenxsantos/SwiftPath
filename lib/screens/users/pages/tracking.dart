import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class EmergencyMap extends StatefulWidget {
  final String emergencyVehicleId = "emergency-vehicle-1";

  const EmergencyMap({super.key});

  @override
  _EmergencyMapState createState() => _EmergencyMapState();
}

class _EmergencyMapState extends State<EmergencyMap> {
  late GoogleMapController _mapController;
  LatLng? _currentLocation;
  LatLng? _emergencyVehicleLocation;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _listenToEmergencyVehicleLocation();
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
      print(
          "Location permissions are permanently denied. Cannot request permissions.");
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
        _moveCameraToIncludeLocations();
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
    }
  }

  void _listenToEmergencyVehicleLocation() {
    _dbRef
        .child('emergency-vehicle-location/${widget.emergencyVehicleId}/origin')
        .onValue
        .listen((DatabaseEvent event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map;
        final latitude = data['latitude'];
        final longitude = data['longitude'];

        if (latitude != null && longitude != null) {
          setState(() {
            _emergencyVehicleLocation = LatLng(latitude, longitude);
            _updateEmergencyVehicleMarker();
            _moveCameraToIncludeLocations();
          });
        }
      } else {
        print(
            "No emergency vehicle location found for ID: ${widget.emergencyVehicleId}");
      }
    });
  }

  void _updateEmergencyVehicleMarker() {
    if (_emergencyVehicleLocation != null) {
      _markers
          .removeWhere((marker) => marker.markerId.value == "emergencyVehicle");
      _markers.add(Marker(
        markerId: const MarkerId("emergencyVehicle"),
        position: _emergencyVehicleLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: "Emergency Vehicle"),
      ));
    }
  }

  void _moveCameraToIncludeLocations() {
    if (_currentLocation != null && _emergencyVehicleLocation != null) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              _currentLocation!.latitude < _emergencyVehicleLocation!.latitude
                  ? _currentLocation!.latitude
                  : _emergencyVehicleLocation!.latitude,
              _currentLocation!.longitude < _emergencyVehicleLocation!.longitude
                  ? _currentLocation!.longitude
                  : _emergencyVehicleLocation!.longitude,
            ),
            northeast: LatLng(
              _currentLocation!.latitude > _emergencyVehicleLocation!.latitude
                  ? _currentLocation!.latitude
                  : _emergencyVehicleLocation!.latitude,
              _currentLocation!.longitude > _emergencyVehicleLocation!.longitude
                  ? _currentLocation!.longitude
                  : _emergencyVehicleLocation!.longitude,
            ),
          ),
          50.0, // Padding for the bounds
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
          target: LatLng(14.5965778,
              120.9383598), // Default position until location is available
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
