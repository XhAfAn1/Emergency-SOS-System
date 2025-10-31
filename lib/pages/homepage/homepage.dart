import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:hugeicons/hugeicons.dart';
import 'package:resqmob/backend/sms.dart';
import 'package:resqmob/Class%20Models/social%20model.dart';
import 'package:resqmob/backend/permission%20handler/location%20services.dart';
import 'package:resqmob/pages/alert%20listing/view%20active%20alerts.dart';
import 'package:resqmob/pages/safe%20map/safe%20road.dart';
import 'package:resqmob/pages/profile/profile.dart';
import '../../Class Models/alert.dart';
import '../../Class Models/pstation.dart';
import '../../Class Models/user.dart';
import 'package:resqmob/backend/api keys.dart';
import '../../backend/firebase config/firebase message.dart';
import '../../backend/widget_service.dart';
import '../../modules/coordinate to location.dart';
import '../../modules/distance.dart';
import 'drawer.dart';

class MyHomePage extends StatefulWidget {
  final navlat;
  final navlng;
  MyHomePage({super.key,this.navlat,this.navlng});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  // Initial camera position
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(23.8103, 90.4125), // Dhaka coordinates
    zoom: 12.0,
  );

  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = false;
  final Set<Marker> _markers = {};
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<RemoteMessage>? _notificationSub;
  StreamSubscription<DocumentSnapshot>? _alertListener;
  StreamSubscription<QuerySnapshot>? _alertMarkerListener;
  UserModel? currentUser;
  var imageLink;
  LatLng? _navigationDestination;
  bool isDanger = false;
  bool isBanned = false;
  final Set<Polyline> _polylines = {};

  // Add these flags to track map state more robustly
  bool _isMapReady = false;
  bool _isControllerDisposed = false;
  Timer? _cameraAnimationTimer;

  @override
  void initState() {
    super.initState();
    //home widget init
    WidgetService.initialize();
    WidgetService.onDataReceived = _handleWidgetData;
    _checkForWidgetData();


    _getCurrentLocation();
    LocationService().getInitialPosition(context);
    _checkInitialMessage();

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print("📥 App opened from background via notification");
      _handleMessage(message);
    });

    _notificationSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (!mounted) return;
          if (message.notification != null) {
            print(
                'message: ${message.notification!.body}, ${message.notification!
                    .title}, ${message.data}');
            final title = message.notification?.title ?? 'Notification';
            final body = message.notification?.body ?? '';
            final data = message.data;
            print(data.toString());
            _showNotificationDialog(title, body, data);
          }
        });

    if(widget.navlat!=null && widget.navlng!=null){
      getnavpoly();
         }


    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
      ),
    ).listen((Position pos) async {
      if (!mounted) return;

      _safeAnimateTo(pos);

      setState(() {
        _currentPosition = pos;
      });



      try {
        if (isDanger) {
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .update({
            "lat": pos.latitude,
            "lng": pos.longitude,
            "lastUpdated": FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        print("⚠️ Error updating location: $e");
      }


      print('1');
      print(_navigationDestination);

      // Live update polyline if navigation is active
      if (_navigationDestination != null) {
        print('2');
        await _getDirections(
          LatLng(pos.latitude, pos.longitude),
          _navigationDestination!,
        );
        _checkArrival(pos, _navigationDestination!);
        print('3');
      }
    }, onError: (error) {
      print('Position stream error: $error');
    });


    try {
      FirebaseFirestore.instance
          .collection('Users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get()
          .then((doc) {
        if (doc.exists && mounted) {
          setState(() {
            isDanger = doc.get('isInDanger');
            final ban= doc.get('token');
            if(ban=='normal') isBanned=false;
            else if(ban=='blocked')
              isBanned=true;
          });
          imageLink = doc.get("profileImageUrl");
          currentUser = UserModel.fromJson(doc.data() as Map<String, dynamic>);
        }
      }).catchError((e) => print('Error: $e'));

    } catch (e) {
      print(e);
    }


  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _notificationSub?.cancel();
    _alertListener?.cancel();
    _alertMarkerListener?.cancel();
    _cameraAnimationTimer?.cancel();

    // Mark controller as disposed before disposing
    _isControllerDisposed = true;
    _isMapReady = false;

    // Dispose map controller with a delay to ensure no pending operations
    if (_mapController != null) {
      Future.delayed(Duration(milliseconds: 100), () {
        try {
          _mapController?.dispose();
        } catch (e) {
          print('Error disposing map controller: $e');
        }
      });
    }

    super.dispose();
  }

getnavpoly()async{
    await _getCurrentLocation();
    if (_currentPosition != null) {

      _navigationDestination = LatLng(widget.navlat, widget.navlng);
      await _getDirections(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        _navigationDestination!,
      );
    }
    final marker = Marker(
      markerId: MarkerId(DateTime.now().toString()),
      position: LatLng(widget.navlat,  widget.navlng),
      icon:BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure),
      onTap: null,
    );
    _markers.add(marker);
    setState(() {

    });
}
  //home widget init
  void _handleWidgetData(String data) {
    if (mounted) {
      activeFromWidget(data);
    }
  }

  Future<void> _checkForWidgetData() async {
    final data = await WidgetService.getInitialData();
    if (data != null && mounted) {
      activeFromWidget(data);
    }
  }

  void activeFromWidget(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        content: Text('Activating Alert System...'),
        duration: const Duration(seconds: 2),
      ),
    );
    print(message);
    if(message=='ACTIVE'){
      try{
        if (!mounted) return;
        AlertSystem(context);
      }catch(e){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            content: Text(e.toString()),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }




// map position initialization
  void _reinitializeMapController() {
    if (!mounted) return;

    print('Attempting to reinitialize map controller...');
    _isMapReady = false;
    _isControllerDisposed = true;
    _mapController = null;

    // Force a rebuild of the widget to recreate the map
    setState(() {});
  }


  void _safeAnimateTo(Position position) {
    if (!mounted || _isControllerDisposed || !_isMapReady ||
        _mapController == null) return;

    // Cancel any pending camera animations
    _cameraAnimationTimer?.cancel();

    // Use a timer to debounce rapid camera updates
    _cameraAnimationTimer = Timer(Duration(milliseconds: 100), () {
      if (!mounted || _isControllerDisposed || !_isMapReady ||
          _mapController == null) return;

      try {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(position.latitude, position.longitude),
          ),
        ).catchError((error) {
          print('Camera animation error caught: $error');
          if (error is PlatformException && error.code == 'channel-error') {
            print('Channel error detected, reinitializing map controller');
            _reinitializeMapController();
            return;
          }
          // Try a fallback approach
          _fallbackCameraUpdate(LatLng(position.latitude, position.longitude));
        });
      } catch (e) {
        print('Exception during camera animation: $e');
        if (e is PlatformException && e.code == 'channel-error') {
          print(
              'Channel error detected in catch block, reinitializing map controller');
          _reinitializeMapController();
          return;
        }
        _fallbackCameraUpdate(LatLng(position.latitude, position.longitude));
      }
    });
  }


  void _fallbackCameraUpdate(LatLng target) {
    if (!mounted || _isControllerDisposed || !_isMapReady ||
        _mapController == null) return;

    try {
      // Try a simple camera move instead of animation
      _mapController!.moveCamera(CameraUpdate.newLatLng(target));
    } catch (e) {
      print('Fallback camera update also failed: $e');
      // At this point, we'll just log the error and continue
    }
  }


  Future<void> _safeAnimateCamera(CameraUpdate cameraUpdate,
      {int timeoutSeconds = 5}) async
  {
    if (!mounted || _isControllerDisposed || !_isMapReady ||
        _mapController == null) return;

    try {
      await _mapController!.animateCamera(cameraUpdate).timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          print('Camera animation timed out');
          throw TimeoutException(
              'Camera animation timeout', Duration(seconds: timeoutSeconds));
        },
      );
    } on TimeoutException {
      print('Camera animation timed out, trying fallback');
      try {
        await _mapController!.moveCamera(cameraUpdate);
      } catch (e) {
        print('Fallback camera move also failed: $e');
      }
    } on PlatformException catch (e) {
      print('Platform exception during camera animation: $e');
      if (e.code == 'channel-error') {
        print('Channel error detected, marking controller as disposed');
        _isControllerDisposed = true;
        _isMapReady = false;
      }
    } catch (e) {
      print('General error during camera animation: $e');
    }
  }


//load marker & navigating
  Future<void> _loadAllAlertMarkers() async {
    _alertMarkerListener?.cancel();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    _alertMarkerListener = FirebaseFirestore.instance
        .collection('Alerts')
        .snapshots()
        .listen((querySnapshot) {
      if (!mounted) return;

      setState(() {
        for (var change in querySnapshot.docChanges) {
          final doc = change.doc;
          final data = doc.data() as Map<String, dynamic>?;
          final docId = doc.id;

          if (data == null ||
              docId == currentUserId ||
              !data.containsKey('location') ||
              data['location'] == null ||
              data['admin'] == true ||
              data['status'] == 'safe' ||
              data['userId'] == currentUserId) {
            _markers.removeWhere((m) => m.markerId.value == docId);
            continue;
          }

          final location = data['location'];
          final latitude = location['latitude'];
          final longitude = location['longitude'];

          if (latitude != null && longitude != null) {
            final marker = Marker(
              markerId: MarkerId(docId),
              position: LatLng(latitude, longitude),
              icon: data['severity'] == 1
                  ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow)
                  : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
              onTap: () {
                _showNavigationBottomSheet(LatLng(latitude, longitude), data);
              },
            );

            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              // update or insert marker
              _markers.removeWhere((m) => m.markerId.value == docId);
              _markers.add(marker);
            } else if (change.type == DocumentChangeType.removed) {
              _markers.removeWhere((m) => m.markerId.value == docId);
            }
          }
        }
      });
    }, onError: (e) {
      debugPrint("Marker listener error: $e");
    });
  }


  //for view alert to homepage
  void handleNavigationRequest(double lat, double lng, String alertId) async {
    if (_currentPosition != null) {
      setState(() {
        _navigationDestination = LatLng(lat, lng);
      });
      await _getDirections(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        LatLng(lat, lng),
      );
      _checkDanger(alertId);
      _checkArrival(_currentPosition!, LatLng(lat, lng));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Current location not available')),
      );
    }
  }

  void _checkArrival(Position current, LatLng destination) async {
    final distance = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      destination.latitude,
      destination.longitude,
    );

    if (distance < 20) { // You can tune this threshold
      setState(() {
        _navigationDestination = null;
        _polylines.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('You have arrived at your destination!')),
        );
      }
    }
  }

  void _checkDanger(String alertId) {
    _alertListener?.cancel();
    _alertListener = FirebaseFirestore.instance
        .collection('Alerts')
        .doc(alertId)
        .snapshots()
        .listen(
          (doc) {
        if (!doc.exists || !mounted) return;

        try {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String?; // Explicit type

          if (status == 'safe') {
            _handleSafeAlert();
          }
        } catch (e) {
          debugPrint('Error processing alert update: $e');
        }
      },
      onError: (e) => debugPrint('Alert listener error: $e'),
    );
  }

  void _handleSafeAlert() {
    print('Alert marked as safe. Stopping navigation.');
    if (!mounted) return;

    setState(() {
      _navigationDestination = null;
      _polylines.clear();
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Alert is marked safe. Navigation stopped.')),
      );
    }
    _alertListener?.cancel();
  }

  // Get current location and add its marker
  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      // Safe camera animation
      await _safeAnimateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16.0,
          ),
        ),
      );

      FirebaseFirestore.instance
          .collection('Users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
        'location': {
          'latitude': _currentPosition?.latitude,
          'longitude': _currentPosition?.longitude,
          'timestamp': Timestamp.now(),
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      print('Error getting location: $e');
    }
  }

  Future<void> _getDirections(LatLng origin, LatLng destination) async {
    if (!mounted) return;

    final String _googleApiKey = apiKey.getKey();
    final String url = 'https://maps.googleapis.com/maps/api/directions/json?origin=${origin
        .latitude},${origin.longitude}&destination=${destination
        .latitude},${destination
        .longitude}&alternatives=true&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (!mounted) return;

      if (response.statusCode != 200) {
        debugPrint("❌ HTTP error: ${response.statusCode}");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Text('HTTP Error: ${response.statusCode}')),
          );
        }
        return;
      }

      final data = json.decode(response.body);
      if (data['status'] != 'OK') {
        debugPrint("❌ Directions API error: ${data['status']}");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Text('Directions API Error: ${data['status']}')),
          );
        }
        return;
      }

      final List<Polyline> updatedPolylines = [];
      final List<Color> routeColors = [
        Colors.blue,
        Colors.green,
        Colors.purple,
        Colors.orange,
        Colors.red,
      ];

      LatLngBounds? bounds;
      int colorIndex = 0;

      for (var route in data['routes']) {
        final polylineStr = route['overview_polyline']?['points'];
        if (polylineStr == null) continue;

        final points = PolylinePoints().decodePolyline(polylineStr);
        if (points.isEmpty) continue;

        final polyline = Polyline(
          polylineId: PolylineId('route_$colorIndex'),
          color: routeColors[colorIndex % routeColors.length],
          width: 6,
          points: points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        );

        updatedPolylines.add(polyline);

        final lats = polyline.points.map((p) => p.latitude);
        final lngs = polyline.points.map((p) => p.longitude);

        bounds ??= LatLngBounds(
          southwest: LatLng(
              lats.reduce((a, b) => a < b ? a : b),
              lngs.reduce((a, b) => a < b ? a : b)),
          northeast: LatLng(
              lats.reduce((a, b) => a > b ? a : b),
              lngs.reduce((a, b) => a > b ? a : b)),
        );

        colorIndex++;
      }

      if (context.mounted) {
        setState(() {
          _polylines.clear();
          _polylines.addAll(updatedPolylines);
        });
      }
    } catch (e, stacktrace) {
      debugPrint("❌ Exception during getDirections: $e");
      debugPrint("Stacktrace: $stacktrace");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Something went wrong while fetching directions.')),
        );
      }
    }
  }

  String calculateDistancewithalert(AlertModel alert) {
    if (_currentPosition == null || alert.location == null) return 'Distance unknown';
    try {
      final alertLat = alert.location!['latitude'];
      final alertLng = alert.location!['longitude'];
      if (alertLat == null || alertLng == null) return 'Distance unknown';

      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        alertLat is double ? alertLat : double.parse(alertLat.toString()),
        alertLng is double ? alertLng : double.parse(alertLng.toString()),
      );

      return distance >= 1000
          ? '${(distance / 1000).toStringAsFixed(1)} km away'
          : '${distance.toInt()} m away';
    } catch (e) {
      return 'Distance unknown';
    }
  }

//need upgrade

  void _showNavigationBottomSheet(LatLng destination, Map<String, dynamic> data) async {
    final userId = data['userId'];
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('User ID is missing'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection("Users").doc(userId).get();
      if (!userDoc.exists || userDoc.data() == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('User not found'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        return;
      }

      final user = UserModel.fromJson(userDoc.data()!);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) => _buildNavigationModal(user, destination, data),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load user info: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Widget _buildNavigationModal(UserModel user, LatLng destination, Map<String, dynamic> data) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: Color(0xFFEF4444),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Navigate to ${user.name}',
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Emergency assistance needed',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  if (data['alertId'] != null) ...[
                    _buildInfoCard('Distance', calculateDistancewithalert(AlertModel.fromJson(data, data['alertId'])), Icons.location_on_outlined),
                    const SizedBox(height: 16),
                  ],
                  if (user.email != null) ...[
                    _buildInfoCard('Email', user.email!, Icons.email_outlined),
                    const SizedBox(height: 16),
                  ],
                  _buildInfoCard(
                    'Status',
                    user.isInDanger == true ? 'In Danger' : 'Safe',
                    user.isInDanger == true ? Icons.warning_outlined : Icons.check_circle_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    'Severity',
                    data['severity'] == 1 ? 'Low' : data['severity'] == 2 ? 'Medium' : 'High',
                    Icons.warning_amber_rounded,
                  ),
                  const SizedBox(height: 32),
                  // Navigation Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.navigation, size: 20),
                      label: const Text('Start Navigation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xff25282b),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        if (_currentPosition != null) {
                          final alertRef = FirebaseFirestore.instance.collection('Alerts').doc(data['alertId']);
                          await alertRef.set({
                            'responders': [],
                          }, SetOptions(merge: true));
                          await alertRef.update({
                            'responders': FieldValue.arrayUnion([currentUser!.id]),
                          });

                          _navigationDestination = destination;
                          await _getDirections(
                            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                            _navigationDestination!,
                          );
                          _checkDanger(data['alertId']);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Current location not available'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xff25282b).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Color(0xff25282b), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // Main alert function
  void AlertSystem(BuildContext context) async {
    if (_currentPosition == null) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //behavior: SnackBarBehavior.floating,
      //   SnackBar(content: Text("Waiting for location...")),
      // );
      await _getCurrentLocation(); // Refresh location
      if (_currentPosition == null) return;
    }
    final data = await FirebaseFirestore.instance.collection('Users').doc(FirebaseAuth.instance.currentUser?.uid).get();
    UserModel user = UserModel.fromJson(data.data()!);

    final snapshotcount = await FirebaseFirestore.instance
        .collection('Alerts')
        .count()
        .get();
    int length = snapshotcount.count!;
    print(length);
    length= length+15;
    print(length);

    String address = await getAddressFromLatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    final alert = AlertModel(
        alertId: length.toString(),
        userId: user.id,
        userName: user.name,
        userPhone: user.phoneNumber,
        severity: 1,
        etype: "Unknown",
        status: 'danger',
        timestamp: Timestamp.now(),
        address: address,
        message: user.msg != "" ? user.msg : "initial help message",
        location: {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
        });

    if (user.isInDanger == false) {
      await FirebaseFirestore.instance.collection('Users').doc(FirebaseAuth.instance.currentUser?.uid).update({
        'isInDanger': true,
      });
      await FirebaseFirestore.instance.collection('Alerts').doc(alert.alertId).set(alert.toJson());

      // Alert distribution for sev 1
      int notified = 0;
      final querySnapshot = await FirebaseFirestore.instance.collection('Users').get();
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final fcm = data['fcmToken'];
        UserModel ouser = UserModel.fromJson(data);
        final cloc = user.location;
        final uloc = ouser.location;
        final distance = calculateDistance(
          LatLng(
            cloc?['latitude'],
            cloc?['longitude'],
          ),
          LatLng(
            uloc?['latitude'],
            uloc?['longitude'],
          ),
        );
        print('user: ${ouser.name}, distance: $distance');
        if (ouser.id != FirebaseAuth.instance.currentUser?.uid &&
            ouser.admin == false &&
            ouser.isInDanger == false) {
          if (0 < distance && distance < 1001) {
            FirebaseApi().sendNotification(
                token: fcm,
                title: 'Alert',
                body: 'Need help!!!',
                userId: ouser.id,
                latitude: _currentPosition?.latitude,
                longitude: _currentPosition?.longitude,
                distance: distance.toStringAsFixed(2),
                alertId: alert.alertId);
            print('alert sent to ${ouser.name}, distance: $distance');
            notified = notified + 1;
          }
        }
      }

      // SOS to emergency contacts
      final econtacts = user.emergencyContacts;
      List<String> phoneNumbers = [];
      for (var contact in econtacts) {
        phoneNumbers.add(contact.phoneNumber);
      }
      // sendSos(phoneNumbers, '${user.name}', _currentPosition!.latitude, _currentPosition!.longitude);

      print('sos sent to emergency contacts');

      // Police station
      final police = await FirebaseFirestore.instance.collection('Resources/PoliceStations/Stations').get();
      var min = 10000000000.0;
      PStationModel? nearStation;
      for (var doc in police.docs) {
        final stationdata = doc.data();
        PStationModel station = PStationModel.fromJson(stationdata);
        final stationloc = station.location;
        final userloc = {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude
        };
        var shortdis = calculateDistancewithmap(stationloc, userloc);
        if (shortdis < min) {
          min = shortdis;
          nearStation = station;
        }
      }

      // Sending sms to police station
      final userloc = {
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude
      };
    //   sendSos(['${nearStation!.phone}'], '${user.name}', userloc['latitude']!, userloc['longitude']!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
                "Informed to Police station: ${nearStation!.stationName}, ${min.toStringAsFixed(2)} meter away")));
      }

      print('notified: $notified');
      await FirebaseFirestore.instance.collection('Alerts').doc(alert.alertId).update({
        "pstation": "${nearStation!.stationName}",
        "notified": notified
      });

      setState(() {
        isDanger = true;
      });

      // Community post
      final post = PostModel(
          id: alert.alertId,
          userId: alert.userId,
          userName: alert.userName,
          userProfileImage: '',
          content:
          'Emergency Alert for ${alert.userName} at ${alert.address} with severity ${alert.severity} and type ${alert.etype}',
          temp: true,
          createdAt: alert.timestamp.toDate(),
          upvotes: [],
          downvotes: [],
          commentCount: 0);
      await FirebaseFirestore.instance.collection('social').doc(alert.alertId).set(post.toJson());
      print('community post created');

      // Additional danger info
      var dtype = '';
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Select Type of Emergency"),
            content: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      dtype = 'Accident';
                      await FirebaseFirestore.instance.collection('Alerts').doc(alert.alertId).update({
                        "etype": "${dtype}"
                      });
                      await FirebaseFirestore.instance.collection('social').doc(alert.alertId).update({
                        'content':
                        'Emergency Alert for ${alert.userName} at ${alert.address} with severity ${alert.severity} and type ${dtype}',
                      });
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Accident"),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      dtype = 'Threat';
                      await FirebaseFirestore.instance.collection('Alerts').doc(alert.alertId).update({
                        "etype": "${dtype}"
                      });
                      await FirebaseFirestore.instance.collection('social').doc(alert.alertId).update({
                        'content':
                        'Emergency Alert for ${alert.userName} at ${alert.address} with severity ${alert.severity} and type ${dtype}',
                      });
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Threat"),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      dtype = 'Medical';
                      await FirebaseFirestore.instance.collection('Alerts').doc(alert.alertId).update({
                        "etype": "${dtype}"
                      });
                      await FirebaseFirestore.instance.collection('social').doc(alert.alertId).update({
                        'content':
                        'Emergency Alert for ${alert.userName} at ${alert.address} with severity ${alert.severity} and type ${dtype}',
                      });
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Medical"),
                  ),
                ],
              ),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          );
        },
      );
    } else if (user.isInDanger == true) {
      final alert_data = await FirebaseFirestore.instance
          .collection('Alerts')
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .where('status', isEqualTo: 'danger')
          .get();
      AlertModel alert2 = AlertModel.fromJson(alert_data.docs.first.data() as Map<String, dynamic>, alert_data.docs.first.id);
      if (alert2.severity < 3) {
        await FirebaseFirestore.instance.collection('Alerts').doc(alert2.alertId).update({
          'severity': FieldValue.increment(1),
        });

        // Alert distribution for sev ++
        int notified = alert2.notified;
        final querySnapshot = await FirebaseFirestore.instance.collection('Users').get();
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final fcm = data['fcmToken'];
          UserModel ouser = UserModel.fromJson(data);
          final cloc = user.location;
          final uloc = ouser.location;
          final distance = calculateDistance(
            LatLng(
              cloc?['latitude'],
              cloc?['longitude'],
            ),
            LatLng(
              uloc?['latitude'],
              uloc?['longitude'],
            ),
          );
          print('severity: ${alert2.severity}, user: ${ouser.name}, distance: $distance');
          if (ouser.id != FirebaseAuth.instance.currentUser?.uid &&
              ouser.admin == false &&
              ouser.isInDanger == false) {
            if (1000 < distance && distance < 10001 && alert2.severity == 1) {
              FirebaseApi().sendNotification(
                  token: fcm,
                  title: 'Alert',
                  body: 'help!!!',
                  userId: ouser.id,
                  latitude: _currentPosition?.latitude,
                  longitude: _currentPosition?.longitude,
                  distance: distance.toStringAsFixed(2),
                  alertId: alert2.alertId);
              print('alert sent to ${ouser.name}, distance: $distance');
              notified = notified + 1;
            }
            if (10000 < distance && distance < 15000 && alert2.severity == 2) {
              FirebaseApi().sendNotification(
                  token: fcm,
                  title: 'Alert',
                  body: 'help meeeeeeeeeeeeee',
                  userId: ouser.id,
                  latitude: _currentPosition?.latitude,
                  longitude: _currentPosition?.longitude,
                  distance: distance.toStringAsFixed(2),
                  alertId: alert2.alertId
              );
              print('alert sent to ${ouser.name}, distance: $distance');
              notified = notified + 1;
            }
          }
        }
        print('notified: $notified');
        await FirebaseFirestore.instance.collection('Alerts').doc(alert2.alertId).update({
          "notified": notified
        });

        // Community post update
        final post = PostModel(
            id: alert2.alertId,
            userId: alert2.userId,
            userName: alert2.userName,
            userProfileImage: '',
            content:
            'Emergency Alert for ${alert.userName} at ${alert2.address} with severity ${alert2.severity + 1} and type ${alert2.etype}',
            temp: true,
            createdAt: alert2.timestamp.toDate(),
            upvotes: [],
            downvotes: [],
            commentCount: 0);
        await FirebaseFirestore.instance.collection('social').doc(alert2.alertId).set(post.toJson());
        print('community post updated');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar( behavior: SnackBarBehavior.floating,content: Text("Severity increased to ${alert2.severity + 1}")));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating,content: Text("Severity already at maximum")));
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating,content: Text("Something went wrong")));
      }
    }
  }

  // UI test
  Widget _buildCustomAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          right: 20,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.white.withOpacity(0.9),
              Colors.white.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            Builder(
              builder: (context) {
                return GestureDetector(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.menu_rounded,
                      color: Color(0xFF1F2937),
                      size: 24,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ResQmob',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Emergency Response System',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => profile(
                        uid: FirebaseAuth.instance.currentUser?.uid,
                      )),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 16,
                        backgroundImage: (imageLink != null && imageLink.isNotEmpty) ? NetworkImage(imageLink) : null,
                        backgroundColor: const Color(0xFFF3F4F6),
                        child: (imageLink == null || imageLink.isEmpty)
                            ? const HugeIcon(icon: HugeIcons.strokeRoundedUser03, color: Colors.grey,size: 16,)
                            : null,
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
  }

  Widget _buildAlertOverlay() {
    return Positioned(
      top: 130,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFEF4444).withOpacity(0.95),
              const Color(0xFFDC2626).withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withOpacity(0.3 + 0.2 * 1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: StreamBuilder(
          stream: FirebaseFirestore.instance
              .collection('Alerts')
              .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
              .where('status', isEqualTo: 'danger')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                  child: Text("No active alerts", style: TextStyle(color: Colors.white)));
            }

            final doc = snapshot.data!.docs.first;
            final alert = AlertModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
            final responderCount = alert.responders?.length ?? 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "EMERGENCY ALERT ACTIVE",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Level ${alert.severity}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildAlertStat("Type", alert.etype ?? "Unspecified"),
                    _buildAlertStat("Notified", "${alert.notified}"),
                    _buildAlertStat("Responding", "$responderCount"),
                  ],
                ),
                if (alert.pstation != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    "Informed Police Station: ${alert.pstation}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAlertStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }


  int _currentIndex = 3;

  @override
  Widget build(BuildContext context) {

    final List<Widget>  _pages = [
      ViewActiveAlertsScreen(
        currentUser: currentUser,
        currentPosition: _currentPosition,
        onNavigate: (lat, lng, alertId) {
          handleNavigationRequest(lat, lng, alertId);
          setState(() => _currentIndex = 3);
        },
      ),
      SafetyMap(currentUser: currentUser,),

    ];
    return Scaffold(
      backgroundColor: isDanger? (_currentIndex!=3?(_currentIndex==1?Color(0xFFEBE3CD):Color(
          0xFFFFFFFF)):Color(0xFFFFC5C5)): (_currentIndex==1?Color(0xFFEBE3CD):Color(
          0xFFFFFFFF)),
      drawer: AppDrawer(
        activePage: 1,
        currentUser: currentUser,
      ),
      body: (_currentIndex == 3)
          ? Stack(
        children: [
          GoogleMap(
            style: '''
                  [
                    {
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#f5f5f5"
                        }
                      ]
                    },
                    {
                      "elementType": "labels.icon",
                      "stylers": [
                        {
                          "visibility": "off"
                        }
                      ]
                    },
                    {
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#616161"
                        }
                      ]
                    },
                    {
                      "elementType": "labels.text.stroke",
                      "stylers": [
                        {
                          "color": "#f5f5f5"
                        }
                      ]
                    },
                    {
                      "featureType": "administrative",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "visibility": "off"
                        }
                      ]
                    },
                    {
                      "featureType": "administrative.land_parcel",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#bdbdbd"
                        }
                      ]
                    },
                    {
                      "featureType": "poi",
                      "stylers": [
                        {
                          "visibility": "off"
                        }
                      ]
                    },
                    {
                      "featureType": "poi",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#eeeeee"
                        }
                      ]
                    },
                    {
                      "featureType": "poi",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#757575"
                        }
                      ]
                    },
                    {
                      "featureType": "poi.park",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#e5e5e5"
                        }
                      ]
                    },
                    {
                      "featureType": "poi.park",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#9e9e9e"
                        }
                      ]
                    },
                    {
                      "featureType": "road",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#ffffff"
                        }
                      ]
                    },
                    {
                      "featureType": "road",
                      "elementType": "labels.icon",
                      "stylers": [
                        {
                          "visibility": "off"
                        }
                      ]
                    },
                    {
                      "featureType": "road.arterial",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#757575"
                        }
                      ]
                    },
                    {
                      "featureType": "road.highway",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#dadada"
                        }
                      ]
                    },
                    {
                      "featureType": "road.highway",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#616161"
                        }
                      ]
                    },
                    {
                      "featureType": "road.local",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#9e9e9e"
                        }
                      ]
                    },
                    {
                      "featureType": "transit",
                      "stylers": [
                        {
                          "visibility": "off"
                        }
                      ]
                    },
                    {
                      "featureType": "transit.line",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#e5e5e5"
                        }
                      ]
                    },
                    {
                      "featureType": "transit.station",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#eeeeee"
                        }
                      ]
                    },
                    {
                      "featureType": "water",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#c9c9c9"
                        }
                      ]
                    },
                    {
                      "featureType": "water",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#9e9e9e"
                        }
                      ]
                    }
                  ]
                  ''',
            polylines: _polylines,
            initialCameraPosition: _initialPosition,
            mapType: MapType.normal,
            onMapCreated: (GoogleMapController controller) async {
              try {
                _mapController = controller;

                // Add a small delay to ensure the controller is fully initialized
                await Future.delayed(Duration(milliseconds: 300));

                if (mounted && !_isControllerDisposed) {
                  _isMapReady = true;
                  _loadAllAlertMarkers();

                  // Initial camera positioning if we have current location
                  if (_currentPosition != null) {
                    await _safeAnimateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                          zoom: 16.0,
                        ),
                      ),
                    );
                  }
                }
              } catch (e) {
                print('Error in onMapCreated: $e');
                _isMapReady = false;
              }
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: true,
            zoomControlsEnabled: false,
            markers: _markers,
          ),
          _buildCustomAppBar(),
          // Red layer when alert is on with alert stat
          if (isDanger)
            IgnorePointer(
              child: Container(
                color: Colors.red.withOpacity(0.2),
                height: double.infinity,
                width: double.infinity,

              ),
            ),
          if (isDanger) _buildAlertOverlay(),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.black,
                strokeWidth: 3,
              ),
            ),

          // Control Buttons
          Positioned(
            bottom: 40,
            left: 16,
            child: Column(
              children: [
                // FloatingActionButton(
                //   backgroundColor: Colors.white,
                //   onPressed: (){
                //    sendSos(['01839228924'] , 'saif', 0, 0);
                //
                //   },
                //   heroTag: "location_3",
                //   child: Text('Test'),
                // ),
                // const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _getCurrentLocation,
                  heroTag: "location_1",
                  child: HugeIcon(icon:HugeIcons.strokeRoundedGps01 , color: Colors.black),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () async {
                    _mapController?.animateCamera(
                      CameraUpdate.newCameraPosition(_initialPosition),
                    );},
                  heroTag: "location_2",
                  child:HugeIcon(icon:HugeIcons.strokeRoundedMapsLocation02 , color: Colors.black),
                ),
              ],
            ),
          ),
          if (isDanger)
          Positioned(
            bottom: 35,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Color(0xFF1F2937),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Mark as Safe',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ],
                    ),
                    content: const Text(
                      'Are you sure you want to mark yourself as safe? This will notify your emergency contacts.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ElevatedButton(

                        child: const Text('Yes, I\'m Safe'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1F2937),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                );

                if (confirm != true) return; // user cancelled

                try {
                  final uid = FirebaseAuth.instance.currentUser?.uid;

                  // Update user's isInDanger flag
                  await FirebaseFirestore.instance
                      .collection('Users')
                      .doc(uid)
                      .update({
                    "isInDanger": false,
                  });
                  setState(() {
                    isDanger = false;
                  });

                  final alertSnapshot = await FirebaseFirestore.instance
                      .collection('Alerts')
                      .where('userId', isEqualTo: uid)
                      .where('status', isEqualTo: 'danger')
                      .get();

                  if (alertSnapshot.docs.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text("No Alert found from you."),
                        ),
                      );
                    }
                    return;
                  }

                  // Update each alert's status to 'safe'
                  for (var doc in alertSnapshot.docs) {
                    await doc.reference.update({
                      'status': 'safe',
                      'safeTime': Timestamp.now(),
                    });
                  }



                  // Temp community post delete
                  String postId = alertSnapshot.docs.first.id;
                  try {
                    final postRef =
                    FirebaseFirestore.instance.collection('social').doc(postId);
                    final commentsRef = postRef.collection('comments');

                    final commentsSnapshot = await commentsRef.get();

                    final batch = FirebaseFirestore.instance.batch();

                    for (final doc in commentsSnapshot.docs) {
                      batch.delete(doc.reference);
                    }
                    batch.delete(postRef);

                    await batch.commit();

                    print('Successfully deleted post $postId and all its comments');
                  } catch (e) {
                    print('Error deleting post and comments: $e');
                    rethrow;
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text("Status updated to safe."),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint("Error updating status: $e");
                }
              },
              heroTag: "location",
              child: Text(
                "Safe",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          ),

        ],
      )
          : IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButton: _currentIndex == 3
          ?( !isBanned? FloatingActionButton.large(
        backgroundColor: Color(0xffe04c6c),
        elevation: 0,
        onPressed: () {
          AlertSystem(context);
        },
        child: Icon(
          Icons.notifications_active_sharp,
          size: 50,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ):FloatingActionButton.large(
        backgroundColor: Colors.black87.withOpacity(0.2),
        elevation: 0,
        onPressed: (){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  Icon(
                    Icons.warning_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('You are blocked from using this app')),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        },
        child: Icon(
          Icons.notifications_off,
          size: 50,
          color: Colors.black87,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ) )
          : FloatingActionButton(
        backgroundColor: Color(0xffe04c6c),
        elevation: 0,
        onPressed: () {
          setState(() {
            _currentIndex = 3;
          });
        },
        child: FaIcon(
          FontAwesomeIcons.home,
          size: 26,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 89,
        color: Color(0xff25282b),
        notchMargin: 8,
        shape: CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentIndex = 0;
                  });
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _currentIndex = 0;
                        });
                      },
                      icon: HugeIcon(icon: HugeIcons.strokeRoundedAlert01, color:_currentIndex==0? Colors.white:Colors.white.withOpacity(0.6),size: 30,),
                    ),
                    Text('Active Alerts', style: TextStyle(color:_currentIndex==0? Colors.white:Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w500))
                  ],
                ),
              ),
            ),

            Expanded(
              child: InkWell(
                onTap: null,
                child: TextButton(
                  onPressed: null,
                  child: Text(''),
                ),
              ),
            ),

            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentIndex = 1;
                  });
                },
                child: Column(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _currentIndex = 1;
                          });
                        },
                        icon: HugeIcon(icon: HugeIcons.strokeRoundedNavigator01, color:_currentIndex==1? Colors.white:Colors.white.withOpacity(0.6),size: 30,),
                      ),
                      Text('Safe Map', style: TextStyle(color:_currentIndex==1? Colors.white:Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w500))
                    ]
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //Push notification handler

  void _checkInitialMessage() async {
    RemoteMessage? initialMessage =
    await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      print(" App opened from terminated state via notification");
      _handleMessage(initialMessage);
    }
  }

  void _handleMessage(RemoteMessage message) {
    final data = message.data;

    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? '';

    if (context.mounted) {
      _showNotificationDialog(title, body, data);
    }
  }


  void _showNotificationDialog(String title, String body, Map<String, dynamic> data) async {

    print(data.toString());
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(
        color: Colors.black,
        strokeWidth: 3,
      )),
    );
    print(data.toString());
    try {
      final alertSnapshot = await FirebaseFirestore.instance
          .collection('Alerts')
          .doc(data['alertId'])
          .get();

      if (!alertSnapshot.exists || alertSnapshot.data() == null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(behavior: SnackBarBehavior.floating,content: Text('Alert not found')),
        );
        return;
      }

      final alert = AlertModel.fromJson(
        alertSnapshot.data() as Map<String, dynamic>,
        alertSnapshot.id,
      );

      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    body,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF374151)),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Text("Distance: ", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                    Expanded(child: Text(data['distance'] ?? 'N/A', style: const TextStyle(color: Color(0xFF374151)))),
                  ]),
                  Row(children: [
                    const Text("Location: ", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                    Expanded(child: Text(alert.address ?? 'N/A', style: const TextStyle(color: Color(0xFF374151)))),
                  ]),
                  Row(children: [
                    const Text("User: ", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                    Expanded(child: Text(alert.userName ?? 'N/A', style: const TextStyle(color: Color(0xFF374151)))),
                  ]),

                  Row(children: [
                    const Text("Message: ", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                    Expanded(child: Text(alert.message ?? 'N/A', style: const TextStyle(color: Color(0xFF374151)))),
                  ]),

                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();

                  final userId = FirebaseAuth.instance.currentUser?.uid;
                  final double? lat = double.tryParse(
                    data['latitude']?.toString() ?? alert.location?['latitude']?.toString() ?? '',
                  );
                  final double? lng = double.tryParse(
                    data['longitude']?.toString() ?? alert.location?['longitude']?.toString() ?? '',
                  );
                  final String? alertId = data['alertId'] ?? alert.alertId;

                  if (userId != null && alertId != null) {
                    try {
                      final alertRef = FirebaseFirestore.instance.collection('Alerts').doc(alertId);
                      await alertRef.set({'responders': []}, SetOptions(merge: true));
                      await alertRef.update({
                        'responders': FieldValue.arrayUnion([userId]),
                      });
                    } catch (e) {
                      print("Failed to add responder: $e");
                    }
                  }

                  if (lat != null && lng != null && _currentPosition != null) {
                    _navigationDestination = LatLng(lat, lng);
                    await _getDirections(
                      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      LatLng(lat, lng),
                    );
                    _checkDanger(alertId!);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Help'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      Navigator.of(context).pop(); // remove loader
      print("Error fetching alert: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating,content: Text('Failed to load alert')),
      );
    }
  }
}
