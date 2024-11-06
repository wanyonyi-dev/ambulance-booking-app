import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _driverEmailController = TextEditingController();
  final TextEditingController _vehicleNumberController = TextEditingController();
  final TextEditingController _adminNameController = TextEditingController();
  final TextEditingController _adminEmailController = TextEditingController();
  final TextEditingController _adminPhoneController = TextEditingController();
  bool _isLoading = false;
  String? _adminPhotoUrl;
  User? currentUser;

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
  }

  Future<void> _loadAdminProfile() async {
    setState(() => _isLoading = true);
    try {
      currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final adminDoc = await FirebaseFirestore.instance
            .collection('admins')
            .doc(currentUser!.uid)
            .get();

        if (adminDoc.exists) {
          final adminData = adminDoc.data() as Map<String, dynamic>;
          setState(() {
            _adminNameController.text = adminData['name'] ?? '';
            _adminEmailController.text = adminData['email'] ?? '';
            _adminPhoneController.text = adminData['phone'] ?? '';
            _adminPhotoUrl = adminData['photoUrl'];
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error loading profile: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _driverNameController.dispose();
    _driverEmailController.dispose();
    _vehicleNumberController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPhoneController.dispose();
    super.dispose();
  }
  Future<void> _showAddDriverDialog() async {
    // Clear the controllers before showing the dialog
    _driverNameController.clear();
    _driverEmailController.clear();
    _vehicleNumberController.clear();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Driver'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _driverNameController,
                decoration: InputDecoration(
                  labelText: 'Driver Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) =>
                value?.isEmpty ?? true ? 'Please enter driver name' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _driverEmailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter email';
                  }
                  // Basic email validation
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _vehicleNumberController,
                decoration: InputDecoration(
                  labelText: 'Vehicle Number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.directions_car),
                ),
                validator: (value) =>
                value?.isEmpty ?? true ? 'Please enter vehicle number' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addNewDriver,
            child: Text('Add Driver'),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewDriver() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        // Create a new driver document with default values
        await FirebaseFirestore.instance.collection('drivers').add({
          'name': _driverNameController.text,
          'email': _driverEmailController.text,
          'vehicleNumber': _vehicleNumberController.text,
          'photoUrl': 'https://via.placeholder.com/150', // Default photo
          'rating': 0.0,
          'completedRequests': 0,
          'activeRequests': 0,
          'status': 'available',
          'createdAt': FieldValue.serverTimestamp(),
        });

        Navigator.pop(context);
        _showSuccessSnackBar('Driver added successfully');
      } catch (e) {
        _showErrorSnackBar('Error adding driver: $e');
      }
    }
  }

  Widget _buildDashboardOverview() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('emergencies').snapshots(),
      builder: (context, emergencySnapshot) {
        if (emergencySnapshot.hasError) {
          return _buildErrorWidget('Error loading emergency data');
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('drivers').snapshots(),
          builder: (context, driverSnapshot) {
            if (driverSnapshot.hasError) {
              return _buildErrorWidget('Error loading driver data');
            }

            if (!emergencySnapshot.hasData || !driverSnapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final emergencies = emergencySnapshot.data!.docs;
            final drivers = driverSnapshot.data!.docs;

            return _buildDashboardContent(emergencies, drivers);
          },
        );
      },
    );
  }

  Widget _buildDashboardContent(
      List<QueryDocumentSnapshot> emergencies, List<QueryDocumentSnapshot> drivers) {
    final stats = _calculateStats(emergencies);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeHeader(),
                SizedBox(height: 24),
                _buildStatsGrid(stats, drivers.length),
                SizedBox(height: 24),
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _buildRecentActivityList(emergencies),
        ),
      ],
    );
  }

  Widget _buildWelcomeHeader() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: _adminPhotoUrl != null
                  ? NetworkImage(_adminPhotoUrl!)
                  : null,
              child: _adminPhotoUrl == null
                  ? Icon(Icons.person, size: 30)
                  : null,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  Text(
                    _adminNameController.text.isNotEmpty
                        ? _adminNameController.text
                        : 'Admin',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, int> _calculateStats(List<QueryDocumentSnapshot> emergencies) {
    return {
      'pending': emergencies
          .where((doc) =>
      (doc.data() as Map<String, dynamic>)['status'] == 'pending')
          .length,
      'active': emergencies
          .where((doc) =>
      (doc.data() as Map<String, dynamic>)['status'] == 'accepted')
          .length,
      'completed': emergencies
          .where((doc) =>
      (doc.data() as Map<String, dynamic>)['status'] == 'completed')
          .length,
    };
  }

  Widget _buildStatsGrid(Map<String, int> stats, int driversCount) {
    final List<MapEntry<String, dynamic>> statsData = [
      MapEntry('Pending\nRequests', {
        'value': stats['pending'],
        'color': Colors.orange,
        'icon': Icons.access_time
      }),
      MapEntry('Active\nRequests', {
        'value': stats['active'],
        'color': Colors.blue,
        'icon': Icons.directions_car
      }),
      MapEntry('Completed\nRequests', {
        'value': stats['completed'],
        'color': Colors.green,
        'icon': Icons.check_circle
      }),
      MapEntry('Available\nDrivers', {
        'value': driversCount,
        'color': Colors.purple,
        'icon': Icons.person
      }),
    ];

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: statsData.length,
      itemBuilder: (context, index) {
        final stat = statsData[index];
        return _buildStatCard(
          stat.key,
          stat.value['value'].toString(),
          stat.value['color'],
          stat.value['icon'],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.7),
              color,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Reduced vertical padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // Added to minimize column height
            children: [
              Icon(icon, size: 28, color: Colors.white), // Reduced icon size
              const SizedBox(height: 4), // Reduced spacing
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20, // Reduced font size
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2), // Reduced spacing
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12, // Reduced font size
                  color: Colors.white.withOpacity(0.9),
                ),
                maxLines: 2, // Limit to 2 lines
                overflow: TextOverflow.ellipsis, // Handle text overflow gracefully
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildRecentActivityList(List<QueryDocumentSnapshot> emergencies) {
    final recentEmergencies = emergencies.take(5).toList();

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: recentEmergencies.length,
        separatorBuilder: (context, index) => Divider(height: 1),
        itemBuilder: (context, index) {
          final emergency = recentEmergencies[index].data() as Map<String, dynamic>;
          final timestamp = (emergency['timestamp'] as Timestamp).toDate();

          return ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getStatusColor(emergency['status']).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getStatusIcon(emergency['status']),
                color: _getStatusColor(emergency['status']),
              ),
            ),
            title: Text(
              emergency['description'] ?? 'No description',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Status: ${emergency['status'].toUpperCase()}\n'
                  '${DateFormat.yMd().add_jm().format(timestamp)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            isThreeLine: true,
          );
        },
      ),
    );
  }

  Widget _buildDriverManagement() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('drivers').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget('Error loading drivers');
        }

        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final drivers = snapshot.data!.docs;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Driver Management',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showAddDriverDialog,
                          icon: Icon(Icons.add),
                          label: Text('Add Driver'),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final driver = drivers[index].data() as Map<String, dynamic>;
                  return _buildDriverCard(driver, drivers[index].id);
                },
                childCount: drivers.length,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver, String driverId) {
    return Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Row(
    children: [
    CircleAvatar(
    radius: 30,
    backgroundImage: NetworkImage(
    driver['photoUrl'] ?? 'https://via.placeholder.com/150',
    ),
    ),
    SizedBox(width: 16),
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    driver['name'] ?? 'No Name',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    ),
    ),
    SizedBox(height: 4),
    Text(
    driver['email'] ?? 'No Email',
    style: TextStyle(color: Colors.grey[600]),
    ),
    SizedBox(height: 4),
    Text(
    'Vehicle: ${driver['vehicleNumber'] ?? 'N/A'}',
    style: TextStyle(color: Colors.grey[600]),
    ),
    ],
    ),
    ),
    PopupMenuButton(
    icon: Icon(Icons.more_vert),
    itemBuilder: (context) => [
    PopupMenuItem(
    value: 'edit',
    child: ListTile(
    leading: Icon(Icons.edit),
    title: Text('Edit'),
    ),
    ),
    PopupMenuItem(
    value: 'delete',
    child: ListTile(
    leading: Icon(Icons.delete, color: Colors.red),
    title: Text('Delete', style: TextStyle(color: Colors.red)),
    ),
    ),
    ],
      onSelected: (value) async {
        if (value == 'edit') {
          _showEditDriverDialog(driver, driverId);
        } else if (value == 'delete') {
          await _deleteDriver(driverId);
        }
      },
    ),
    ],
    ),
      SizedBox(height: 16),
      Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildDriverStat(
              'Completed',
              '${driver['completedRequests'] ?? 0}',
              Icons.check_circle,
            ),
            _buildDriverStat(
              'Active',
              '${driver['activeRequests'] ?? 0}',
              Icons.directions_car,
            ),
            _buildDriverStat(
              'Rating',
              '${(driver['rating'] ?? 0.0).toStringAsFixed(1)}',
              Icons.star,
            ),
          ],
        ),
      ),
    ],
    ),
    ),
    );
  }

  Widget _buildDriverStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileManagement() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(height: 24),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _profileFormKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _updateProfilePhoto,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: _adminPhotoUrl != null
                                ? NetworkImage(_adminPhotoUrl!)
                                : null,
                            child: _adminPhotoUrl == null
                                ? Icon(Icons.person, size: 50)
                                : null,
                          ),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Theme.of(context).primaryColor,
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    TextFormField(
                      controller: _adminNameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter your name' : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _adminEmailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter your email' : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _adminPhoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter your phone number' : null,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _updateProfile,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text('Update Profile'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfilePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => _isLoading = true);

      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('admin_photos')
            .child('${currentUser!.uid}.jpg');

        await ref.putFile(File(image.path));
        final photoUrl = await ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('admins')
            .doc(currentUser!.uid)
            .update({'photoUrl': photoUrl});

        setState(() => _adminPhotoUrl = photoUrl);
        _showSuccessSnackBar('Profile photo updated successfully');
      } catch (e) {
        _showErrorSnackBar('Error updating profile photo: $e');
      }

      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (_profileFormKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        await FirebaseFirestore.instance
            .collection('admins')
            .doc(currentUser!.uid)
            .update({
          'name': _adminNameController.text,
          'email': _adminEmailController.text,
          'phone': _adminPhoneController.text,
        });

        _showSuccessSnackBar('Profile updated successfully');
      } catch (e) {
        _showErrorSnackBar('Error updating profile: $e');
      }

      setState(() => _isLoading = false);
    }
  }

  Future<void> _showEditDriverDialog(Map<String, dynamic> driver, String driverId) async {
    _driverNameController.text = driver['name'] ?? '';
    _driverEmailController.text = driver['email'] ?? '';
    _vehicleNumberController.text = driver['vehicleNumber'] ?? '';

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Driver'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _driverNameController,
                decoration: InputDecoration(
                  labelText: 'Driver Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                value?.isEmpty ?? true ? 'Please enter driver name' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _driverEmailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                value?.isEmpty ?? true ? 'Please enter email' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _vehicleNumberController,
                decoration: InputDecoration(
                  labelText: 'Vehicle Number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                value?.isEmpty ?? true ? 'Please enter vehicle number' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _updateDriver(driverId),
            child: Text('Update Driver'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateDriver(String driverId) async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(driverId)
            .update({
          'name': _driverNameController.text,
          'email': _driverEmailController.text,
          'vehicleNumber': _vehicleNumberController.text,
        });

        Navigator.pop(context);
        _showSuccessSnackBar('Driver updated successfully');
      } catch (e) {
        _showErrorSnackBar('Error updating driver: $e');
      }
    }
  }

  Future<void> _deleteDriver(String driverId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Driver'),
        content: Text('Are you sure you want to delete this driver?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(driverId)
            .delete();
        _showSuccessSnackBar('Driver deleted successfully');
      } catch (e) {
        _showErrorSnackBar('Error deleting driver: $e');
      }
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign Out'),
        content: Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.access_time;
      case 'accepted':
        return Icons.directions_car;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: _confirmSignOut,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboardOverview(),
          _buildDriverManagement(),
          _buildProfileManagement(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people),
            label: 'Drivers',
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