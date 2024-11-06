import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverScreen extends StatefulWidget {
  @override
  _DriverScreenState createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedStatus = 'pending';
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  bool _hasActiveRequest = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserProfile();
    _getCurrentLocation();
    _checkActiveRequest();
  }

  Future<void> _checkActiveRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final activeRequests = await FirebaseFirestore.instance
          .collection('emergencies')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      setState(() {
        _hasActiveRequest = activeRequests.docs.isNotEmpty;
      });
    }
  }

  Future<Position?> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions denied';
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _currentPosition = position);
      return position;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
      return null;
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _navigateToEmergency(DocumentSnapshot emergency) async {
    final data = emergency.data() as Map<String, dynamic>;
    if (data['latitude'] == null || data['longitude'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location not available for this emergency')),
      );
      return;
    }

    final url = 'https://www.google.com/maps/dir/?api=1&destination=${data['latitude']},${data['longitude']}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch navigation')),
      );
    }
  }

  Future<void> _acceptEmergencyRequest(DocumentSnapshot emergency) async {
    try {
      if (_hasActiveRequest) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You already have an active request. Please complete it first.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final data = emergency.data() as Map<String, dynamic>;
      final driverUser = FirebaseAuth.instance.currentUser;

      // Update emergency status
      await emergency.reference.update({
        'status': 'accepted',
        'driverId': driverUser?.uid,
        'driverName': driverUser?.displayName,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Update driver's active request status
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverUser?.uid)
          .update({
        'activeRequests': 1,
        'lastAcceptedRequest': emergency.id,
      });

      setState(() {
        _hasActiveRequest = true;
      });

      // Send notification to patient
      final patientFcmToken = data['patientFcmToken'];
      if (patientFcmToken != null) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'to': patientFcmToken,
          'notification': {
            'title': 'Emergency Request Accepted',
            'body': 'A driver has accepted your emergency request and is on their way.',
          },
          'data': {
            'emergencyId': emergency.id,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
        });
      }

      Navigator.pop(context); // Close the details modal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Emergency request accepted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Switch to the Active tab
      _tabController.animateTo(1);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeEmergencyRequest(DocumentSnapshot emergency) async {
    try {
      final driverUser = FirebaseAuth.instance.currentUser;

      // Update emergency status
      await emergency.reference.update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Reset driver's active request status
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverUser?.uid)
          .update({
        'activeRequests': 0,
        'lastAcceptedRequest': null,
        'completedRequests': FieldValue.increment(1),
      });

      setState(() {
        _hasActiveRequest = false;
      });

      Navigator.pop(context); // Close the details modal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Emergency request completed successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Switch to the Completed tab
      _tabController.animateTo(2);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Map<String, dynamic> _userProfile = {};

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(user.uid)
          .get();
      setState(() {
        _userProfile = doc.data() ?? {};
      });
    }
  }

  void _showProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: NetworkImage(_userProfile['photoUrl'] ??
                            'https://via.placeholder.com/100'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  _userProfile['name'] ?? 'Driver Name',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Email: ${_userProfile['email'] ?? 'email@example.com'}',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 24),
                _buildStatCard(),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  child: Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Completed', '${_userProfile['completedRequests'] ?? 0}'),
                _buildStatItem('Active', '${_userProfile['activeRequests'] ?? 0}'),
                _buildStatItem('Rating', '${_userProfile['rating']?.toStringAsFixed(1) ?? 'N/A'}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 14)),
      ],
    );
  }

  void _showEmergencyDetails(DocumentSnapshot emergency) {
    final data = emergency.data() as Map<String, dynamic>;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency Details',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildDetailItem(Icons.description, 'Description', data['description']),
            _buildDetailItem(Icons.access_time, 'Time',
                data['timestamp'].toDate().toString()),
            _buildDetailItem(Icons.location_on, 'Location',
                data['address'] ?? 'Unknown location'),
            _buildDetailItem(Icons.info_outline, 'Status',
                data['status'].toUpperCase()),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (data['status'] == 'pending' && !_hasActiveRequest)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptEmergencyRequest(emergency),
                      child: Text('Accept Request'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                if (data['status'] == 'accepted')
                  Expanded(
                    child: Column(
                      children: [
                        ElevatedButton(
                          onPressed: () => _navigateToEmergency(emergency),
                          child: Text('Navigate'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => _completeEmergencyRequest(emergency),
                          child: Text('Complete Request'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(width: 16),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Response'),
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
          IconButton(
            icon: Icon(Icons.person),
            onPressed: _showProfile,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
          onTap: (index) {
            setState(() {
              _selectedStatus = index == 0 ? 'pending' :
              index == 1 ? 'accepted' : 'completed';
            });
          },
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEmergencyList('pending'),
          _buildEmergencyList('accepted'),
          _buildEmergencyList('completed'),
        ],
      ),
    );
  }

  Widget _buildEmergencyList(String status) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: status == 'accepted'
          ? FirebaseFirestore.instance
          .collection('emergencies')
          .where('status', isEqualTo: status)
          .where('driverId', isEqualTo: user?.uid)
          .orderBy('timestamp', descending: true)
          .snapshots()
          : status == 'completed'
          ? FirebaseFirestore.instance
          .collection('emergencies')
          .where('status', isEqualTo: status)
          .where('driverId', isEqualTo: user?.uid)
          .orderBy('timestamp', descending: true)
          .snapshots()
          : FirebaseFirestore.instance
          .collection('emergencies')
          .where('status', isEqualTo: status)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final emergencies = snapshot.data!.docs;

        if (emergencies.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  status == 'pending' ? Icons.hourglass_empty :
                  status == 'accepted' ? Icons.directions_car :
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  status == 'pending' ? 'No pending emergencies' :
                  status == 'accepted' ? 'No active emergencies' :
                  'No completed emergencies',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: emergencies.length,
          itemBuilder: (context, index) {
            final emergency = emergencies[index];
            final data = emergency.data() as Map<String, dynamic>;

            // Skip showing pending emergencies if driver has an active request
            if (status == 'pending' && _hasActiveRequest) {
              return SizedBox.shrink();
            }

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(data['status']),
                  child: Icon(
                    _getStatusIcon(data['status']),
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  data['description'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time: ${data['timestamp'].toDate().toString()}',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Location: ${data['address'] ?? 'Unknown location'}',
                      style: TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                trailing: Icon(Icons.chevron_right),
                onTap: () => _showEmergencyDetails(emergency),
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.access_time;
      case 'accepted':
        return Icons.directions_car;
      case 'completed':
        return Icons.check;
      default:
        return Icons.help_outline;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}