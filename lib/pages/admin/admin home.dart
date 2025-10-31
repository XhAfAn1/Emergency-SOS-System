import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:resqmob/pages/profile/profile.dart';
import 'package:url_launcher/url_launcher.dart';


class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  final List<Marker> _markers = [];
  LatLng? _currentPosition;
  late final MapController _mapController;
  TextEditingController replycontroller = TextEditingController();
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<Position>? _positionStream;
  bool _isMapReady = false;
  bool _showSafeAlerts = true;

  // Data subscriptions
  StreamSubscription<QuerySnapshot>? _stationsSubscription;
  StreamSubscription<QuerySnapshot>? _hospitalsSubscription;
  StreamSubscription<QuerySnapshot>? _alertSubscription;
  StreamSubscription<QuerySnapshot>? _usersSubscription;
  StreamSubscription<QuerySnapshot>? _feedbackSubscription;

  // UI State
  int _selectedNavIndex = 0;
  String _currentView = 'dashboard';
  bool _showSidePanels = true;

  // Statistics
  int _totalUsers = 0;
  int _totalStations = 0;
  int _totalHospitals = 0;
  int _totalAlerts = 0;
  int _activeAlerts = 0;
  int _safeAlerts = 0;
  int _totalFeedback = 0;

  // Data lists for detailed views
  List<Map<String, dynamic>> _usersList = [];
  List<Map<String, dynamic>> _alertsList = [];
  List<Map<String, dynamic>> _stationsList = [];
  List<Map<String, dynamic>> _hospitalsList = [];
  List<Map<String, dynamic>> _feedbackList = [];

  // Search controllers
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Pulse Animation Controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation1;
  late Animation<double> _pulseAnimation2;
  late Animation<double> _pulseAnimation3;

  // Store active alert locations for pulse effect
  List<LatLng> _activeAlertLocations = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializePulseAnimations();
    _initializeMap();
    _loadAllData();
    _setupFirebaseMessaging();
  }

  void _initializePulseAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

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

    _pulseController.repeat();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _stationsSubscription?.cancel();
    _hospitalsSubscription?.cancel();
    _alertSubscription?.cancel();
    _usersSubscription?.cancel();
    _feedbackSubscription?.cancel();
    _pulseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setupFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showNotificationSnackBar(
          message.notification?.title ?? 'Notification',
          message.notification?.body ?? '',
        );
      }
    });
  }

  void _showNotificationSnackBar(String title, String body) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1976D2),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Load all data for list views
  Future<void> _loadAllData() async {
    _loadAlertsData();
    _loadUsersData();
    _loadStationsData();
    _loadHospitalsData();
    _loadFeedbackData();
  }

  void _loadUsersData() {
    _usersSubscription?.cancel();
    _usersSubscription = FirebaseFirestore.instance
        .collection('Users')
        .snapshots()
        .listen((QuerySnapshot querySnapshot) {
      if (!mounted) return;

      final List<Map<String, dynamic>> users = [];
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (doc.id != currentUserId) {
          data['id'] = doc.id;
          users.add(data);
        }
      }

      setState(() {
        _usersList = users;
        _totalUsers = users.length;
      });
    });
  }

  void _loadAlertsData() {
    _alertSubscription?.cancel();
    _alertSubscription = FirebaseFirestore.instance
        .collection('Alerts').orderBy('timestamp', descending: true)
        .snapshots()
        .listen((QuerySnapshot querySnapshot) {
      if (!mounted) return;

      final List<Map<String, dynamic>> alerts = [];
      final List<LatLng> activeLocations = [];
      int activeCount = 0;
      int safeCount = 0;

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        alerts.add(data);

        final status = data['status']?.toString().toLowerCase() ?? '';
        final isDanger = status == 'danger';
        final isActive = status == 'active' || isDanger;
        final isSafe = status == 'safe' || status == 'resolved';

        if (isActive) activeCount++;
        if (isSafe) safeCount++;

        if (isActive && data['location'] != null) {
          final location = data['location'];
          double? latitude, longitude;

          if (location is Map<String, dynamic>) {
            latitude = location['latitude']?.toDouble();
            longitude = location['longitude']?.toDouble();
          }

          if (latitude != null && longitude != null) {
            activeLocations.add(LatLng(latitude, longitude));
          }
        }
      }

      setState(() {
        _alertsList = alerts;
        _totalAlerts = alerts.length;
        _activeAlerts = activeCount;
        _safeAlerts = safeCount;
        _activeAlertLocations = activeLocations;
      });
    });
  }

  void _loadStationsData() {
    _stationsSubscription?.cancel();
    _stationsSubscription = FirebaseFirestore.instance
        .collection('/Resources/PoliceStations/Stations')
        .snapshots()
        .listen((QuerySnapshot querySnapshot) {
      if (!mounted) return;

      final List<Map<String, dynamic>> stations = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        stations.add(data);
      }

      setState(() {
        _stationsList = stations;
        _totalStations = stations.length;
      });
    });
  }

  void _loadHospitalsData() {
    _hospitalsSubscription?.cancel();
    _hospitalsSubscription = FirebaseFirestore.instance
        .collection('/Resources/Hospitals/hospitals')
        .snapshots()
        .listen((QuerySnapshot querySnapshot) {
      if (!mounted) return;

      final List<Map<String, dynamic>> hospitals = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        hospitals.add(data);
      }

      setState(() {
        _hospitalsList = hospitals;
        _totalHospitals = hospitals.length;
      });
    });

  }

  void _loadFeedbackData() {
    _feedbackSubscription?.cancel();
    _feedbackSubscription = FirebaseFirestore.instance
        .collection('/Resources/Feedbacks/feedbacks')
        .snapshots()
        .listen((QuerySnapshot querySnapshot) {
      if (!mounted) return;

      final List<Map<String, dynamic>> feedback = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        feedback.add(data);
      }

      setState(() {
        _feedbackList = feedback;
        _totalFeedback = feedback.length;
      });
    });
  }

  //map initialization

  Future<void> _initializeMap() async {
    try {
      await _loadAllAlertMarkers();
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && _isMapReady) {
        _fitMarkersInView();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize map: ${e.toString()}';
        _currentPosition = const LatLng(23.769224, 90.425574);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  //load markers in map

  Future<void> _loadAllUserMarkers() async {
    _usersSubscription?.cancel();

    try {
      _usersSubscription = FirebaseFirestore.instance
          .collection('Users')
          .snapshots()
          .listen((QuerySnapshot querySnapshot) {
        if (!mounted) return;

        final List<Marker> loadedMarkers = [];
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        int userCount = 0;

        for (var doc in querySnapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            final docId = doc.id;

            if (docId == currentUserId) continue;

            final location = data['location'];
            if (location == null) continue;

            double? latitude;
            double? longitude;

            if (location is Map<String, dynamic>) {
              latitude = location['latitude']?.toDouble();
              longitude = location['longitude']?.toDouble();
            } else if (location is List && location.length >= 2) {
              latitude = location[0]?.toDouble();
              longitude = location[1]?.toDouble();
            }

            if (latitude == null || longitude == null) continue;
            if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) continue;

            final marker = Marker(
              width: 40,
              height: 50,
              point: LatLng(latitude, longitude),
              child: GestureDetector(
                onTap: () => _showUserInfoDialog(data),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // Shadow
                    Transform.translate(
                      offset: const Offset(2, 3),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 0,
                            height: 0,
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(width: 8, color: Colors.transparent),
                                right: BorderSide(width: 8, color: Colors.transparent),
                                bottom: BorderSide(width: 14, color: Colors.black12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Main pin shape
                    Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, 10),
                          child: Container(
                            width: 0,
                            height: 0,
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(width: 8, color: Colors.transparent),
                                right: BorderSide(width: 8, color: Colors.transparent),
                                bottom: BorderSide(width: 14, color: Color(0xFF4CAF50)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
            loadedMarkers.add(marker);
            userCount++;
          } catch (e) {
            debugPrint('Error processing user ${doc.id}: $e');
          }
        }

        if (!mounted) return;
        setState(() {
          _markers.clear();
          _markers.addAll(loadedMarkers);
          _totalUsers = userCount;
          _currentView = 'users';
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isMapReady) {
            _fitMarkersInView();
          }
        });
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load users: ${e.toString()}';
      });
    }
  }

  Future<void> _loadAllStationMarkers() async {
    _stationsSubscription?.cancel();

    try {
      _stationsSubscription = FirebaseFirestore.instance
          .collection('/Resources/PoliceStations/Stations')
          .snapshots()
          .listen((QuerySnapshot querySnapshot) {
        if (!mounted) return;

        final List<Marker> loadedMarkers = [];
        int stationCount = 0;

        for (var doc in querySnapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            final location = data['location'];
            if (location == null) continue;

            double? latitude;
            double? longitude;

            if (location is Map<String, dynamic>) {
              latitude = location['latitude']?.toDouble();
              longitude = location['longitude']?.toDouble();
            } else if (location is List && location.length >= 2) {
              latitude = location[0]?.toDouble();
              longitude = location[1]?.toDouble();
            }

            if (latitude == null || longitude == null) continue;
            if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) continue;
            final marker = Marker(
              width: 40,
              height: 50,
              point: LatLng(latitude, longitude),
              child: GestureDetector(
                onTap: () {
                  _showStationInfoDialog(data);
                } ,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // Shadow
                    Transform.translate(
                      offset: const Offset(2, 3),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 0,
                            height: 0,
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(width: 8, color: Colors.transparent),
                                right: BorderSide(width: 8, color: Colors.transparent),
                                bottom: BorderSide(width: 14, color: Colors.black12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Main pin shape
                    Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(0xFF2196F3),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.local_police,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, 10),
                          child: Container(
                            width: 0,
                            height: 0,
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(width: 8, color: Colors.transparent),
                                right: BorderSide(width: 8, color: Colors.transparent),
                                bottom: BorderSide(width: 14,  color: Color(0xFF2196F3),),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
            loadedMarkers.add(marker);
            stationCount++;
          } catch (e) {
            debugPrint('Error processing station ${doc.id}: $e');
          }
        }

        if (!mounted) return;
        setState(() {
          _markers.clear();
          _markers.addAll(loadedMarkers);
          _totalStations = stationCount;
          _currentView = 'stations';
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isMapReady) {
            _fitMarkersInView();
          }
        });
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load stations: ${e.toString()}';
      });
    }
  }

  Future<void> _loadAllHospitalMarkers() async {
    _hospitalsSubscription?.cancel();

    try {
      _hospitalsSubscription = FirebaseFirestore.instance
          .collection('/Resources/Hospitals/hospitals')
          .snapshots()
          .listen((QuerySnapshot querySnapshot) {
        if (!mounted) return;

        final List<Marker> loadedMarkers = [];
        int hospitalCount = 0;

        for (var doc in querySnapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            final location = data['location'];
            if (location == null) continue;

            double? latitude;
            double? longitude;

            if (location is Map<String, dynamic>) {
              latitude = location['latitude']?.toDouble();
              longitude = location['longitude']?.toDouble();
            } else if (location is List && location.length >= 2) {
              latitude = location[0]?.toDouble();
              longitude = location[1]?.toDouble();
            }

            if (latitude == null || longitude == null) continue;
            if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) continue;
            final marker = Marker(
              width: 40,
              height: 50,
              point: LatLng(latitude, longitude),
              child: GestureDetector(
                onTap: () {
                  _showHospitalInfoDialog(data);
                } ,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // Shadow
                    Transform.translate(
                      offset: const Offset(2, 3),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 0,
                            height: 0,
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(width: 8, color: Colors.transparent),
                                right: BorderSide(width: 8, color: Colors.transparent),
                                bottom: BorderSide(width: 14, color: Colors.black12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Main pin shape
                    Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(0xFF2196F3),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.local_hospital_rounded,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, 10),
                          child: Container(
                            width: 0,
                            height: 0,
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(width: 8, color: Colors.transparent),
                                right: BorderSide(width: 8, color: Colors.transparent),
                                bottom: BorderSide(width: 14,  color: Color(0xFF2196F3),),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
            loadedMarkers.add(marker);
            hospitalCount++;
          } catch (e) {
            debugPrint('Error processing hospital ${doc.id}: $e');
          }
        }

        if (!mounted) return;
        setState(() {
          _markers.clear();
          _markers.addAll(loadedMarkers);
          _totalHospitals = hospitalCount;
          _currentView = 'hospitals';
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isMapReady) {
            _fitMarkersInView();
          }
        });
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load hospitals: ${e.toString()}';
      });
    }
  }

  Future<void> _loadAllAlertMarkers() async {
    _alertSubscription?.cancel();

    try {
      _alertSubscription = FirebaseFirestore.instance
          .collection('Alerts')
          .snapshots()
          .listen((QuerySnapshot querySnapshot) {
        if (!mounted) return;

        final List<Marker> loadedMarkers = [];
        final List<LatLng> activeLocations = [];
        int alertCount = 0;
        int activeCount = 0;
        int safeCount = 0;

        for (var doc in querySnapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            final location = data['location'];
            if (location == null) continue;

            double? latitude;
            double? longitude;

            if (location is Map<String, dynamic>) {
              latitude = location['latitude']?.toDouble();
              longitude = location['longitude']?.toDouble();
            } else if (location is List && location.length >= 2) {
              latitude = location[0]?.toDouble();
              longitude = location[1]?.toDouble();
            }

            if (latitude == null || longitude == null) continue;
            if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) continue;

            final status = data['status']?.toString().toLowerCase() ?? '';
            final isDanger = status == 'danger';
            final isActive = status == 'active' || isDanger;
            final isSafe = status == 'safe' || status == 'resolved';

            if (isActive) {
              activeCount++;
              activeLocations.add(LatLng(latitude, longitude));
            }
            if (isSafe) safeCount++;

            // Skip safe alerts if toggle is off
            if (isSafe && !_showSafeAlerts) continue;

            Color pinColor;
            IconData pinIcon;

            if (isDanger) {
              pinColor = const Color(0xFFE53E3E);
              pinIcon = Icons.dangerous;
            } else if (isActive) {
              pinColor = const Color(0xFFFF9800);
              pinIcon = Icons.warning;
            } else if (isSafe) {
              pinColor = const Color(0xFF4CAF50);
              pinIcon = Icons.check_circle;
            } else {
              pinColor = const Color(0xFF9E9E9E);
              pinIcon = Icons.help_outline;
            }
            final marker = Marker(
              width: 40,
              height: 40,
              point: LatLng(latitude, longitude),
              child: GestureDetector(
                onTap: () { _showAlertInfoDialog(context,data);},
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // Shadow
                    Transform.translate(
                      offset: const Offset(2, 3),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 0,
                            height: 0,
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(width: 8, color: Colors.transparent),
                                right: BorderSide(width: 8, color: Colors.transparent),
                                bottom: BorderSide(width: 14, color: Colors.black12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Main pin shape
                    Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: pinColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            pinIcon,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, 10),
                          child: Container(
                            width: 0,
                            height: 0,
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(width: 8, color: Colors.transparent),
                                right: BorderSide(width: 8, color: Colors.transparent),
                                bottom: BorderSide(width: 14,  color: pinColor,),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );

            loadedMarkers.add(marker);
            alertCount++;
          } catch (e) {
            debugPrint('Error processing alert ${doc.id}: $e');
          }
        }

        if (!mounted) return;
        setState(() {
          _markers.clear();
          _markers.addAll(loadedMarkers);
          _activeAlertLocations = activeLocations;
          _totalAlerts = alertCount;
          _activeAlerts = activeCount;
          _safeAlerts = safeCount;
          _currentView = 'alerts';
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isMapReady) {
            _fitMarkersInView();
          }
        });
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load alerts: ${e.toString()}';
      });
    }
  }

  // Generate pulse circles for active alerts
  List<CircleMarker> _generatePulseCircles() {
    if (_activeAlertLocations.isEmpty) return [];

    List<CircleMarker> circles = [];

    for (LatLng location in _activeAlertLocations) {
      circles.addAll([
        CircleMarker(
          point: location,
          radius: 30 + (_pulseAnimation1.value * 70),
          color: Colors.red.withOpacity((1 - _pulseAnimation1.value) * 0.3),
          borderColor: Colors.red.withOpacity((1 - _pulseAnimation1.value) * 0.8),
          borderStrokeWidth: 2,
        ),
        CircleMarker(
          point: location,
          radius: 30 + (_pulseAnimation2.value * 70),
          color: Colors.red.withOpacity((1 - _pulseAnimation2.value) * 0.3),
          borderColor: Colors.red.withOpacity((1 - _pulseAnimation2.value) * 0.8),
          borderStrokeWidth: 2,
        ),
        CircleMarker(
          point: location,
          radius: 30 + (_pulseAnimation3.value * 70),
          color: Colors.red.withOpacity((1 - _pulseAnimation3.value) * 0.3),
          borderColor: Colors.red.withOpacity((1 - _pulseAnimation3.value) * 0.8),
          borderStrokeWidth: 2,
        ),
        CircleMarker(
          point: location,
          radius: 25,
          color: Colors.red.withOpacity(0.1),
          borderColor: Colors.red.withOpacity(0.5),
          borderStrokeWidth: 1,
        ),
      ]);
    }

    return circles;
  }

// Build Users List View
  Widget _buildUsersListView() {
    final filteredUsers = _usersList.where((user) {
      if (_searchQuery.isEmpty) return true;
      final name = user['name']?.toString().toLowerCase() ?? '';
      final email = user['email']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        _buildSearchBar('Search users...'),
        Expanded(
          child: filteredUsers.isEmpty
              ? _buildEmptyState('No users found', Icons.people_outline)
              : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final user = filteredUsers[index];
              return _buildUserCard(user, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showUserInfoDialog(user),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Enhanced Profile Section
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundImage: (user['profileImageUrl'] != null &&
                            user['profileImageUrl'].toString().isNotEmpty)
                            ? NetworkImage(user['profileImageUrl'])
                            : null,
                        backgroundColor: const Color(0xFFF3F4F6),
                        child: (user['profileImageUrl'] == null ||
                            user['profileImageUrl'].toString().isEmpty)
                            ? const Icon(
                          Icons.person,
                          size: 28,
                          color: Color(0xFF6B7280),
                        )
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // User Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user['name'] ?? 'Unknown User',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'USR-${(index + 1).toString().padLeft(3, '0')}',
                              style: const TextStyle(
                                color: Color(0xFF4CAF50),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Contact Info
                      _buildInfoRow(
                        Icons.email_outlined,
                        user['email'] ?? 'No email',
                        const Color(0xFF6366F1),
                      ),
                      const SizedBox(height: 4),
                      _buildInfoRow(
                        Icons.phone_outlined,
                        user['phoneNumber'] ?? 'No phone',
                        const Color(0xFF10B981),
                      ),
                      const SizedBox(height: 4),
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        user['address'] ?? 'No address',
                        const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                ),

                // Action Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Build Alerts List View
  Widget _buildAlertsListView() {
    final filteredAlerts = _alertsList.where((alert) {
      if (_searchQuery.isEmpty) return true;
      final alertID = alert['alertId']?.toString().toLowerCase() ?? '';
      final status = alert['status']?.toString().toLowerCase() ?? '';
      final userName = alert['userName']?.toString().toLowerCase() ?? '';
      return alertID.contains(_searchQuery.toLowerCase()) ||
          status.contains(_searchQuery.toLowerCase()) ||
          userName.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        _buildSearchBar('Search alerts...'),
        Expanded(
          child: filteredAlerts.isEmpty
              ? _buildEmptyState('No alerts found', Icons.warning_outlined)
              : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: filteredAlerts.length,
            itemBuilder: (context, index) {
              final alert = filteredAlerts[index];
              return _buildAlertCard(alert);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final status = alert['status']?.toString().toLowerCase() ?? '';
    final isDanger = status == 'danger';
    final isActive = status == 'active' || isDanger;
    final isSafe = status == 'safe' || status == 'resolved';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isDanger) {
      statusColor = const Color(0xFFEF4444);
      statusIcon = Icons.dangerous_outlined;
      statusText = 'DANGER';
    } else if (isActive) {
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.warning_outlined;
      statusText = 'ACTIVE';
    } else if (isSafe) {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle_outlined;
      statusText = 'RESOLVED';
    } else {
      statusColor = const Color(0xFF6B7280);
      statusIcon = Icons.help_outline;
      statusText = 'UNKNOWN';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAlertInfoDialog(context, alert),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        statusIcon,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                alert['alertId'] ?? 'Unknown ID',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  statusText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            alert['etype'] ?? 'Unknown Type',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (alert['timestamp'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatTimestamp(alert['timestamp'] as Timestamp),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // User and Severity Info
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoRow(
                        Icons.person_outline,
                        alert['userName'] ?? 'Unknown User',
                        const Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.priority_high,
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Severity: ${alert['severity'] ?? 'N/A'}',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Location
                _buildInfoRow(
                  Icons.location_on_outlined,
                  alert['address'] ?? 'No address provided',
                  const Color(0xFFF59E0B),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // Controllers for the add station form
  final TextEditingController _stationNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  Map<String, Map<String, dynamic>> _userCache = {};
  final _formKey = GlobalKey<FormState>();
  Future<void> _addPoliceStation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final newStationRef = FirebaseFirestore.instance.collection('Resources/PoliceStations/Stations');
      final newStationData = {
        'stationId': _stationNameController.text.trim(),
        'stationName': _stationNameController.text.trim(),
        'address': _addressController.text.trim(),
        'location': {
          'latitude': double.parse(_latitudeController.text.trim()),
          'longitude': double.parse(_longitudeController.text.trim()),
        },
        'phone': _phoneController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      await newStationRef.doc(_stationNameController.text.trim()).set(newStationData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Police station added successfully!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.black,
          ),
        );
      }
      Navigator.pop(context);
      _loadAllStationMarkers();
      _loadStationsData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding police station: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.black,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            prefixIcon: Icon(icon, color: const Color(0xFF6B7280), size: 20),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Build Police Stations List View
  void _showAddStationModal(context) {
    _stationNameController.clear();
    _addressController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
    _phoneController.clear();

    showModalBottomSheet(

      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.65,
          width: MediaQuery.of(context).size.width * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.local_police_outlined, color: Color(0xFF3B82F6), size: 28),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Add New Police Station',
                        style: TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          controller: _stationNameController,
                          label: 'Station Name',
                          hint: 'Enter police station name',
                          icon: Icons.local_police_outlined,
                          validator: (value) => value!.isEmpty ? 'Station name cannot be empty' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _addressController,
                          label: 'Address',
                          hint: 'Enter full address',
                          icon: Icons.location_on_outlined,
                          validator: (value) => value!.isEmpty ? 'Address cannot be empty' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _latitudeController,
                                label: 'Latitude',
                                hint: 'e.g., 23.769',
                                icon: Icons.map_outlined,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value!.isEmpty) return 'Latitude cannot be empty';
                                  if (double.tryParse(value) == null) return 'Invalid number';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _longitudeController,
                                label: 'Longitude',
                                hint: 'e.g., 90.425',
                                icon: Icons.map_outlined,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value!.isEmpty) return 'Longitude cannot be empty';
                                  if (double.tryParse(value) == null) return 'Invalid number';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Phone Number (Optional)',
                          hint: 'Enter phone number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: _isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Icon(Icons.save_outlined, size: 20),
                            label: Text(_isLoading ? 'Saving...' : 'Save Police Station'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _isLoading ? null : _addPoliceStation,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildStationsListView() {
    final filteredStations = _stationsList.where((station) {
      if (_searchQuery.isEmpty) return true;
      final name = station['stationName']?.toString().toLowerCase() ?? '';
      final address = station['address']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase()) ||
          address.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        _buildSearchBar('Search police stations...'),
        Expanded(
          child: filteredStations.isEmpty
              ? _buildEmptyState('No stations found', Icons.local_police_outlined)
              : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: filteredStations.length,
            itemBuilder: (context, index) {
              final station = filteredStations[index];
              return _buildStationCard(station, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHospitalsListView() {
    final filteredHospitals = _hospitalsList.where((hospital) {
      if (_searchQuery.isEmpty) return true;
      final name = hospital['hospitalName']?.toString().toLowerCase() ?? '';
      final address = hospital['address']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase()) ||
          address.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        _buildSearchBar('Search hospital...'),
        Expanded(
          child: filteredHospitals.isEmpty
              ? _buildEmptyState('No hospital found', Icons.local_police_outlined)
              : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: filteredHospitals.length,
            itemBuilder: (context, index) {
              final hospital = filteredHospitals[index];
              return _buildHospitalCard(hospital, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStationCard(Map<String, dynamic> station, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showStationInfoDialog(station),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Station Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.local_police_outlined,
                    color: Color(0xFF3B82F6),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // Station Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              station['stationName'] ?? 'Unknown Station',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Contact Info
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        station['address'] ?? 'No address',
                        const Color(0xFFF59E0B),
                      ),
                      const SizedBox(height: 4),
                      _buildInfoRow(
                        Icons.phone_outlined,
                        station['phone']?.toString() ?? 'No phone',
                        const Color(0xFF10B981),
                      ),
                      const SizedBox(height: 8),

                      // Service Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '24/7 Service Available',
                          style: TextStyle(
                            color: Color(0xFF3B82F6),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHospitalCard(Map<String, dynamic> hospital, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showHospitalInfoDialog(hospital),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [

                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.local_hospital_rounded,
                    color: Color(0xFF3B82F6),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              hospital['hospitalName'] ?? 'Unknown hospital',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Contact Info
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        hospital['address'] ?? 'No address',
                        const Color(0xFFF59E0B),
                      ),
                      const SizedBox(height: 4),
                      _buildInfoRow(
                        Icons.phone_outlined,
                        hospital['phone']?.toString() ?? 'No phone',
                        const Color(0xFF10B981),
                      ),
                      const SizedBox(height: 8),

                      // Service Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '24/7 Service Available',
                          style: TextStyle(
                            color: Color(0xFF3B82F6),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Build Feedback List View
  Widget _buildFeedbackListView() {
    final filteredFeedback = _feedbackList.where((feedback) {
      if (_searchQuery.isEmpty) return true;
      final message = feedback['message']?.toString().toLowerCase() ?? '';
      final userId = feedback['userId']?.toString().toLowerCase() ?? '';
      final userEmail = feedback['userEmail']?.toString().toLowerCase() ?? '';
      return message.contains(_searchQuery.toLowerCase()) ||
          userId.contains(_searchQuery.toLowerCase()) ||
          userEmail.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        _buildSearchBar('Search feedback...'),
        Expanded(
          child: filteredFeedback.isEmpty
              ? _buildEmptyState('No feedback found', Icons.feedback_outlined)
              : RefreshIndicator(
            onRefresh: () async {
              _loadFeedbackData();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: filteredFeedback.length,
              itemBuilder: (context, index) {
                final feedback = filteredFeedback[index];
                return _buildFeedbackCard(feedback);
              },
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildFeedbackCard(Map<String, dynamic> feedback) {

    final typeColor = Colors.black;
    final userEmail = feedback['userEmail']?.toString() ?? '';
    final userId = feedback['userId']?.toString() ?? '';
    var userName = _userCache[userId]?['name'] ?? 'Unknown User';
    var userPhoto = _userCache[userId]?['profileImageUrl'];

    final data = FirebaseFirestore.instance.collection('Users').doc(feedback['userId']).get().then((doc) {
      if (doc.exists) {
        _userCache[feedback['userId']] = doc.data()!;
        userName = doc.data()!['name'];
        userPhoto = doc.data()!['profileImageUrl'];
        setState(() {

        });
      }
    });
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: typeColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row with User Info
            Row(
              children: [
                // User Profile Photo
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF4CAF50),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 23,
                    backgroundImage: (userPhoto != null && userPhoto.isNotEmpty)
                        ? NetworkImage(userPhoto)
                        : null,
                    backgroundColor: Colors.grey[200],
                    child: (userPhoto == null || userPhoto.isEmpty)
                        ? const Icon(
                      Icons.person,
                      size: 25,
                      color: Color(0xFF4CAF50),
                    )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userEmail,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (feedback['createdAt'] != null)
                        Text(
                          _formatTimestamp(feedback['createdAt'] as Timestamp),
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ID: ${feedback['id']}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Message Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              child: Text(
                feedback['message'] ?? 'No message provided',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF374151),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: Container(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(),
                ),
                const SizedBox(width: 8),
                // Reply Button
                Expanded(
                  child: InkWell(
                    onTap: () => _replyToFeedback(userEmail,feedback),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.reply_outlined,
                            size: 14,
                            color: Color(0xFF3B82F6),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Reply',
                            style: TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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

// Helper method to send email
  Future<void> _sendEmailToUser(String userEmail, Map<String, dynamic> feedback, String message) async {
    try {
      final subject = Uri.encodeComponent('Re: Your Feedback (ID: ${feedback['id']})');
      final body = Uri.encodeComponent(
          'Dear User,\n\n'
              'Thank you for your feedback:\n'
              '"${feedback['message']}"\n\n'
              'Reply From Admin:\n$message.\n\n'
              'We appreciate your input and we appreciate your contribution.\n\n'
              'Best regards,\n'
              'Admin Team'
      );

      final gmailUrl = 'https://mail.google.com/mail/?view=cm&fs=1&to=$userEmail&subject=$subject&body=$body';

      if (await canLaunchUrl(Uri.parse(gmailUrl))) {
        await launchUrl(Uri.parse(gmailUrl), mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open Gmail in browser'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening Gmail: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
// Helper method to reply to feedback
  void _replyToFeedback(String userEmail,Map<String, dynamic> feedback) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Reply to Feedback ID: ${feedback['id']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Original Message:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(feedback['message'] ?? ''),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: replycontroller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Type your reply here...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:  Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16,horizontal: 27),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              _sendEmailToUser(userEmail, feedback,replycontroller.text);
            },
            child: const Text('Send Reply'),
          ),
        ],
      ),
    );
  }
// Helper Widget for Info Rows
  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 12,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
// Helper Widget for Empty States
  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search criteria',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(String hint) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }


  //dialog box for details

  void _showUserInfoDialog(Map<String, dynamic> userData) {
    bool isNormal = userData['token'] != 'normal';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 900,
                constraints: const BoxConstraints(maxHeight: 700),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Section
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: (userData['profileImageUrl'] != null &&
                                userData['profileImageUrl'].toString().isNotEmpty)
                                ? NetworkImage(userData['profileImageUrl'])
                                : null,
                            backgroundColor: Colors.white,
                            child: (userData['profileImageUrl'] == null ||
                                userData['profileImageUrl'].toString().isEmpty)
                                ? const Icon(Icons.person, size: 40, color: Color(0xFF4CAF50))
                                : null,
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userData['name'] ?? 'Unknown User',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Registered User',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          ),
                        ],
                      ),
                    ),

                    // Content Section
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column - Personal & Location Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader('Personal Information', Icons.person_outline),
                                  const SizedBox(height: 20),
                                  _buildInfoCard([
                                    _buildEnhancedInfoRow('Full Name', userData['name'] ?? 'Not provided', Icons.badge),
                                    _buildEnhancedInfoRow('Email Address', userData['email'] ?? 'Not provided', Icons.email_outlined),
                                    _buildEnhancedInfoRow('Phone Number', userData['phoneNumber'] ?? 'Not provided', Icons.phone_outlined),
                                    _buildEnhancedInfoRow('Address', userData['address'] ?? 'Not provided', Icons.location_on_outlined),
                                  ]),

                                  const SizedBox(height: 24),

                                  _buildSectionHeader('Location Information', Icons.map_outlined),
                                  const SizedBox(height: 20),
                                  _buildInfoCard([
                                    if (userData['location'] != null) ...[
                                      _buildEnhancedInfoRow(
                                        'Latitude',
                                        userData['location']['latitude']?.toString() ?? 'Not available',
                                        Icons.my_location,
                                      ),
                                      _buildEnhancedInfoRow(
                                        'Longitude',
                                        userData['location']['longitude']?.toString() ?? 'Not available',
                                        Icons.place,
                                      ),
                                    ] else
                                      _buildEnhancedInfoRow('Location', 'Location not available', Icons.location_off),
                                  ]),
                                ],
                              ),
                            ),

                            const SizedBox(width: 32),

                            // Right Column - Emergency Contacts & Account Status
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader('Emergency Contacts', Icons.emergency),
                                  const SizedBox(height: 20),
                                  _buildEmergencyContactsSection(userData['emergencyContacts']),

                                  const SizedBox(height: 24),

                                  _buildSectionHeader('Account Status', Icons.verified_user),
                                  const SizedBox(height: 20),
                                  _buildInfoCard([
                                    _buildEnhancedInfoRow(
                                      'Safety Status',
                                      userData['isInDanger'] ? 'Danger' : 'Safe',
                                      Icons.check_circle,
                                      valueColor: userData['isInDanger'] ? Colors.red : Colors.green,
                                    ),
                                    _buildEnhancedInfoRow(
                                      'Last Updated',
                                      '${_formatTimestamp(Timestamp.fromDate(DateTime.parse(userData['createdAt'])))}',
                                      Icons.access_time,
                                    ),
                                    _buildEnhancedInfoRow(
                                      'Member Since',
                                      '${userData['createdAt']}',
                                      Icons.calendar_today,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 16.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8F9FA),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(Icons.block, size: 16, color: Color(0xFF6B7280)),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Block Status',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF6B7280),
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Switch(
                                                  value: isNormal,
                                                  onChanged: (newValue) {
                                                    _updateAccountStatus(userData['id'], newValue);
                                                    setStateDialog(() {
                                                      isNormal = newValue;
                                                    });
                                                  },
                                                  activeColor: Colors.red,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ]),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _updateAccountStatus(String uid, bool value) {
    FirebaseFirestore.instance.collection('Users').doc(uid).update({
      'token': value ? 'blocked' : 'normal',
    }).catchError((e) => print(e.toString()));
  }


  void _showStationInfoDialog(Map<String, dynamic> stationData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 800,
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_police,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stationData['stationName'] ?? 'Unknown Station',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Police Station',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),

              // Content Section
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Station Information', Icons.info_outline),
                      const SizedBox(height: 20),
                      _buildInfoCard([
                        _buildEnhancedInfoRow('Station Name', stationData['stationName'] ?? 'Not provided', Icons.local_police),
                        _buildEnhancedInfoRow('Address', stationData['address'] ?? 'Not provided', Icons.location_on_outlined),
                        _buildEnhancedInfoRow('Phone Number', stationData['phone']?.toString() ?? 'Not provided', Icons.phone_outlined),
                        if (stationData['location'] != null) ...[
                          _buildEnhancedInfoRow('Latitude', stationData['location']['latitude']?.toString() ?? 'Not available', Icons.my_location),
                          _buildEnhancedInfoRow('Longitude', stationData['location']['longitude']?.toString() ?? 'Not available', Icons.place),
                        ],
                      ]),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(onPressed: (){
                          print(stationData['id']);
                          FirebaseFirestore.instance.collection('/Resources/PoliceStations/Stations').doc(stationData['id']).delete();
                          setState(() {
                            _loadStationsData();
                          });
                          Navigator.pop(context);
                        }, icon: Icon(Icons.delete,size: 30,color: Colors.red,)),
                      )
                    ],
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  void _showHospitalInfoDialog(Map<String, dynamic> hospitalData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 800,
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_hospital_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hospitalData['hospitalName'] ?? 'Unknown hospital',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Hospitals',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),

              // Content Section
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Hospital Information', Icons.info_outline),
                      const SizedBox(height: 20),
                      _buildInfoCard([
                        _buildEnhancedInfoRow('Hospital Name', hospitalData['hospitalName'] ?? 'Not provided', Icons.local_police),
                        _buildEnhancedInfoRow('Address', hospitalData['address'] ?? 'Not provided', Icons.location_on_outlined),
                        _buildEnhancedInfoRow('Phone Number', hospitalData['phone']?.toString() ?? 'Not provided', Icons.phone_outlined),
                        if (hospitalData['location'] != null) ...[
                          _buildEnhancedInfoRow('Latitude', hospitalData['location']['latitude']?.toString() ?? 'Not available', Icons.my_location),
                          _buildEnhancedInfoRow('Longitude', hospitalData['location']['longitude']?.toString() ?? 'Not available', Icons.place),
                        ],
                      ]),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(onPressed: (){
                          FirebaseFirestore.instance.collection('/Resources/Hospitals/hospitals').doc(hospitalData['id']).delete();
                          setState(() {

                          });
                          Navigator.pop(context);
                        }, icon: Icon(Icons.delete,size: 30,color: Colors.red,)),
                      )
                    ],
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAlertInfoDialog(BuildContext context, Map<String, dynamic> alertData) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(alertData['userId'])
          .get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not found.")),
        );
        return;
      }

      final userData = userDoc.data()!;
      final status = alertData['status']?.toString().toLowerCase() ?? '';

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 1000,
            constraints: const BoxConstraints(maxHeight: 800),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: alertData['severity']!=1
                          ? [const Color(0xFFE53E3E), const Color(0xFFDC2626)]
                          : [const Color(0xFFFF9800), const Color(0xFFF57C00)],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.warning,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ALERT TYPE: ${alertData['etype'] ?? 'Unknown'}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Severity: ${alertData['severity']?.toString().toUpperCase() ?? 'UNKNOWN'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              alertData['etype'] ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (alertData['timestamp'] != null)
                            Text(
                              _formatTimestamp(alertData['timestamp'] as Timestamp),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                ),

                // Content Section
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column - User Information
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('User Information', Icons.person_outline),
                              const SizedBox(height: 20),

                              // User Profile Card
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE9ECEF)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFF4CAF50), width: 2),
                                      ),
                                      child: CircleAvatar(
                                        radius: 28,
                                        backgroundImage: (userData['profileImageUrl'] != null &&
                                            userData['profileImageUrl'].toString().isNotEmpty)
                                            ? NetworkImage(userData['profileImageUrl'])
                                            : null,
                                        backgroundColor: Colors.grey[200],
                                        child: (userData['profileImageUrl'] == null ||
                                            userData['profileImageUrl'].toString().isEmpty)
                                            ? const Icon(Icons.person, size: 30, color: Color(0xFF4CAF50))
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userData['name'] ?? 'Unknown User',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            userData['email'] ?? 'No email',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              _buildInfoCard([
                                _buildEnhancedInfoRow('Phone Number', userData['phoneNumber'] ?? 'Not provided', Icons.phone_outlined),
                                _buildEnhancedInfoRow('Address', userData['address'] ?? 'Not provided', Icons.location_on_outlined),
                              ]),

                              const SizedBox(height: 24),

                              // Emergency Contacts
                              _buildSectionHeader('Emergency Contacts', Icons.emergency),
                              const SizedBox(height: 20),
                              _buildEmergencyContactsSection(userData['emergencyContacts']),
                            ],
                          ),
                        ),

                        const SizedBox(width: 32),

                        // Right Column - Alert Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('Alert Details', Icons.info_outline),
                              const SizedBox(height: 20),

                              // Alert Message Card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: alertData['severity']!=1
                                      ? const Color(0xFFE53E3E).withOpacity(0.1)
                                      : const Color(0xFFFF9800).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: alertData['severity']!=1
                                        ? const Color(0xFFE53E3E).withOpacity(0.3)
                                        : const Color(0xFFFF9800).withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.message,
                                          color: alertData['severity']!=1 ? const Color(0xFFE53E3E) : const Color(0xFFFF9800),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Alert Message',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      alertData['message'] ?? 'No message provided',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              _buildInfoCard([
                                _buildEnhancedInfoRow('Alert ID', alertData['userId'] ?? 'Unknown', Icons.fingerprint),
                                _buildEnhancedInfoRow('Severity Level', alertData['severity']?.toString() ?? 'Unknown', Icons.priority_high),
                                _buildEnhancedInfoRow('Current Status', status.toUpperCase(), Icons.info,
                                    valueColor: alertData['severity']!=1 ? const Color(0xFFE53E3E) : const Color(0xFFFF9800)),
                                _buildEnhancedInfoRow('Location Address', alertData['address'] ?? 'No address provided', Icons.place),
                              ]),

                              const SizedBox(height: 20),

                              // Location Coordinates
                              if (alertData['location'] != null) ...[
                                _buildSectionHeader('Location Coordinates', Icons.gps_fixed),
                                const SizedBox(height: 20),
                                _buildInfoCard([
                                  _buildEnhancedInfoRow('Latitude', alertData['location']['latitude']?.toString() ?? 'Unknown', Icons.my_location),
                                  _buildEnhancedInfoRow('Longitude', alertData['location']['longitude']?.toString() ?? 'Unknown', Icons.place),
                                ]),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action Buttons
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Status indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: alertData['severity']!=1
                              ? const Color(0xFFE53E3E).withOpacity(0.1)
                              : const Color(0xFFFF9800).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: alertData['severity']!=1
                                ? const Color(0xFFE53E3E).withOpacity(0.3)
                                : const Color(0xFFFF9800).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning,
                              size: 16,
                              color: alertData['severity']!=1 ? const Color(0xFFE53E3E) : const Color(0xFFFF9800),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              alertData['severity']!=1 ? 'High Priority' : 'Medium Priority',
                              style: TextStyle(
                                color: alertData['severity']!=1 ? const Color(0xFFE53E3E) : const Color(0xFFFF9800),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error showing alert dialog: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error loading alert info")),
      );
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF4CAF50),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A202C),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildEnhancedInfoRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? const Color(0xFF1A202C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactsSection(dynamic emergencyContacts) {
    if (emergencyContacts == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFE69C)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF856404)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No emergency contacts available',
                style: TextStyle(
                  color: Color(0xFF856404),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    List<dynamic> contacts = [];
    if (emergencyContacts is List) {
      contacts = emergencyContacts;
    } else if (emergencyContacts is String) {
      try {
        contacts = [{'info': emergencyContacts}];
      } catch (e) {
        contacts = [{'info': emergencyContacts.toString()}];
      }
    }

    if (contacts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFE69C)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF856404)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No emergency contacts configured',
                style: TextStyle(
                  color: Color(0xFF856404),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: contacts.asMap().entries.map((entry) {
        int index = entry.key;
        dynamic contact = entry.value;

        return Container(
          margin: EdgeInsets.only(bottom: index < contacts.length - 1 ? 12 : 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.contact_emergency,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (contact is Map<String, dynamic>) ...[
                      Text(
                        contact['name']?.toString() ?? 'Contact ${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (contact['phoneNumber'] != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 12, color: Color(0xFF6B7280)),
                            const SizedBox(width: 4),
                            Text(
                              contact['phoneNumber'].toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (contact['relationship'] != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            contact['relationship'].toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF0EA5E9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      Text(
                        contact.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.call, color: Color(0xFF0EA5E9), size: 18),
                onPressed: () {
                  // Implement call functionality
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _fitMarkersInView() {
    if (!mounted || !_isMapReady || _markers.isEmpty) return;

    try {
      List<LatLng> points = _markers.map((marker) => marker.point).toList();

      if (points.length == 1) {
        _mapController.move(points.first, 15.0);
        return;
      }

      double minLat = points.first.latitude;
      double maxLat = points.first.latitude;
      double minLng = points.first.longitude;
      double maxLng = points.first.longitude;

      for (LatLng point in points) {
        minLat = minLat < point.latitude ? minLat : point.latitude;
        maxLat = maxLat > point.latitude ? maxLat : point.latitude;
        minLng = minLng < point.longitude ? minLng : point.longitude;
        maxLng = maxLng > point.longitude ? maxLng : point.longitude;
      }

      double latPadding = (maxLat - minLat) * 0.1;
      double lngPadding = (maxLng - minLng) * 0.1;

      LatLngBounds bounds = LatLngBounds(
        LatLng(minLat - latPadding, minLng - lngPadding),
        LatLng(maxLat + latPadding, maxLng + lngPadding),
      );

      _mapController.fitBounds(
        bounds,
        options: const FitBoundsOptions(
          padding: EdgeInsets.all(50),
          maxZoom: 17.0,
        ),
      );
    } catch (e) {
      debugPrint('Error fitting bounds: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          // Sidebar Navigation
          Container(
            width: 280,
            color: const Color(0xFF1A202C),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  child: const Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                      SizedBox(width: 12),
                      Text(
                        'Admin Panel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF2D3748), height: 1),

                // Navigation Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      _buildNavItem(0, Icons.dashboard, 'Dashboard'),
                      _buildNavItem(1, Icons.map, 'Map View'),
                      const Divider(color: Color(0xFF2D3748), height: 32),
                      _buildNavItem(2, Icons.people, 'All Users', badge: _totalUsers.toString()),
                      _buildNavItem(3, Icons.warning, 'All Alerts', badge: _totalAlerts.toString()),
                      _buildNavItem(4, Icons.local_police, 'All Stations', badge: _totalStations.toString()),
                      _buildNavItem(8, Icons.local_hospital_rounded, 'All Hospitals', badge: _totalHospitals.toString()),
                      _buildNavItem(5, Icons.feedback, 'All Feedback', badge: _totalFeedback.toString()),
                      const Divider(color: Color(0xFF2D3748), height: 32),
                      _buildNavItem(6, Icons.analytics, 'Analytics'),
                      _buildNavItem(7, Icons.settings, 'Settings'),
                    ],
                  ),
                ),

                // User Profile
                Container(
                  padding: const EdgeInsets.all(16),
                  child: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection("Users")
                        .doc(FirebaseAuth.instance.currentUser?.uid)
                        .get(),
                    builder: (context, snapshot) {
                      String? imageUrl = snapshot.data?.get("profileImageUrl");
                      String name = snapshot.data?.get("name") ?? "Admin";

                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                                ? NetworkImage(imageUrl)
                                : null,
                            backgroundColor: Colors.grey[600],
                            child: (imageUrl == null || imageUrl.isEmpty)
                                ? const Icon(Icons.person, size: 20, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Text(
                                  'Administrator',
                                  style: TextStyle(
                                    color: Color(0xFFA0AEC0),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            color: Colors.white, // White background
                            surfaceTintColor: Colors.white, // Ensures white background on newer Flutter versions
                            elevation: 4,
                            // Control the width through constraints
                            constraints: const BoxConstraints(
                              minWidth: 180, // Minimum width
                              maxWidth: 200, // Maximum width
                            ),
                            onSelected: (value) async {
                              if (value == 'profile') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => profile(
                                      uid: FirebaseAuth.instance.currentUser!.uid,
                                    ),
                                  ),
                                );
                              } else if (value == 'logout') {
                                final bool? confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: Colors.white,
                                      surfaceTintColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12.0),
                                      ),
                                      title: const Text(
                                        'Logout',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      content: const Text(
                                        'Are you sure you want to logout from your account?',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      actions: [
                                        // Cancel button
                                        OutlinedButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.grey,
                                            side: BorderSide(color: Colors.grey.shade400),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: const Text('Cancel'),
                                        ),

                                        // Logout button
                                        ElevatedButton(
                                          onPressed: () => Navigator.of(context).pop(true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: const Text('Logout'),
                                        ),
                                      ],
                                    )
                                );

                                if (confirm == true) {
                                  await FirebaseAuth.instance.signOut();
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'profile',
                                child: Row(
                                  children: [
                                    Icon(Icons.person, size: 20),
                                    SizedBox(width: 12), // Increased spacing
                                    Text('Profile'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'logout',
                                child: Row(
                                  children: [
                                    Icon(Icons.logout, size: 20, color: Colors.red),
                                    SizedBox(width: 12), // Increased spacing
                                    Text('Logout', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          _isLoading?Expanded(
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.black,
                strokeWidth: 3,
              ),
            ),
          ):
          // Main Content Area
           Expanded(
            child: Column(
              children: [
                // Top Header
                Container(
                  height: 80,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        _getPageTitle(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A202C),
                        ),
                      ),
                      const Spacer(),

                      const SizedBox(width: 24),

                      // Controls
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _isLoading ? null : () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _initializeMap();

                          _loadAllData();

                        },
                      ),
                      const SizedBox(width: 24),
                      _selectedNavIndex == 1 ? IconButton(
                        icon: Icon(_showSidePanels ? Icons.keyboard_double_arrow_right : Icons.keyboard_double_arrow_left),
                        onPressed: () {
                          setState(() {
                            _showSidePanels = !_showSidePanels;
                          });
                        },
                      ):Container(),
                      _selectedNavIndex == 4 ? IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          _showAddStationModal(context);
                        },
                      ):Container(),
                      _selectedNavIndex == 8 ? IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          _showAddHospitalModal(context);
                        },
                      ):Container(),
                    ],
                  ),
                ),

                // Content Area
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildMainContent() {
    switch (_selectedNavIndex) {
      case 0:
        return _buildDashboardView();
      case 1:
        return _buildMapView();
      case 2:
        return _buildUsersListView();
      case 3:
        return _buildAlertsListView();
      case 4:
        return _buildStationsListView();
      case 5:
        return _buildFeedbackListView();
      case 6:
        return _buildAnalyticsView();
      case 7:
        return _buildSettingsView();
      case 8:
        return _buildHospitalsListView();
      default:
        return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Cards
          Row(
            children: [
              Expanded(
                child: _buildDashboardCard(
                  'Total Users',
                  _totalUsers.toString(),
                  Icons.people,
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDashboardCard(
                  'Police Stations',
                  _totalStations.toString(),
                  Icons.local_police,
                  const Color(0xFF2196F3),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDashboardCard(
                  'Hospitals',
                  _totalHospitals.toString(),
                  Icons.local_hospital_rounded,
                  const Color(0xFF2196F3),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDashboardCard(
                  'Total Alerts',
                  _totalAlerts.toString(),
                  Icons.warning,
                  const Color(0xFFFF9800),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDashboardCard(
                  'Feedback',
                  _totalFeedback.toString(),
                  Icons.feedback,
                  const Color(0xFF9C27B0),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Recent Activity
          // Expanded(
          //   child: Card(
          //     elevation: 2,
          //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          //     child: Padding(
          //       padding: const EdgeInsets.all(24),
          //       child: Column(
          //         crossAxisAlignment: CrossAxisAlignment.start,
          //         children: [
          //           const Text(
          //             'Recent Activity',
          //             style: TextStyle(
          //               fontSize: 20,
          //               fontWeight: FontWeight.bold,
          //             ),
          //           ),
          //           const SizedBox(height: 16),
          //           Expanded(
          //             child: ListView(
          //               children: [
          //                 _buildActivityItem(
          //                   'New user registered',
          //                   'John Doe joined the platform',
          //                   Icons.person_add,
          //                   const Color(0xFF4CAF50),
          //                   '2 minutes ago',
          //                 ),
          //                 _buildActivityItem(
          //                   'Emergency alert received',
          //                   'High priority alert from downtown area',
          //                   Icons.warning,
          //                   const Color(0xFFE53E3E),
          //                   '5 minutes ago',
          //                 ),
          //                 _buildActivityItem(
          //                   'Feedback submitted',
          //                   'User reported a bug in the mobile app',
          //                   Icons.feedback,
          //                   const Color(0xFF9C27B0),
          //                   '10 minutes ago',
          //                 ),
          //                 _buildActivityItem(
          //                   'Police station updated',
          //                   'Central Station contact information updated',
          //                   Icons.local_police,
          //                   const Color(0xFF2196F3),
          //                   '15 minutes ago',
          //                 ),
          //               ],
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, IconData icon, Color color, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    return Row(
      children: [
        // Map Area
        Expanded(
          flex: _showSidePanels ? 3 : 1,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildMapContent(),
            ),
          ),
        ),

        // Side Panel
        if (_showSidePanels)
          Container(
            width: 350,
            margin: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
            child: Column(
              children: [
                // Map Controls
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Map Controls',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildControlButton(
                              'Alerts',
                              Icons.warning,
                              const Color(0xFFFF9800),
                              _currentView == 'alerts',
                              _loadAllAlertMarkers,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildControlButton(
                              'Stations',
                              Icons.local_police,
                              const Color(0xFF2196F3),
                              _currentView == 'stations',
                              _loadAllStationMarkers,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _buildControlButton(
                              'Users',
                              Icons.people,
                              const Color(0xFF4CAF50),
                              _currentView == 'users',
                              _loadAllUserMarkers,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildControlButton(
                              'Hospitals',
                              Icons.local_hospital_rounded,
                              const Color(0xFF2196F3),
                              _currentView == 'hospitals',
                              _loadAllHospitalMarkers,
                            ),
                          ),

                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Center all mark',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _buildControlButton(
                              'Center',
                              Icons.center_focus_strong,
                              const Color(0xFF9C27B0),
                              false,
                              _fitMarkersInView,
                            ),
                          ),

                        ],
                      ),


                      // Safe Alerts Toggle (only show when viewing alerts)
                      if (_currentView == 'alerts') ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Show Safe Alerts',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Switch(
                              value: _showSafeAlerts,
                              onChanged: (value) {
                                setState(() {
                                  _showSafeAlerts = value;
                                });
                                _loadAllAlertMarkers();
                              },
                              activeColor: const Color(0xFF4CAF50),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Safe alerts: $_safeAlerts',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Statistics Panel
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Live Statistics',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildStatCard('Total Users', _totalUsers, Icons.people, const Color(0xFF4CAF50)),
                          const SizedBox(height: 12),
                          _buildStatCard('Police Stations', _totalStations, Icons.local_police, const Color(0xFF2196F3)),
                          const SizedBox(height: 12),
                          _buildStatCard('Total Hospitals', _totalHospitals, Icons.local_hospital_rounded, const Color(0xFF2196F3)),
                          const SizedBox(height: 12),
                          _buildStatCard('Total Alerts', _totalAlerts, Icons.warning, const Color(0xFFFF9800)),
                          const SizedBox(height: 12),
                          _buildStatCard('Active Alerts', _activeAlerts, Icons.notification_important, const Color(0xFFFF5722)),
                          const SizedBox(height: 12),
                          if (_currentView == 'alerts') ...[
                            const SizedBox(height: 12),
                            _buildStatCard('Safe Alerts', _safeAlerts, Icons.check_circle, const Color(0xFF4CAF50)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAnalyticsView() {
    return const Center(
      child: Text(
        'Analytics View - Coming Soon',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSettingsView() {
    return const Center(
      child: Text(
        'Settings View - Coming Soon',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String title, {String? badge}) {
    final isSelected = _selectedNavIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF4299E1) : const Color(0xFFA0AEC0),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFA0AEC0),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: badge != null
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF4299E1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        )
            : null,
        selected: isSelected,
        selectedTileColor: const Color(0xFF2D3748),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onTap: () {
          setState(() {
            _selectedNavIndex = index;
            _currentView = _getViewName(index);
          });

          // Handle navigation for map view
          if (index == 1) {
            _loadAllAlertMarkers();
          }
        },
      ),
    );
  }

  Widget _buildQuickStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF718096),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton(String label, IconData icon, Color color, bool isActive, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? color : Colors.grey[100],
        foregroundColor: isActive ? Colors.white : Colors.grey[700],
        elevation: isActive ? 2 : 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedNavIndex) {
      case 0:
        return 'Dashboard Overview';
      case 1:
        return 'Map View';
      case 2:
        return 'All Users';
      case 3:
        return 'All Alerts';
      case 4:
        return 'All Police Stations';
      case 5:
        return 'All Feedback';
      case 6:
        return 'Analytics';
      case 7:
        return 'Settings';
      case 8:
        return 'All Hospitals';
      default:
        return 'Admin Dashboard';
    }
  }

  String _getViewName(int index) {
    switch (index) {
      case 0:
        return 'dashboard';
      case 1:
        return 'map';
      case 2:
        return 'users';
      case 3:
        return 'alerts';
      case 4:
        return 'stations';
      case 5:
        return 'feedback';
      case 6:
        return 'analytics';
      case 7:
        return 'settings';
      case 8:
        return 'hospitals';
      default:
        return 'dashboard';
    }
  }

  Widget _buildMapContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading map data...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeMap,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            center: _currentPosition ?? const LatLng(23.769224, 90.425574),
            zoom: 12,
            onMapReady: () {
              _isMapReady = true;
              Future.delayed(const Duration(milliseconds: 100), () {
                _fitMarkersInView();
              });
            },
          ),
          children: [
            TileLayer(
              tileProvider: CancellableNetworkTileProvider(),
              urlTemplate: "https://cartodb-basemaps-a.global.ssl.fastly.net/{variant}/{z}/{x}/{y}.png",
              additionalOptions: {
                'variant': 'light_all', // or dark_all, voyager, voyager_nolabels
              },
              userAgentPackageName: 'com.example.resqmob',
            ),
            // Pulse circles for active alerts
            if (_activeAlertLocations.isNotEmpty)
              CircleLayer(
                circles: _generatePulseCircles(),
              ),
            MarkerLayer(
              markers: [
                if (_currentPosition != null)
                  Marker(
                    width: 40,
                    height: 40,
                    point: _currentPosition!,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ..._markers,
              ],
            ),
          ],
        );
      },
    );
  }

  // Controllers for the add hospital form
  final TextEditingController _hospitalNameController = TextEditingController();
  void _showAddHospitalModal(context) {
    _hospitalNameController.clear();
    _addressController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
    _phoneController.clear();

    showModalBottomSheet(

      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.65,
          width: MediaQuery.of(context).size.width * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.local_hospital_rounded, color: Color(0xFF3B82F6), size: 28),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Add New Hospital',
                        style: TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          controller: _hospitalNameController,
                          label: 'Hospital Name',
                          hint: 'Enter hospital name',
                          icon: Icons.local_hospital_rounded,
                          validator: (value) => value!.isEmpty ? 'Hospital name cannot be empty' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _addressController,
                          label: 'Address',
                          hint: 'Enter full address',
                          icon: Icons.location_on_outlined,
                          validator: (value) => value!.isEmpty ? 'Address cannot be empty' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _latitudeController,
                                label: 'Latitude',
                                hint: 'e.g., 23.769',
                                icon: Icons.map_outlined,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value!.isEmpty) return 'Latitude cannot be empty';
                                  if (double.tryParse(value) == null) return 'Invalid number';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _longitudeController,
                                label: 'Longitude',
                                hint: 'e.g., 90.425',
                                icon: Icons.map_outlined,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value!.isEmpty) return 'Longitude cannot be empty';
                                  if (double.tryParse(value) == null) return 'Invalid number';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Phone Number (Optional)',
                          hint: 'Enter phone number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: _isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Icon(Icons.save_outlined, size: 20),
                            label: Text(_isLoading ? 'Saving...' : 'Save Hospital'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _isLoading ? null : _addHospital,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addHospital() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final newHospitalRef = FirebaseFirestore.instance.collection('Resources/Hospitals/hospitals');
      final newHospitalData = {
        'hospitalId': _hospitalNameController.text.trim(),
        'hospitalName': _hospitalNameController.text.trim(),
        'address': _addressController.text.trim(),
        'location': {
          'latitude': double.parse(_latitudeController.text.trim()),
          'longitude': double.parse(_longitudeController.text.trim()),
        },
        'phone': _phoneController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      await newHospitalRef.doc(_hospitalNameController.text.trim()).set(newHospitalData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hospital added successfully!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.black,
          ),
        );
      }
      Navigator.pop(context);
      _loadHospitalsData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding hospital: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.black,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
