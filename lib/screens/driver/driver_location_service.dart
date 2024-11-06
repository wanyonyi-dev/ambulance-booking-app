import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class DriverLocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Reference to driver's location document
  DocumentReference get _driverLocationRef =>
      _firestore.collection('driver_locations').doc(_auth.currentUser?.uid);

  // Update driver location
  Future<void> updateLocation(Position position) async {
    if (_auth.currentUser == null) {
      throw 'No authenticated user found';
    }

    try {
      await _driverLocationRef.set({
        'location': GeoPoint(position.latitude, position.longitude),
        'heading': position.heading,
        'speed': position.speed,
        'timestamp': FieldValue.serverTimestamp(),
        'isOnline': true,
        'driverId': _auth.currentUser?.uid,
      }, SetOptions(merge: true));
    } catch (e) {
      throw 'Failed to update location: $e';
    }
  }

  // Update driver status
  Future<void> updateStatus({required bool isOnline}) async {
    if (_auth.currentUser == null) {
      throw 'No authenticated user found';
    }

    try {
      await _driverLocationRef.set({
        'isOnline': isOnline,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw 'Failed to update status: $e';
    }
  }

  // Clean up when driver goes offline
  Future<void> cleanupDriverLocation() async {
    if (_auth.currentUser == null) return;

    try {
      await _driverLocationRef.set({
        'isOnline': false,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Failed to cleanup driver location: $e');
    }
  }
}