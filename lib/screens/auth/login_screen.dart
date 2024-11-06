import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../patient/patient_home_screen.dart';
import '../driver/driver_home_screen.dart';
import '../admin/admin_dashboard.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInUser(String email, String password, String userType) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final DocumentSnapshot userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
      if (userDoc.exists && userDoc['userType'] == userType) {
        return userCredential;
      } else {
        await _auth.signOut();
        throw 'User is not authorized as a $userType';
      }
    } catch (e) {
      throw 'Failed to sign in: $e';
    }
  }

  Future<UserCredential> registerUser(String email, String password, String userType) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      Map<String, dynamic> userData = {
        'email': email,
        'userType': userType,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(userCredential.user!.uid).set(userData);

      return userCredential;
    } catch (e) {
      throw 'Failed to register: $e';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _userType = 'patient';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _navigateToUserScreen(String userId) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!mounted) return;

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String userType = userData['userType'];

        Widget destinationScreen;
        switch (userType) {
          case 'patient':
            destinationScreen = PatientScreen();
            break;
          case 'driver':
            destinationScreen = DriverScreen();
            break;
          case 'admin':
            destinationScreen = AdminDashboard();
            break;
          default:
            throw 'Invalid user type';
        }

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => destinationScreen),
              (Route<dynamic> route) => false,
        );
      } else {
        throw 'User profile not found';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Navigation error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (_isLogin) {
          UserCredential userCredential = await _authService.signInUser(
            _emailController.text.trim(),
            _passwordController.text,
            _userType,
          );

          if (mounted) {
            await _navigateToUserScreen(userCredential.user!.uid);
          }
        } else {
          if (_passwordController.text != _confirmPasswordController.text) {
            throw 'Passwords do not match';
          }

          UserCredential userCredential = await _authService.registerUser(
            _emailController.text.trim(),
            _passwordController.text,
            _userType,
          );

          if (mounted) {
            await _navigateToUserScreen(userCredential.user!.uid);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    switch (_userType) {
      case 'driver':
        if (!value.contains('DRIVER')) {
          return 'invalid Driver password contact developer';
        }
        break;
      case 'admin':
        if (!value.contains('ADMIN')) {
          return 'invalid Admin password contact developer';
        }
        break;
      default:
        break;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
        body: Container(
        decoration: BoxDecoration(
        gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
        Theme.of(context).primaryColor.withOpacity(0.1),
    Colors.white,
    ],
    ),
    ),
    child: SafeArea(
    child: SingleChildScrollView(
    child: ConstrainedBox(
    constraints: BoxConstraints(
    minHeight: size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
    ),
    child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24.0),
    child: Form(
    key: _formKey,
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
    const SizedBox(height: 40),
    Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
    color: Theme.of(context).primaryColor.withOpacity(0.1),
    shape: BoxShape.circle,
    ),
    child: Icon(
    Icons.local_hospital,
    size: 60,
    color: Theme.of(context).primaryColor,
    ),
    ),
    const SizedBox(height: 24),
    Text(
    _isLogin ? 'Welcome Back' : 'Create Account',
    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
    fontWeight: FontWeight.bold,
    color: Theme.of(context).primaryColor,
    ),
    textAlign: TextAlign.center,
    ),
    const SizedBox(height: 8),
    Text(
    _isLogin ? 'Sign in to continue' : 'Fill in your details to get started',
    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
    color: Colors.grey[600],
    ),
    textAlign: TextAlign.center,
    ),
    const SizedBox(height: 32),
    Container(
    decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    color: Colors.grey[50],
    border: Border.all(color: Colors.grey[300]!),
    ),
    child: DropdownButtonFormField<String>(
    value: _userType,
    decoration: InputDecoration(
    labelText: 'User Type',
    border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide.none,
    ),
    prefixIcon: const Icon(Icons.person_outline),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    items: const [
    DropdownMenuItem(value: 'patient', child: Text('Patient')),
    DropdownMenuItem(value: 'driver', child: Text('Driver')),
    DropdownMenuItem(value: 'admin', child: Text('Admin')),
    ],
    onChanged: (String? newValue) {
    if (newValue != null) {
    setState(() {
    _userType = newValue;
    _passwordController.clear();
    _confirmPasswordController.clear();
    });
    }
    },
    ),
    ),
    const SizedBox(height: 16),
    Container(
    decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    color: Colors.grey[50],
    border: Border.all(color: Colors.grey[300]!),
    ),
    child: TextFormField(
    controller: _emailController,
    keyboardType: TextInputType.emailAddress,
    decoration: InputDecoration(
    labelText: 'Email',
    border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide.none,
    ),
    prefixIcon: const Icon(Icons.email_outlined),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    validator: _validateEmail,
    ),
    ),
    const SizedBox(height: 16),
    Container(
    decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    color: Colors.grey[50],
    border: Border.all(color: Colors.grey[300]!),
    ),
    child: TextFormField(
    controller: _passwordController,
    obscureText: _obscurePassword,
    decoration: InputDecoration(
    labelText: 'Password',
    border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide.none,
    ),
    prefixIcon: const Icon(Icons.lock_outline),
    suffixIcon: IconButton(
    icon: Icon(
    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
    ),
    onPressed: () {
    setState(() {
    _obscurePassword = !_obscurePassword;
    });
    },
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    helperText: !_isLogin ? _getPasswordRequirementText() : null,
    helperMaxLines: 2,
    ),
    validator: _validatePassword,
    ),
    ),
    const SizedBox(height: 16),
    if (!_isLogin) ...[
    Container(
    decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    color: Colors.grey[50],
    border: Border.all(color: Colors.grey[300]!),
    ),
    child: TextFormField(
    controller: _confirmPasswordController,
    obscureText: _obscurePassword,
    decoration: InputDecoration(
    labelText: 'Confirm Password',
    border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide.none,
    ),
    prefixIcon: const Icon(Icons.lock_outline),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    validator: (value) {
    if (value != _passwordController.text) {
    return 'Passwords do not match';
    }
    return null;
    },
    ),
    ),
    const SizedBox(height: 16),
    ],
    const SizedBox(height: 24),
    ElevatedButton(
    onPressed: _isLoading ? null : _handleSubmit,
    style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 16),
    backgroundColor: Theme.of(context).primaryColor,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    ),
    elevation: 0,
    ),
    child: _isLoading
    ? const SizedBox(
    height: 20,
    width: 20,
    child: CircularProgressIndicator(
    strokeWidth: 2,
    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
    ),
    )
        : Text(
    _isLogin ? 'Sign In' : 'Create Account',
    style: const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    ),
    ),
    ),
    const SizedBox(height: 16),
    TextButton(
    onPressed: () {
    setState(() {
    _isLogin = !_isLogin;
    _formKey.currentState?.reset();
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    });
    },
    child: Text(
    _isLogin ? 'Don\'t have an account? Register' : 'Already have an account? Sign In',
      style: TextStyle(
        color: Theme.of(context).primaryColor,
        fontWeight: FontWeight.w600,
      ),
    ),
    ),
      const SizedBox(height: 24),
    ],
    ),
    ),
    ),
    ),
    ),
    ),
        ),
    );
  }

  String _getPasswordRequirementText() {
    switch (_userType) {
      case 'driver':
        return 'Password must be at least 8 characters';
      case 'admin':
        return 'Password must be at least 8 characters';
      default:
        return 'Password must be at least 8 characters';
    }
  }
}