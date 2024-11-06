import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PatientScreen extends StatefulWidget {
  const PatientScreen({super.key});

  @override
  _PatientScreenState createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  File? _image;
  Position? _currentPosition;
  String? _currentAddress;
  bool _isLoading = false;
  int _selectedIndex = 0;
  bool _locationPermissionGranted = false;
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _setupPushNotifications();
  }

  Future<void> _setupPushNotifications() async {
    // Request notification permissions
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get the FCM token
    String? token = await messaging.getToken();
    if (token != null) {
      // Store the token in Firestore for the current user
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('patients')
            .doc(user.uid)
            .set({
          'fcmToken': token,
        }, SetOptions(merge: true));
      }
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.notification!.body ?? ''),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'VIEW',
              onPressed: () {
                // Navigate to request history
                setState(() {
                  _selectedIndex = 1;
                });
              },
            ),
          ),
        );
      }
    });
  }

  Future<void> _getAddressFromCoordinates() async {
    if (_currentPosition != null) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          setState(() {
            _currentAddress =
            '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}';
          });
        }
      } catch (e) {
        print('Error getting address: $e');
      }
    }
  }

  Future<void> _getImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _image = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking photo: $e')),
      );
    }
  }

  Future<void> _cancelRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('emergencies')
          .doc(requestId)
          .update({'status': 'cancelled'});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request cancelled successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Navigate to login screen or handle sign out as needed
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enable location services'),
          action: SnackBarAction(
            label: 'SETTINGS',
            onPressed: () => Geolocator.openLocationSettings(),
          ),
        ),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location permissions permanently denied'),
          action: SnackBarAction(
            label: 'SETTINGS',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      return;
    }

    setState(() {
      _locationPermissionGranted = true;
    });
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    if (!_locationPermissionGranted) {
      await _checkLocationPermission();
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      );

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      await _getAddressFromCoordinates();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  Future<void> _submitEmergencyRequest() async {
    if (!_locationPermissionGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enable location access to submit request')),
      );
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Waiting for location... Please try again')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('User not logged in');
        }

        // Get the user's FCM token
        String? fcmToken = await messaging.getToken();

        await FirebaseFirestore.instance.collection('emergencies').add({
          'description': _descriptionController.text,
          'timestamp': FieldValue.serverTimestamp(),
          'location': GeoPoint(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          'address': _currentAddress,
          'status': 'pending',
          'patientId': user.uid,
          'patientName': user.displayName,
          'patientFcmToken': fcmToken,
          'hasImage': _image != null,
        });

        _descriptionController.clear();
        setState(() {
          _image = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Emergency request sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildLocationDisplay() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Current Location',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            SizedBox(height: 8),
            if (_currentPosition != null) ...[
              Text(
                'Address:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(_currentAddress ?? 'Getting address...'),
              SizedBox(height: 8),
              Text(
                'Coordinates:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}\nLong: ${_currentPosition!.longitude.toStringAsFixed(6)}',
              ),
            ] else
              Text(
                _isLoading
                    ? 'Getting your location...'
                    : 'Location not available. Please tap "Get Location"',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyForm() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Describe Your Emergency',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 8 : 12),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Please provide details about your emergency...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please describe your emergency';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),
          _buildLocationDisplay(),
          SizedBox(height: isSmallScreen ? 12 : 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: isSmallScreen ? double.infinity : screenWidth / 2 - 12,
                child: ElevatedButton.icon(
                  onPressed: _getImage,
                  icon: Icon(Icons.camera_alt),
                  label: Text('Take Photo'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: isSmallScreen ? double.infinity : screenWidth / 2 - 12,
                child: ElevatedButton.icon(
                  onPressed: _getCurrentLocation,
                  icon: Icon(Icons.location_on),
                  label: Text(_currentPosition == null
                      ? 'Get Location'
                      : 'Update Location'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_image != null) ...[
            SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.file(
                _image!,
                height: isSmallScreen ? 150 : 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          SizedBox(height: 24),
          if (_isLoading)
            Center(child: CircularProgressIndicator())
          else
            Container(
              width: double.infinity,
              height: isSmallScreen ? 48 : 56,
              child: ElevatedButton(
                onPressed: _submitEmergencyRequest,
                child: Text(
                  'REQUEST EMERGENCY ASSISTANCE',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestsHistory() {
    final user = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    if (user == null) {
      return Center(
        child: Text('Please login to view your request history'),
      );
    }

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('emergencies')
            .where('patientId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: isSmallScreen ? 48 : 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No emergency requests yet',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              return Future.delayed(Duration(milliseconds: 500));
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                vertical: isSmallScreen ? 8 : 16,
                horizontal: isSmallScreen ? 12 : 16,
              ),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final DocumentSnapshot document = snapshot.data!.docs[index];
                final Map<String, dynamic> data = document.data() as Map<String, dynamic>;
                final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                final status = data['status'] as String? ?? 'unknown';
                final address = data['address'] as String?;

                return Dismissible(
                  key: Key(document.id),
                  direction: status == 'pending'
                      ? DismissDirection.endToStart
                      : DismissDirection.none,
                  confirmDismiss: (direction) async {
                    if (status == 'pending') {
                      return await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Cancel Request'),
                            content: Text('Are you sure you want to cancel this emergency request?'),
                            actions: <Widget>[
                              TextButton(
                                child: Text('No'),
                                onPressed: () => Navigator.of(context).pop(false),
                              ),
                              TextButton(
                                child: Text('Yes'),
                                onPressed: () => Navigator.of(context).pop(true),
                              ),
                            ],
                          );
                        },
                      );
                    }
                    return false;
                  },
                  onDismissed: (direction) {
                    if (status == 'pending') {
                      _cancelRequest(document.id);
                    }
                  },
                  background: Container(
                    color: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    alignment: AlignmentDirectional.centerEnd,
                    child: Icon(
                      Icons.cancel,
                      color: Colors.white,
                    ),
                  ),
                  child: Card(
                    margin: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 6 : 8,
                      horizontal: 0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  data['description'] ?? 'No description',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 14 : 16,
                                  ),
                                ),
                              ),
                              if (status == 'pending')
                                TextButton(
                                  onPressed: () => _cancelRequest(document.id),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: isSmallScreen ? 12 : 14,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (address != null) ...[
                            SizedBox(height: 8),
                            Text(
                              'Location:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallScreen ? 12 : 14,
                              ),
                            ),
                            Text(
                              address,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: isSmallScreen ? 12 : 14,
                              ),
                            ),
                          ],
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallScreen ? 12 : 14,
                              ),
                            ),
                          ),
                          if (timestamp != null) ...[
                            SizedBox(height: 8),
                            Text(
                              'Submitted: ${_formatDateTime(timestamp)}',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: isSmallScreen ? 12 : 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange[800]!;
      case 'cancelled':
        return Colors.red[800]!;
      case 'completed':
        return Colors.green[800]!;
      default:
        return Colors.grey[800]!;
    }
  }
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildProfile() {
    final user = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: isSmallScreen ? 40 : 50,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Icon(Icons.person,
                        size: isSmallScreen ? 40 : 50,
                        color: Colors.grey[400])
                        : null,
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  Text(
                    user?.displayName ?? 'Anonymous User',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (user?.email != null) ...[
                    SizedBox(height: 4),
                    Text(
                      user!.email!,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  _buildProfileOption(
                    icon: Icons.edit,
                    title: 'Edit Profile',
                    onTap: () {
                      // Navigate to edit profile screen
                    },
                    isSmallScreen: isSmallScreen,
                  ),
                  Divider(height: 1),
                  _buildProfileOption(
                    icon: Icons.settings,
                    title: 'Settings',
                    onTap: () {
                      // Navigate to settings screen
                    },
                    isSmallScreen: isSmallScreen,
                  ),
                  const Divider(height: 1),
                  _buildProfileOption(
                    icon: Icons.logout,
                    title: 'Sign Out',
                    onTap: _signOut,
                    isSmallScreen: isSmallScreen,
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isSmallScreen,
    bool isDestructive = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: isSmallScreen ? 4 : 8,
      ),
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : null,
        size: isSmallScreen ? 24 : 28,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : null,
          fontSize: isSmallScreen ? 15 : 16,
        ),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0
              ? 'Emergency Request'
              : _selectedIndex == 1
              ? 'Request History'
              : 'Profile',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width < 600 ? 18 : 20,
          ),
        ),
        backgroundColor: Colors.red,
        elevation: 0,
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 600 ? 12 : 16,
                vertical: MediaQuery.of(context).size.width < 600 ? 16 : 24,
              ),
              child: _buildEmergencyForm(),
            ),
            _buildRequestsHistory(),
            _buildProfile(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: MediaQuery.of(context).size.width < 600 ? 65 : 80,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.emergency),
            label: 'Emergency',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}