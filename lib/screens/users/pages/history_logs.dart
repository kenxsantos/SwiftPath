import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class HistoryLogs extends StatefulWidget {
  const HistoryLogs({Key? key}) : super(key: key);

  @override
  State<HistoryLogs> createState() => _HistoryLogsState();
}

class _HistoryLogsState extends State<HistoryLogs> {
  late IO.Socket _socket;
  final List<String> _logs = []; // Store logs here
  bool _isLoading = true; // Track loading state

  @override
  void initState() {
    super.initState();
    _initializeSocket();
  }

  void _initializeSocket() {
    _socket = IO.io(
      'https://11f2-136-158-25-188.ngrok-free.app',
      IO.OptionBuilder()
          .setPath('/webhook')
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket.connect();

    // Listen for location updates
    _socket.on('location_update', (data) {
      if (data is Map<String, dynamic>) {
        final coordinates = data['coordinates']['coordinates'];
        setState(() {
          _logs.add(
            'LocationL: $coordinates',
          );
        });
      }
    });

    // Listen for geofence entry updates
    _socket.on('geofence_update', (data) {
      print('Geofence Update: $data');
      if (data is Map<String, dynamic>) {
        final locationId = data['location_id'];
        final geofenceId = data['geofence_id'];
        final recordedAt = data['recorded_at'];
        final coordinates = data['location']['coordinates'];

        setState(() {
          _logs.add(
            'Geofence entry detected:\nLocation ID: $locationId\n'
            'Geofence ID: $geofenceId\nRecorded At: $recordedAt\nCoordinates: $coordinates',
          );
        });
      }
    });

    // Set loading to false once the connection is established and logs start coming in
    _socket.onConnect((_) {
      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History Logs'),
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator()) // Show loading indicator while connecting
          : _logs.isEmpty
              ? const Center(
                  child: Text(
                      'No logs available.')) // Show message if no logs are available
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.all(10.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0)),
                        elevation: 6.0,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            _logs[index],
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
