import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'backend/firebase config/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ResQ Maps',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  // Updated initial camera position
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(23.753222, 90.449305),
    zoom: 14.0,
  );

  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = false;
  bool _useInitialLocation = false;
  bool _isPulsing = false; // New variable to control pulse animation
  int _selectedIndex = 0; // For bottom navigation

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation1;
  late Animation<double> _pulseAnimation2;
  late Animation<double> _pulseAnimation3;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _requestLocationPermission();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Create three pulse animations with different delays
    _pulseAnimation1 = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    ));

    _pulseAnimation2 = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    _pulseAnimation3 = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    ));

    // Don't start pulsing immediately - wait for button press
    setState(() {
      _useInitialLocation = true;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Request location permission
  Future<void> _requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermissionDialog();
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        _getCurrentLocation();
      }
    } catch (e) {
      print('Error requesting location permission: $e');
      // Keep using initial location if permission fails
    }
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _useInitialLocation = false; // Switch to actual location
        _isLoading = false;
      });

      // Move camera to current location
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 16.0,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _useInitialLocation = true; // Fallback to initial location
      });
      print('Error getting current location: $e');
      // Show snackbar to inform user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to get current location. Using default location.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // Show permission dialog
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission'),
          content: const Text(
            'This app needs location permission to show your current location on the map. Using default location for now.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openAppSettings();
              },
              child: const Text('Settings'),
            ),
          ],
        );
      },
    );
  }

  // Toggle pulse animation
  void _togglePulse() {
    setState(() {
      _isPulsing = !_isPulsing;
    });

    if (_isPulsing) {
      _pulseController.repeat();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency signal activated!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      _pulseController.stop();
      _pulseController.reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency signal deactivated'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Handle bottom navigation tap
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
      // Home - do nothing or navigate to home
        break;
      case 1:
      // Search/Find - toggle pulse
        _togglePulse();
        break;
      case 2:
      // Profile or settings
        break;
    }
  }

  // Get the location to use for pulse (current or initial)
  LatLng _getPulseLocation() {
    if (_currentPosition != null && !_useInitialLocation) {
      return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }
    return _initialPosition.target;
  }

  // Generate animated circles for pulse effect
  Set<Circle> _generatePulseCircles() {
    if (!_isPulsing) return {}; // Only show circles when pulsing

    final LatLng center = _getPulseLocation();
    return {
      // Pulse circle 1
      Circle(
        circleId: const CircleId('pulse_1'),
        center: center,
        radius: 30 + (_pulseAnimation1.value * 70), // 30 to 100 meters
        fillColor: Colors.red.withOpacity((1 - _pulseAnimation1.value) * 0.3),
        strokeColor: Colors.red.withOpacity((1 - _pulseAnimation1.value) * 0.8),
        strokeWidth: 2,
      ),
      // Pulse circle 2
      Circle(
        circleId: const CircleId('pulse_2'),
        center: center,
        radius: 30 + (_pulseAnimation2.value * 70),
        fillColor: Colors.red.withOpacity((1 - _pulseAnimation2.value) * 0.3),
        strokeColor: Colors.red.withOpacity((1 - _pulseAnimation2.value) * 0.8),
        strokeWidth: 2,
      ),
      // Pulse circle 3
      Circle(
        circleId: const CircleId('pulse_3'),
        center: center,
        radius: 30 + (_pulseAnimation3.value * 70),
        fillColor: Colors.red.withOpacity((1 - _pulseAnimation3.value) * 0.3),
        strokeColor: Colors.red.withOpacity((1 - _pulseAnimation3.value) * 0.8),
        strokeWidth: 2,
      ),
      // Static accuracy circle
      Circle(
        circleId: const CircleId('accuracy'),
        center: center,
        radius: 25,
        fillColor: Colors.red.withOpacity(0.1),
        strokeColor: Colors.red.withOpacity(0.5),
        strokeWidth: 1,
      ),
    };
  }

  // Generate markers
  Set<Marker> _generateMarkers() {
    final LatLng location = _getPulseLocation();
    final bool isCurrentLocation = _currentPosition != null && !_useInitialLocation;
    return {
      Marker(
        markerId: const MarkerId('location_marker'),
        position: location,
        infoWindow: InfoWindow(
          title: isCurrentLocation ? 'Your Location' : 'Default Location',
          snippet: isCurrentLocation
              ? (_isPulsing ? 'Emergency signal active!' : 'Searching nearby...')
              : (_isPulsing ? 'Emergency signal active!' : 'Dhaka, Bangladesh - Searching...'),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _isPulsing
              ? BitmapDescriptor.hueRed
              : (isCurrentLocation ? BitmapDescriptor.hueBlue : BitmapDescriptor.hueOrange),
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ResQ Maps'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_useInitialLocation)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Using default location. Tap the location button to try getting your current location.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),
          if (_isPulsing)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'EMERGENCY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return GoogleMap(
                initialCameraPosition: _initialPosition,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                myLocationEnabled: false,
                myLocationButtonEnabled: true,
                compassEnabled: true,
                mapToolbarEnabled: true,
                zoomControlsEnabled: true,
                markers: _generateMarkers(),
                circles: _generatePulseCircles(),
              );
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Searching for your location...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Status indicator
          if (_useInitialLocation)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_off, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Using default location - Dhaka, Bangladesh',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _getCurrentLocation,
                      child: const Text(
                        'Get Location',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        tooltip: 'Get Current Location',
        backgroundColor: _useInitialLocation ? Colors.orange : Colors.blue,
        child: _isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Icon(_useInitialLocation ? Icons.my_location_outlined : Icons.my_location),
      ),
      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isPulsing ? Colors.red : Colors.blue,
                shape: BoxShape.circle,
                boxShadow: _isPulsing ? [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ] : null,
              ),
              child: Icon(
                Icons.search,
                color: Colors.white,
                size: 28,
              ),
            ),
            label: _isPulsing ? 'Stop' : 'Find',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}