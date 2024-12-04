import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:developer' as developer;

import 'package:roam_flutter/RoamTrackingMode.dart';
import 'package:roam_flutter/roam_flutter.dart';

class CustomFloatingActionButton extends StatelessWidget {
  final Completer<GoogleMapController> controller;
  final Future<Position> Function() getCurrentUserLocation;
  final void Function(LatLng point, {String? info}) setMarker;
  final Color backgroundColor;
  final IconData icon;
  final double iconSize;
  final String markerInfo;

  const CustomFloatingActionButton({
    super.key,
    required this.controller,
    required this.getCurrentUserLocation,
    required this.setMarker,
    this.backgroundColor = Colors.red,
    this.icon = Icons.my_location_rounded,
    this.iconSize = 25.0,
    this.markerInfo = "My Current Location",
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () async {
        try {
          Roam.startTracking(trackingMode: "active");
        } on PlatformException {
          print('Get Current Location Error');
        }

        Roam.startTracking(trackingMode: "active");
        Roam.onLocation((location) {
          print(jsonEncode(location));
        });
        GoogleMapController mapController = await controller.future;
        developer.log('Floating action button pressed');
        getCurrentUserLocation().then((value) async {
          await mapController.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(value.latitude, value.longitude),
                zoom: 14.2,
              ),
            ),
          );
          setMarker(LatLng(value.latitude, value.longitude), info: markerInfo);
        });
      },
      shape: const CircleBorder(),
      backgroundColor: backgroundColor,
      child: Icon(
        icon,
        color: Colors.white,
        size: iconSize,
      ),
    );
  }
}
