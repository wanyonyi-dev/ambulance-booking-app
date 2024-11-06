import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update user's last login
      await _firestore.collection('users').doc(userCredential.user?.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
        'isOnline': true,
      });

      return userCredential;
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailPassword(
      String email,
      String password,
      String role,
      String name,
      ) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(userCredential.user?.uid).set({
        'email': email,
        'name': name,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        'lastLogin': FieldValue.serverTimestamp(),
        'isAvailable': role == 'driver' ? false : null,
      });

      return userCredential;
    } catch (e) {
      throw Exception('Failed to register: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      final String? userId = _auth.currentUser?.uid;

      if (userId != null) {
        // Update user status in Firestore
        await _firestore.collection('users').doc(userId).update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
          'isAvailable': false,
        });
      }

      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Get user role
  Future<String?> getUserRole() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        return doc.get('role') as String?;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user role: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? name,
    String? phone,
    String? address,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final Map<String, dynamic> updates = {};

        if (name != null) updates['name'] = name;
        if (phone != null) updates['phone'] = phone;
        if (address != null) updates['address'] = address;

        updates['updatedAt'] = FieldValue.serverTimestamp();

        await _firestore
            .collection('users')
            .doc(user.uid)
            .update(updates);
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }
}