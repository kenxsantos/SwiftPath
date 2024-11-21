import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class SampleMapScreen extends StatefulWidget {
  @override
  _SampleMapScreenState createState() => _SampleMapScreenState();
}

class _SampleMapScreenState extends State<SampleMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final String websocketUrl =
      "ws://8bd4-136-158-25-28.ngrok-free.app"; // Replace with your backend WebSocket URL
  late WebSocketChannel _channel;
  Set<Marker> _markers = {};
  LatLng _currentPosition = const LatLng(0, 0); // Default position

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _channel.sink
        .close(); // Close the WebSocket connection when the widget is disposed
    super.dispose();
  }

  // Connect to the WebSocket
  void _connectWebSocket() {
    print("Connecting to WebSocket: $websocketUrl");
    _channel = WebSocketChannel.connect(Uri.parse(websocketUrl));

    // Listen for incoming messages
    _channel.stream.listen((message) {
      final data = jsonDecode(message);

      if (data['coordinates'] != null) {
        final List<dynamic> coordinates = data['coordinates'];

        setState(() {
          _currentPosition = LatLng(coordinates[1], coordinates[0]);
          _markers = {
            Marker(
              markerId: const MarkerId('current_location'),
              position: _currentPosition,
              infoWindow: const InfoWindow(title: "Current Location"),
            ),
          };
        });

        // Move the map camera to the new position
        _moveCameraToCurrentPosition();
      }
    });
  }

  // Move the camera to the current position
  Future<void> _moveCameraToCurrentPosition() async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentPosition, zoom: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Real-Time Google Map"),
      ),
      body: GoogleMap(
        onMapCreated: (controller) {
          _controller.complete(controller);
        },
        initialCameraPosition: CameraPosition(
          target: _currentPosition, // Use the updated position
          zoom: 2,
        ),
        markers: _markers,
      ),
    );
  }
}
