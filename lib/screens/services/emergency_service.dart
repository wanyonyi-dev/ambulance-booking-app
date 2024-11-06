import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/emergency_request.dart';
import '../../models/request_status.dart';

class EmergencyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get user's active request
  Stream<EmergencyRequest?> getUserActiveRequest(String userId) {
    try {
      return _firestore
          .collection('emergency_requests')
          .where('patientId', isEqualTo: userId)
          .where('status', whereIn: [
        RequestStatus.pending.toString(),
        RequestStatus.accepted.toString()
      ])
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isEmpty) return null;
        return EmergencyRequest.fromFirestore(snapshot.docs.first);
      })
          .handleError((error) {
        print('Error in getUserActiveRequest: $error');
        throw FirestoreException('Failed to fetch active request');
      });
    } catch (e) {
      print('Error setting up getUserActiveRequest stream: $e');
      rethrow;
    }
  }

  // Get pending requests (for drivers)
  Stream<List<EmergencyRequest>> getPendingRequests() {
    try {
      return _firestore
          .collection('emergency_requests')
          .where('status', isEqualTo: RequestStatus.pending.toString())
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
          .map((doc) => EmergencyRequest.fromFirestore(doc))
          .toList())
          .handleError((error) {
        print('Error in getPendingRequests: $error');
        throw FirestoreException('Failed to fetch pending requests');
      });
    } catch (e) {
      print('Error setting up getPendingRequests stream: $e');
      rethrow;
    }
  }

  // Get active requests (for drivers)
  Stream<List<EmergencyRequest>> getActiveRequests() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw FirestoreException('User not authenticated');

    try {
      return _firestore
          .collection('emergency_requests')
          .where('driverId', isEqualTo: userId)
          .where('status', isEqualTo: RequestStatus.accepted.toString())
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
          .map((doc) => EmergencyRequest.fromFirestore(doc))
          .toList())
          .handleError((error) {
        print('Error in getActiveRequests: $error');
        throw FirestoreException('Failed to fetch active requests');
      });
    } catch (e) {
      print('Error setting up getActiveRequests stream: $e');
      rethrow;
    }
  }

  // Get completed requests (for drivers)
  Stream<List<EmergencyRequest>> getCompletedRequests() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw FirestoreException('User not authenticated');

    try {
      return _firestore
          .collection('emergency_requests')
          .where('driverId', isEqualTo: userId)
          .where('status', isEqualTo: RequestStatus.completed.toString())
          .orderBy('timestamp', descending: true)
          .limit(50) // Limit to recent 50 completed requests
          .snapshots()
          .map((snapshot) => snapshot.docs
          .map((doc) => EmergencyRequest.fromFirestore(doc))
          .toList())
          .handleError((error) {
        print('Error in getCompletedRequests: $error');
        throw FirestoreException('Failed to fetch completed requests');
      });
    } catch (e) {
      print('Error setting up getCompletedRequests stream: $e');
      rethrow;
    }
  }

  // Create new emergency request
  Future<void> createRequest(EmergencyRequest request) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw FirestoreException('User not authenticated');

    try {
      await _firestore.collection('emergency_requests').add({
        ...request.toFirestore(),
        'timestamp': FieldValue.serverTimestamp(),
        'patientId': userId,
      });
    } catch (e) {
      print('Error creating request: $e');
      throw FirestoreException('Failed to create emergency request');
    }
  }

  // Update request status
  Future<void> updateRequestStatus(String requestId, RequestStatus status) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw FirestoreException('User not authenticated');

    try {
      await _firestore.collection('emergency_requests').doc(requestId).update({
        'status': status.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (status == RequestStatus.accepted) ...{
          'driverId': userId,
          'driverName': _auth.currentUser?.displayName,
        }
      });
    } catch (e) {
      print('Error updating request status: $e');
      throw FirestoreException('Failed to update request status');
    }
  }
}

class FirestoreException implements Exception {
  final String message;
  FirestoreException(this.message);

  @override
  String toString() => message;
}