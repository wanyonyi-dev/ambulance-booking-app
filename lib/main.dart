import 'package:ambulance_system/screens/admin/admin_dashboard.dart';
import 'package:ambulance_system/screens/auth/login_screen.dart';
import 'package:ambulance_system/screens/driver/booking_details_screen.dart';
import 'package:ambulance_system/screens/driver/driver_home_screen.dart';
import 'package:ambulance_system/screens/patient/patient_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AmbulanceBookingApp());
}

class AmbulanceBookingApp extends StatelessWidget {
  const AmbulanceBookingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ambulance Booking System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.grey[100],
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.grey[800]),
          titleTextStyle: GoogleFonts.poppins(
            color: Colors.grey[800],
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade200),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade400),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          // Show splash screen while checking authentication state
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }

          // If user is authenticated, check their type in Firestore
          if (authSnapshot.hasData) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(authSnapshot.data!.uid)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const SplashScreen();
                }

                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;

                  // Route to appropriate screen based on user type
                  switch (userData['userType']) {
                    case 'patient':
                      return PatientScreen();
                    case 'driver':
                      return DriverScreen();
                    case 'admin':
                      return AdminDashboard();
                    default:
                    // Invalid user type, sign out and show login
                      FirebaseAuth.instance.signOut();
                      return const LoginScreen();
                  }
                }

                // No user data exists, sign out and show login
                FirebaseAuth.instance.signOut();
                return const LoginScreen();
              },
            );
          }

          // Not authenticated, show login screen
          return const LoginScreen();
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/patient-home': (context) => PatientScreen(),
        '/driver-home': (context) => DriverScreen(),
        '/admin-dashboard': (context) => AdminDashboard(),
        '/booking-details': (context) => const BookingDetailsScreen(emergencyType: '', description: '',),
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_hospital_rounded,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Emergency Response',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(
              color: Colors.red[400],
            ),
          ],
        ),
      ),
    );
  }
}