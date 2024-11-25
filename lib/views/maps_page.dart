// ignore_for_file: prefer_final_fields, non_constant_identifier_names, unused_field, curly_braces_in_flow_control_structures, prefer_typing_uninitialized_variables

import 'dart:async';
import 'dart:convert';
// import 'dart:developer' as developer;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_html/flutter_html.dart' as flutter_html;
import 'package:http/http.dart' as http;
import 'package:google_places_autocomplete_text_field/model/prediction.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:fab_circular_menu_plus/fab_circular_menu_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:swiftpath/screens/admin/pages/barangay_maps.dart';
import 'package:swiftpath/screens/super_admin/pages/admin_maps.dart';
import 'package:swiftpath/screens/users/pages/report_incident.dart';
import 'package:swiftpath/screens/users/pages/settings_page.dart';
import 'package:swiftpath/services/notification_service.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_database/firebase_database.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  Timer? _debounce;
  TextEditingController _originController = TextEditingController();
  final String googleApiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
  final GlobalKey<FabCircularMenuPlusState> fabKey = GlobalKey();
  Completer<GoogleMapController> _controller = Completer();
  List<Map<String, dynamic>> routes = [];
  List<dynamic> _placesList = [];
  Set<Marker> _markers = <Marker>{};
  // Replace with your backend URL
  late IO.Socket _socket;
  LatLng _currentPosition = const LatLng(0, 0); // Default position
  bool showAlternativeRoutes = false;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final _destinationController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  String? _destination;
  final _apiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
  bool _isLoading = false;
  Set<Polyline> polylines = <Polyline>{};
  final FocusNode _focusNode = FocusNode();

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _chatController = TextEditingController();
  List<Map<String, dynamic>> _chatMessages = [];
  bool _isChatLoading = false;
  late GenerativeModel _genAI;

  // Initialize Firebase Messaging
  void _setupFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showNotification(
          message.notification!.title ?? '',
          message.notification!.body ?? '',
        );
        _showSnackbar(
          context,
          '${message.notification!.title}: ${message.notification!.body}',
        );
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
    });
  }

  // Display Snackbar
  void _showSnackbar(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // Setup Local Notifications
  void setupLocalNotifications() async {
    const AndroidInitializationSettings androidInitialization =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings =
        InitializationSettings(android: androidInitialization);
    await flutterLocalNotificationsPlugin.initialize(settings);
  }

  // Show Notification
  void showNotification(String title, String body) {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails('channel_id', 'channel_name',
            importance: Importance.high);
    const NotificationDetails details =
        NotificationDetails(android: androidDetails);
    flutterLocalNotificationsPlugin.show(0, title, body, details);
  }

  @override
  void initState() {
    super.initState();
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    print("GEMINI API KEY in maps_page: $apiKey");

    if (apiKey == null || apiKey.isEmpty) {
      print("Warning: GEMINI_API_KEY is not available");
      // Handle the error case appropriately
    } else {
      _genAI = GenerativeModel(
        model: 'gemini-pro',
        apiKey: apiKey,
      );
    }

    NotificationService().initNotifications();
    NotificationService().listenToMessages();
    _setupFirebaseMessaging();
    _connectSocket();
  }

  // Connect to Socket
  void _connectSocket() {
    String socketUrl = "https://f9fd-136-158-25-188.ngrok-free.app";
    print("Connecting to Socket.IO server: $socketUrl");
    _socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
          .setPath('/webhook')
          .setTransports(['websocket']) // Use WebSocket transport
          .disableAutoConnect() // Disable auto-connect for manual connection
          .build(),
    );
    _socket.connect();
    _socket.on('location_update', (data) {
      print('Location Update: $data');
      if (data is Map<String, dynamic>) {
        final coordinates = data['coordinates']['coordinates'];
        setState(() {
          _currentPosition = LatLng(coordinates[1], coordinates[0]);
        });
      }
      // Move the map camera to the new position
      _moveCameraToCurrentPosition();
    });

    _socket.on("alternative_routes", (data) {
      print("Received data: $data");

      if (data is Map<String, dynamic> && data['routes'] is List) {
        final List<dynamic> receivedRoutes = data['routes'];

        print("Received data: $receivedRoutes");
        // Parse routes and store in the `routes` list
        setState(() {
          routes = receivedRoutes.map((route) {
            return {
              'summary': route['summary'],
              'distance': route['distance'],
              'duration': route['duration'],
              'start_address': route['start_address'],
              'end_address': route['end_address'],
              'overview_polyline': route['overview_polyline'],
              'steps': route['steps'] ?? [],
            };
          }).toList();
        });
      } else {
        print("Invalid data format received: $data");
      }
    });

    _socket.onConnect((_) {
      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _focusNode.dispose();

    _socket.dispose();
    super.dispose();
  }

  // Move Camera to Current Position
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
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height,
                    width: MediaQuery.of(context).size.width,
                    child: GoogleMap(
                      initialCameraPosition: const CameraPosition(
                          target: LatLng(14.4964995, 120.9996993),
                          zoom: 10.4746),
                      mapType: MapType.normal,
                      myLocationButtonEnabled: true,
                      onMapCreated: (controller) {
                        _controller.complete(controller);
                      },
                      myLocationEnabled: true,
                      markers: _markers,
                      polylines: polylines,
                    ),
                  ),
                  // showGPSlocator(),
                  autoCompleteSearchBar(),
                  Positioned(
                    bottom: 130.0,
                    right: 10,
                    child: routes.isEmpty
                        ? Container()
                        : SizedBox(
                            height: 60.0, // Increase height
                            width: 60.0, // Increase width
                            child: FloatingActionButton(
                              backgroundColor: Colors.red.shade400,
                              shape: const CircleBorder(),
                              onPressed: showRoutesPopup,
                              child: const Icon(
                                Icons.route,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FabCircularMenuPlus(
          key: fabKey,
          alignment: Alignment.bottomLeft,
          fabColor: Colors.red.shade400,
          fabOpenColor: Colors.red.shade400,
          fabElevation: 4,
          ringDiameter: 350.0,
          ringWidth: 65.0,
          fabMargin: const EdgeInsets.only(left: 25),
          ringColor: Colors.red.shade400,
          fabSize: 60.0,
          fabOpenIcon: const Icon(Icons.menu, color: Colors.white),
          fabCloseIcon: const Icon(Icons.close, color: Colors.white),
          children: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminMaps()),
                );
              },
              icon: const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BarangayMaps()),
                );
              },
              icon: const Icon(
                Icons.emergency_rounded,
                color: Colors.white,
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
              icon: const Icon(
                Icons.settings,
                color: Colors.white,
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ReportIncidentPage()),
                );
              },
              icon: const Icon(
                Icons.report,
                color: Colors.white,
              ),
            ),
            IconButton(
              onPressed: _showChatModal,
              icon: const Icon(
                Icons.chat,
                color: Colors.white,
              ),
            ),
          ]),
    );
  }

  void showRoutesPopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Available Routes",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                // Use Expanded for ListView in a Dialog
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: routes.length,
                    itemBuilder: (context, index) {
                      final route = routes[index];
                      return Card(
                        margin: const EdgeInsets.all(5.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0)),
                        elevation: 6.0,
                        child: ExpansionTile(
                          title: Text(
                            route['summary'] ?? 'No summary available',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Distance: ${route['distance'] ?? 'N/A'}, Duration: ${route['duration'] ?? 'N/A'}',
                          ),
                          children: [
                            ListTile(
                              onTap: () => setAlterativeRoutesPolyline(
                                  route['overview_polyline']),
                              title: const Text(
                                'Follow Route',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            ListTile(
                              title: Text(
                                'Start: ${route['start_address']}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            ListTile(
                              title: Text(
                                'Destination: ${route['end_address']}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const Divider(),
                            ...route['steps'].map<Widget>((step) {
                              return Column(
                                children: [
                                  ListTile(
                                    title: flutter_html.Html(
                                      data: step['instruction'] ??
                                          'No instruction',
                                    ),
                                    subtitle: Text(
                                      '  Distance: ${step['distance']}, Duration: ${step['duration']}',
                                    ),
                                  ),
                                  const Divider(),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text("Close"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void setAlterativeRoutesPolyline(String overviewPolyline) {
    // Decode the polyline into LatLng points
    final decodedPolyline = decodePolyline(overviewPolyline);

    // Add the polyline to your map (assuming you're using a controller)
    setState(() {
      polylines.add(Polyline(
        polylineId: PolylineId('route_polyline'),
        points: decodedPolyline,
        color: Colors.blue, // Customize polyline color
        width: 5, // Customize polyline width
      ));
    });

    Navigator.of(context).pop();
  }

  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      polyline.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return polyline;
  }

  Positioned autoCompleteSearchBar() {
    return Positioned(
        top: 40.0,
        right: 15.0,
        left: 15.0,
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidateMode,
          child: GooglePlacesAutoCompleteTextFormField(
            countries: ['ph'],
            textEditingController: _destinationController,
            googleAPIKey: "AIzaSyC2cU6RHwIR6JskX2GHe-Pwv1VepIHkLCg",
            decoration: const InputDecoration(
              fillColor: Colors.white,
              filled: true,
              hintText: 'Enter your address',
              labelText: 'Address',
              labelStyle: TextStyle(color: Colors.black),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
              ),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value!.isEmpty) {
                return 'Please enter some text';
              }
              return null;
            },
            // proxyURL: _yourProxyURL,
            maxLines: 1,
            overlayContainer: (child) => Material(
              elevation: 1.0,
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: child,
            ),
            getPlaceDetailWithLatLng: (prediction) {
              print('placeDetails${prediction.lng}');
              final double destinationLat = double.parse(prediction.lat!);
              final double destinationLng = double.parse(prediction.lng!);
              setState(() {
                _markers = {
                  Marker(
                    markerId: const MarkerId('destination'),
                    position: LatLng(destinationLat, destinationLng),
                    infoWindow: const InfoWindow(title: "Destination Location"),
                  ),
                };
              });
              //provide me a code for sending a destination to the server
              requestRoutesToServer(destinationLat, destinationLng);
              _focusNode.unfocus(); // Remove focus
              _destinationController.clear();
            },
            itmClick: (Prediction prediction) =>
                _destinationController.text = prediction.description!,
          ),
        ));
  }

  void requestRoutesToServer(
      double destinationLat, double destinationLng) async {
    final String? apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];

    const String backendUrl =
        "https://f9fd-136-158-25-188.ngrok-free.app/destination";
    try {
      // Payload for the backend
      final Map<String, dynamic> payload = {
        "destination": {"lat": destinationLat, "lng": destinationLng}
      };

      // Send POST request to the backend
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          "Content-Type": "application/json",
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        print("Destination sent successfully.");
        print("Response: ${response.body}");
      } else {
        print("Failed to send destination: ${response.body}");
      }
    } catch (e) {
      print("Error sending destination: $e");
    }
  }

  Future<String> _fetchIncidentReports() async {
    final snapshot = await _dbRef.child('incident-reports').get();
    if (!snapshot.exists) return 'No incident reports found.';

    Map<String, dynamic> reports =
        Map<String, dynamic>.from(snapshot.value as Map);
    String reportText = 'Here are the recent incident reports:\n\n';

    reports.forEach((key, value) {
      final report = Map<String, dynamic>.from(value);
      reportText += '📍 Location: ${report['address']}\n'
          '📝 Details: ${report['details']}\n'
          '🕒 Time: ${report['timestamp']}\n'
          '📊 Status: ${report['status']}\n\n';
    });

    return reportText;
  }

  Future<void> _handleChatInteraction(String userMessage) async {
    setState(() {
      _chatMessages.add({
        'isUser': true,
        'message': userMessage,
      });
      _isChatLoading = true;
    });

    try {
      final reports = await _fetchIncidentReports();
      final prompt = '''
      Context: You are an emergency response assistant. Use this incident report data:
      $reports
      
      User question: $userMessage
      
      Please provide a helpful response based on the incident reports data.
      ''';

      final content = [Content.text(prompt)];
      final response = await _genAI.generateContent(content);

      setState(() {
        _chatMessages.add({
          'isUser': false,
          'message': response.text,
        });
      });
    } catch (e) {
      setState(() {
        _chatMessages.add({
          'isUser': false,
          'message': 'Sorry, I encountered an error: $e',
        });
      });
    } finally {
      setState(() {
        _isChatLoading = false;
      });
      _chatController.clear();
    }
  }

  void _showChatModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Emergency Response Assistant',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  final message = _chatMessages[index];
                  return Align(
                    alignment: message['isUser']
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: message['isUser']
                            ? Colors.blue[100]
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(message['message']),
                    ),
                  );
                },
              ),
            ),
            if (_isChatLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      decoration: const InputDecoration(
                        hintText: 'Ask about incident reports...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      if (_chatController.text.isNotEmpty) {
                        _handleChatInteraction(_chatController.text);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
