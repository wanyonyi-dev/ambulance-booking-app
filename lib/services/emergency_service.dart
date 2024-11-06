import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/emergency_request.dart';
import '../models/request_status.dart';

class EmergencyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new emergency request
  Future<String> createRequest(EmergencyRequest request) async {
    final docRef = await _firestore.collection('requests').add(request.toFirestore());
    return docRef.id;
  }

  // Update request status
  Future<void> updateRequestStatus(String requestId, RequestStatus status) async {
    await _firestore.collection('requests').doc(requestId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get user's active request
  Stream<EmergencyRequest?> getUserActiveRequest(String userId) {
    return _firestore
        .collection('requests')
        .where('patientId', isEqualTo: userId)
        .where('status', whereIn: ['pending', 'accepted'])
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return EmergencyRequest.fromFirestore(snapshot.docs.first);
    });
  }

  // Get driver's active requests
  Stream<List<EmergencyRequest>> getDriverActiveRequests(String driverId) {
    return _firestore
        .collection('requests')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => EmergencyRequest.fromFirestore(doc))
        .toList());
  }

  // Get pending requests
  Stream<List<EmergencyRequest>> getPendingRequests() {
    return _firestore
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => EmergencyRequest.fromFirestore(doc))
        .toList());
  }

  // Accept a request
  Future<void> acceptRequest(String requestId, String driverName) async {
    await _firestore.collection('requests').doc(requestId).update({
      'status': RequestStatus.accepted.name,
      'driverId': _auth.currentUser?.uid,
      'driverName': driverName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Complete a request
  Future<void> completeRequest(String requestId) async {
    await _firestore.collection('requests').doc(requestId).update({
      'status': RequestStatus.completed.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get request history
  Stream<List<EmergencyRequest>> getRequestHistory(String userId, {bool isDriver = false}) {
    final field = isDriver ? 'driverId' : 'patientId';
    return _firestore
        .collection('requests')
        .where(field, isEqualTo: userId)
        .where('status', isEqualTo: RequestStatus.completed.name)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => EmergencyRequest.fromFirestore(doc))
        .toList());
  }
}
