import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ambulance_system/main.dart';
import 'package:ambulance_system/screens/auth/login_screen.dart';
import 'package:ambulance_system/screens/patient/patient_home_screen.dart';
import 'package:ambulance_system/screens/patient/booking_details_screen.dart';
import 'package:ambulance_system/screens/driver/driver_home_screen.dart';
import 'package:ambulance_system/screens/admin/admin_dashboard.dart';

void main() {
  group('AmbulanceBookingApp Widget Tests', () {
    testWidgets('App should start with login screen', (WidgetTester tester) async {
      await tester.pumpWidget(const AmbulanceBookingApp());

      expect(find.text('Login'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('Login screen should have all required elements', (WidgetTester tester) async {
      await tester.pumpWidget(const AmbulanceBookingApp());

      // Verify login form elements
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      // Verify user type selection
      expect(find.byType(SegmentedButton<String>), findsOneWidget);
      expect(find.text('Patient'), findsOneWidget);
      expect(find.text('Driver'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
    });

    testWidgets('Login form should validate empty fields', (WidgetTester tester) async {
      await tester.pumpWidget(const AmbulanceBookingApp());

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    group('User Type Navigation Tests', () {
      testWidgets('Patient login should navigate to PatientHomeScreen',
              (WidgetTester tester) async {
            await tester.pumpWidget(const AmbulanceBookingApp());

            // Select patient user type
            await tester.tap(find.text('Patient'));
            await tester.pump();

            // Fill login form
            await tester.enterText(
                find.widgetWithText(TextFormField, 'Email'),
                'patient@test.com'
            );
            await tester.enterText(
                find.widgetWithText(TextFormField, 'Password'),
                'password123'
            );

            await tester.tap(find.byType(ElevatedButton));
            await tester.pumpAndSettle();

            expect(find.byType(PatientHomeScreen), findsOneWidget);
            expect(find.text('Emergency Services'), findsOneWidget);
          });

      testWidgets('Driver login should navigate to DriverHomeScreen',
              (WidgetTester tester) async {
            await tester.pumpWidget(const AmbulanceBookingApp());

            // Select driver user type
            await tester.tap(find.text('Driver'));
            await tester.pump();

            // Fill login form
            await tester.enterText(
                find.widgetWithText(TextFormField, 'Email'),
                'driver@test.com'
            );
            await tester.enterText(
                find.widgetWithText(TextFormField, 'Password'),
                'password123'
            );

            await tester.tap(find.byType(ElevatedButton));
            await tester.pumpAndSettle();

            expect(find.byType(DriverHomeScreen), findsOneWidget);
            expect(find.text('Driver Dashboard'), findsOneWidget);
          });

      testWidgets('Admin login should navigate to AdminDashboard',
              (WidgetTester tester) async {
            await tester.pumpWidget(const AmbulanceBookingApp());

            // Select admin user type
            await tester.tap(find.text('Admin'));
            await tester.pump();

            // Fill login form
            await tester.enterText(
                find.widgetWithText(TextFormField, 'Email'),
                'admin@test.com'
            );
            await tester.enterText(
                find.widgetWithText(TextFormField, 'Password'),
                'password123'
            );

            await tester.tap(find.byType(ElevatedButton));
            await tester.pumpAndSettle();

            expect(find.byType(AdminDashboard), findsOneWidget);
            expect(find.text('Admin Dashboard'), findsOneWidget);
          });
    });

    group('PatientHomeScreen Tests', () {
      testWidgets('Should display all emergency types', (WidgetTester tester) async {
        await tester.pumpWidget(
            MaterialApp(home: const PatientHomeScreen())
        );

        expect(find.text('Life Support'), findsOneWidget);
        expect(find.text('Pediatric'), findsOneWidget);
        expect(find.text('General'), findsOneWidget);
        expect(find.text('Non-Emergency'), findsOneWidget);

        // Verify emergency cards
        expect(find.byType(Card), findsNWidgets(4));
      });

      testWidgets('Emergency cards should navigate to booking screen',
              (WidgetTester tester) async {
            await tester.pumpWidget(
                MaterialApp(home: const PatientHomeScreen())
            );

            await tester.tap(find.text('Life Support'));
            await tester.pumpAndSettle();

            expect(find.byType(BookingDetailsScreen), findsOneWidget);
            expect(find.text('Life Support Booking'), findsOneWidget);
          });
    });

    group('BookingDetailsScreen Tests', () {
      testWidgets('Should have all booking form elements',
              (WidgetTester tester) async {
            await tester.pumpWidget(
                MaterialApp(
                    home: BookingDetailsScreen(emergencyType: 'Life Support', description: '',)
                )
            );

            expect(find.text('Your Location'), findsOneWidget);
            expect(find.text('Emergency Description'), findsOneWidget);
            expect(find.text('Request Ambulance'), findsOneWidget);
          });

      testWidgets('Should validate empty description',
              (WidgetTester tester) async {
            await tester.pumpWidget(
                MaterialApp(
                    home: BookingDetailsScreen(emergencyType: 'Life Support', description: '',)
                )
            );

            await tester.tap(find.text('Request Ambulance'));
            await tester.pump();

            expect(find.text('Please describe the emergency'), findsOneWidget);
          });

      testWidgets('Should show confirmation dialog on valid submission',
              (WidgetTester tester) async {
            await tester.pumpWidget(
                MaterialApp(
                    home: BookingDetailsScreen(emergencyType: 'Life Support', description: '',)
                )
            );

            await tester.enterText(
                find.byType(TextFormField),
                'Test emergency description'
            );

            await tester.tap(find.text('Request Ambulance'));
            await tester.pumpAndSettle();

            expect(find.text('Booking Confirmed'), findsOneWidget);
            expect(
                find.text('Your ambulance request has been sent. Please wait for confirmation.'),
                findsOneWidget
            );
          });
    });

    group('DriverHomeScreen Tests', () {
      testWidgets('Should display availability toggle and requests',
              (WidgetTester tester) async {
            await tester.pumpWidget(
                MaterialApp(home: const DriverHomeScreen())
            );

            expect(find.text('Available for Service'), findsOneWidget);
            expect(find.byType(Switch), findsOneWidget);
            expect(find.text('Incoming Requests'), findsOneWidget);
          });
    });

    group('AdminDashboard Tests', () {
      testWidgets('Should display statistics and ambulance list',
              (WidgetTester tester) async {
            await tester.pumpWidget(
                MaterialApp(home: const AdminDashboard())
            );

            expect(find.text('Active Ambulances'), findsOneWidget);
            expect(find.text('Pending Requests'), findsOneWidget);
            expect(find.text('Registered Ambulances'), findsOneWidget);
            expect(find.byType(FloatingActionButton), findsOneWidget);
          });
    });

    group('Responsive Layout Tests', () {
      testWidgets('Screens should be responsive', (WidgetTester tester) async {
        const Size smallScreen = Size(320, 480);
        const Size largeScreen = Size(1024, 1366);

        // Test LoginScreen
        await tester.binding.setSurfaceSize(smallScreen);
        await tester.pumpWidget(const AmbulanceBookingApp());
        expect(find.byType(LoginScreen), findsOneWidget);

        await tester.binding.setSurfaceSize(largeScreen);
        await tester.pumpWidget(const AmbulanceBookingApp());
        expect(find.byType(LoginScreen), findsOneWidget);

        // Test PatientHomeScreen
        await tester.binding.setSurfaceSize(smallScreen);
        await tester.pumpWidget(MaterialApp(home: const PatientHomeScreen()));
        expect(find.byType(GridView), findsOneWidget);

        await tester.binding.setSurfaceSize(largeScreen);
        await tester.pumpWidget(MaterialApp(home: const PatientHomeScreen()));
        expect(find.byType(GridView), findsOneWidget);

        await tester.binding.setSurfaceSize(null);
      });
    });
  });
}
