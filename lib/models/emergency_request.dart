import 'package:ambulance_system/models/request_status.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyRequest {
  final String id;
  final String description;
  final String? imageUrl;
  final GeoPoint location;
  final String patientId;
  final String? driverId;
  final RequestStatus status;
  final DateTime timestamp;
  final DateTime? updatedAt;
  final String? patientName;
  final String? driverName;

  EmergencyRequest({
    required this.id,
    required this.description,
    this.imageUrl,
    required this.location,
    required this.patientId,
    this.driverId,
    required this.status,
    required this.timestamp,
    this.updatedAt,
    this.patientName,
    this.driverName,
  });

  factory EmergencyRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmergencyRequest(
      id: doc.id,
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      location: data['location'] as GeoPoint,
      patientId: data['patientId'] ?? '',
      driverId: data['driverId'],
      status: RequestStatus.values.firstWhere(
            (e) => e.name == (data['status'] ?? 'pending'),
        orElse: () => RequestStatus.pending,
      ),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      patientName: data['patientName'],
      driverName: data['driverName'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'description': description,
      'imageUrl': imageUrl,
      'location': location,
      'patientId': patientId,
      'driverId': driverId,
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'patientName': patientName,
      'driverName': driverName,
    };
  }
}
