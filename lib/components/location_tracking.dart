import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationTracker {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Method to listen for real-time location updates
  void listenToLocationUpdates(String userId, Function(LatLng) onUpdate) {
    _dbRef.child('emergency-vehicle-location/$userId/origin').onValue.listen(
      (DatabaseEvent event) {
        if (event.snapshot.exists) {
          final data = event.snapshot.value as Map;
          final latitude = data['latitude'];
          final longitude = data['longitude'];
          if (latitude != null && longitude != null) {
            LatLng updatedLocation = LatLng(latitude, longitude);
            onUpdate(
                updatedLocation); // Pass the updated location back to the caller
          }
        } else {
          print("No location updates found for userId: $userId");
        }
      },
    );
  }
}
