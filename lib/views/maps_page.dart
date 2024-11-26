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
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

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
  FlutterTts? _flutterTts;
  bool _isTtsInitialized = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initTts();
    });
    _initTts().then((_) {
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
    });
  }

  Future<void> _initTts() async {
    try {
      print("Starting TTS initialization...");
      _flutterTts = FlutterTts();

      if (_flutterTts != null) {
        // Check if the platform is supported
        try {
          var isLanguageAvailable =
              await _flutterTts!.isLanguageAvailable("en-US");
          print("Is language available: $isLanguageAvailable");
        } catch (e) {
          print("Error checking language availability: $e");
        }

        // Basic configuration
        try {
          await _flutterTts!.setLanguage("en-US");
          await _flutterTts!.setPitch(1.0);
          await _flutterTts!.setSpeechRate(0.5);
          await _flutterTts!.setVolume(1.0);

          // Platform specific settings
          if (Platform.isAndroid) {
            await _flutterTts!.setQueueMode(1);
            await _flutterTts!.awaitSpeakCompletion(true);
          }

          _isTtsInitialized = true;
          print("TTS initialized successfully");
        } catch (e) {
          print("Error during TTS configuration: $e");
        }
      }
    } catch (e) {
      print("Error in TTS initialization: $e");
      _isTtsInitialized = false;
    }
  }

  Future<void> _speakText(String text) async {
    if (!_isTtsInitialized || _flutterTts == null) {
      print("TTS not initialized, attempting to initialize...");
      await _initTts();
    }

    try {
      if (_isTtsInitialized && _flutterTts != null) {
        print("Attempting to speak: $text");
        var result = await _flutterTts!.speak(text);
        print("Speak result: $result");
      } else {
        print("TTS still not initialized");
      }
    } catch (e) {
      print("Error in _speakText: $e");
    }
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
    try {
      if (_isTtsInitialized && _flutterTts != null) {
        _flutterTts!.stop();
      }
    } catch (e) {
      print("Error in dispose: $e");
    }
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
      body: Stack(
        children: [
          // Full screen map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(14.4964995, 120.9996993),
              zoom: 10.4746,
            ),
            mapType: MapType.normal,
            myLocationButtonEnabled: true,
            onMapCreated: (controller) {
              _controller.complete(controller);
            },
            myLocationEnabled: true,
            markers: _markers,
            polylines: polylines,
          ),

          // Search bar with improved styling
          Positioned(
            top: 50.0,
            left: 20.0,
            right: 20.0,
            child: Card(
              elevation: 8.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidateMode,
                child: GooglePlacesAutoCompleteTextFormField(
                  countries: ['ph'],
                  textEditingController: _destinationController,
                  googleAPIKey: "AIzaSyC2cU6RHwIR6JskX2GHe-Pwv1VepIHkLCg",
                  decoration: InputDecoration(
                    fillColor: Colors.white,
                    filled: true,
                    hintText: 'Where to?',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
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
                          infoWindow:
                              const InfoWindow(title: "Destination Location"),
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
              ),
            ),
          ),

          // Routes button with improved styling
          if (routes.isNotEmpty)
            Positioned(
              bottom: 130.0,
              right: 20.0,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  backgroundColor: Colors.red.shade400,
                  onPressed: showRoutesPopup,
                  child: const Icon(Icons.route, color: Colors.white, size: 28),
                ),
              ),
            ),
        ],
      ),

      // Improved FAB menu styling
      floatingActionButton: FabCircularMenuPlus(
        key: fabKey,
        alignment: Alignment.bottomLeft,
        fabColor: Colors.red.shade400,
        fabOpenColor: Colors.red.shade600,
        fabElevation: 8.0,
        ringDiameter: 380.0,
        ringWidth: 70.0,
        fabMargin: const EdgeInsets.only(left: 30, bottom: 20),
        ringColor: Colors.red.shade400.withOpacity(0.9),
        fabSize: 64.0,
        fabOpenIcon: const Icon(Icons.menu, color: Colors.white, size: 30),
        fabCloseIcon: const Icon(Icons.close, color: Colors.white, size: 30),
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
              size: 28,
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
              size: 28,
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
              size: 28,
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
              size: 28,
            ),
          ),
          IconButton(
            onPressed: _showChatModal,
            icon: const Icon(
              Icons.chat,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  void showRoutesPopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              children: [
                const Text(
                  "Available Routes",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Divider(height: 30),
                // ... rest of routes dialog content
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
    if (userMessage.trim().isEmpty) return;

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

      if (response.text == null || response.text!.isEmpty) {
        throw Exception("Empty response from Gemini API");
      }

      final responseText = response.text!;
      print("Response received, attempting to speak...");

      // Attempt to speak the response
      await _speakText(responseText);

      setState(() {
        _chatMessages.add({
          'isUser': false,
          'message': responseText,
        });
      });
    } catch (e, stackTrace) {
      print("Error in chat interaction: $e");
      print("Stack trace: $stackTrace");

      final errorMessage = 'Sorry, I encountered an error: $e';
      await _speakText(errorMessage);

      setState(() {
        _chatMessages.add({
          'isUser': false,
          'message': errorMessage,
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
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            // Chat Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.emergency,
                            color: Colors.red[400], size: 24),
                      ),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Emergency Assistant',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Ask about incident reports and emergency services',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chat Messages
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView.builder(
                  itemCount: _chatMessages.length + (_isChatLoading ? 1 : 0),
                  reverse: true,
                  padding: const EdgeInsets.only(top: 20),
                  itemBuilder: (context, index) {
                    // Show loading indicator as the first item when loading
                    if (_isChatLoading && index == 0) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.red[50],
                              radius: 15,
                              child: Icon(Icons.emergency,
                                  color: Colors.red[400], size: 16),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.red[400] ?? Colors.red,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Flexible(
                                      child: Text(
                                        'Please wait, SwiftPath Smart AI assistant is processing your request...',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Adjust index for actual messages
                    final messageIndex = _isChatLoading ? index - 1 : index;
                    final message =
                        _chatMessages[_chatMessages.length - 1 - messageIndex];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Row(
                        mainAxisAlignment: message['isUser']
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          if (!message['isUser']) ...[
                            CircleAvatar(
                              backgroundColor: Colors.red[50],
                              radius: 15,
                              child: Icon(Icons.emergency,
                                  color: Colors.red[400], size: 16),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: message['isUser']
                                    ? Colors.red[400]
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft: Radius.circular(
                                      message['isUser'] ? 20 : 5),
                                  bottomRight: Radius.circular(
                                      message['isUser'] ? 5 : 20),
                                ),
                              ),
                              child: Text(
                                message['message'],
                                style: TextStyle(
                                  color: message['isUser']
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          if (message['isUser']) const SizedBox(width: 10),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // Input Area
            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextField(
                        controller: _chatController,
                        decoration: InputDecoration(
                          hintText: 'Ask about emergency services...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildSendButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red[400],
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: _isChatLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.send_rounded),
        color: Colors.white,
        onPressed: _isChatLoading
            ? null
            : () {
                if (_chatController.text.isNotEmpty) {
                  _handleChatInteraction(_chatController.text);
                }
              },
      ),
    );
  }
}

class AmbulanceLoadingIndicator extends StatefulWidget {
  const AmbulanceLoadingIndicator({super.key});

  @override
  State<AmbulanceLoadingIndicator> createState() =>
      _AmbulanceLoadingIndicatorState();
}

class _AmbulanceLoadingIndicatorState extends State<AmbulanceLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Image.asset(
        'assets/images/ambulance.png',
        width: 30,
        height: 30,
      ),
    );
  }
}
