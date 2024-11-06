import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get user role and status from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      return userDoc.data() as Map<String, dynamic>?;
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  // General sign-in with role and status verification
  Future<UserCredential> signInWithRole(String email, String password, String expectedRole) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get user data
      final userData = await getUserData(userCredential.user!.uid);
      if (userData == null) throw Exception('User data not found');

      // Verify user role
      String? role = userData['role'] as String?;
      bool? isActive = userData['isActive'] as bool?;

      if (role != expectedRole) {
        await _auth.signOut();
        throw Exception('User is not authorized as $expectedRole');
      }

      // Verify account status
      if (isActive == false) {
        await _auth.signOut();
        throw Exception('Account is inactive. Please contact support.');
      }

      return userCredential;
    } catch (e) {
      if (e is FirebaseAuthException) {
        throw Exception('Firebase Auth Error: ${e.message}');
      } else {
        throw Exception('Sign-in failed: $e');
      }
    }
  }

  // Sign in driver
  Future<UserCredential> signInDriver(String email, String password) {
    return signInWithRole(email, password, 'driver');
  }

  // Sign in admin
  Future<UserCredential> signInAdmin(String email, String password) {
    return signInWithRole(email, password, 'admin');
  }

  // Sign in patient (default role)
  Future<UserCredential> signInPatient(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      if (e is FirebaseAuthException) {
        throw Exception('Firebase Auth Error: ${e.message}');
      } else {
        throw Exception('Sign-in failed: $e');
      }
    }
  }

  // Register new user with role
  Future<UserCredential> registerUser(String email, String password, String role) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      return userCredential;
    } catch (e) {
      if (e is FirebaseAuthException) {
        throw Exception('Firebase Auth Error: ${e.message}');
      } else {
        throw Exception('Registration failed: $e');
      }
    }
  }

  // Update user's last login
  Future<void> updateLastLogin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Failed to update last login: $e');
    }
  }

  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      return await getUserData(uid);
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Disable user account
  Future<void> disableUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isActive': false,
      });
    } catch (e) {
      throw Exception('Failed to disable user: $e');
    }
  }

  // Enable user account
  Future<void> enableUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isActive': true,
      });
    } catch (e) {
      throw Exception('Failed to enable user: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
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

  // Change password
  Future<void> changePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }
}
