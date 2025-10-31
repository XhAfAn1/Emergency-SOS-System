import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:hugeicons/hugeicons.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:resqmob/backend/api%20keys.dart';
import 'package:resqmob/pages/safe%20map/safety%20module.dart';
import '../../Class Models/Danger zone.dart';
import '../../Class Models/user.dart';
import '../homepage/drawer.dart';

class SafetyMap extends StatefulWidget {
  final UserModel? currentUser;
  const SafetyMap({Key? key, required this.currentUser}) : super(key: key);

  @override
  _SafetyMapState createState() => _SafetyMapState();
}

class _SafetyMapState extends State<SafetyMap> with TickerProviderStateMixin {
  // Controllers and Completers
  final Completer<GoogleMapController> _controller = Completer();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final DraggableScrollableController _draggableController =
  DraggableScrollableController();

  // Animation Controllers (Only keep necessary ones)
  late AnimationController _routeLoadingController;
  late Animation<double> _routeLoadingAnimation;

  int selectedRouteIndex = 0;
  Timer? _debounceTimer;
  bool _isSearchExpanded = true; // NEW: Search box toggle state

  // Google API Key
  String googleApiKey = apiKey.getKey();

  // Map and Location Variables
  GoogleMapController? mapController;
  Position? currentPosition;
  LatLng? destinationLocation;
  List<DangerZone> dangerZones = [];
  Set<Circle> circles = {};
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  List<PlaceSuggestion> suggestions = [];
  bool showSuggestions = false;
  bool showcircle = true;

  // *** NEW STATE FOR NAVIGATION ***
  bool _isNavigating = false;
  bool isLoading = false;
  List<RouteInfo> availableRoutes = [];

  // Professional color scheme
  static const Color primaryColor = Color(0xff25282b);
  static const Color secondaryColor = Color(0xFF059669);
  static const Color surfaceColor = Color(0xFFD5C4A1);
  static const Color errorColor = Color(0xFFDC2626);
  static const Color warningColor = Color(0xFFF59E0B);

  // Initial camera position - Dhaka, Bangladesh
  static const CameraPosition _kDhakaPosition = CameraPosition(
    target: LatLng(23.8103, 90.4125),
    zoom: 12.0,
  );

  @override
  void initState() {
    super.initState();
    _initializeAnimations(); // Only initialize necessary animations
    _getCurrentLocation();
    _initializeDataFromFirebase();
    _searchFocusNode.addListener(() {
      setState(() {
        showSuggestions =
            _searchFocusNode.hasFocus && suggestions.isNotEmpty;
      });
    });
  }

  void _initializeAnimations() {
    _routeLoadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _routeLoadingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _routeLoadingController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _routeLoadingController.dispose();
    super.dispose();
  }

  // NEW: Toggle search box visibility
  void _toggleSearchBox() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (!_isSearchExpanded) {
        // Collapse search
        showSuggestions = false;
        _searchFocusNode.unfocus();
      }
    });
  }

  // Get current location (keeping your existing implementation)
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Location services are disabled', warningColor);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permission denied', errorColor);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permission permanently denied', errorColor);
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      setState(() {
        currentPosition = position;
      });
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15.0,
          ),
        ),
      );
    } catch (e) {
      print('Error getting location: $e');
      _showSnackBar('Could not get location', errorColor);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(
              color == errorColor
                  ? Icons.error_outline
                  : color == warningColor
                  ? Icons.warning_outlined
                  : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Search places (keeping your existing implementation but with improved loading)
  void _searchPlaces(String query) {
    if (query.isEmpty) {
      setState(() {
        suggestions.clear();
        showSuggestions = false;
      });
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchPlaceSuggestions(query);
    });
  }

  Future<void> _fetchPlaceSuggestions(String query) async {
    setState(() {
      isLoading = true;
    });
    try {
      String baseUrl =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json';
      String request =
          '$baseUrl?input=${Uri.encodeQueryComponent(query)}'
          '&key=$googleApiKey'
          '&components=country:bd'
          '&types=establishment|geocode'
          '&fields=place_id,description,structured_formatting'
          '&language=en';
      if (currentPosition != null) {
        request +=
        '&location=${currentPosition!.latitude},${currentPosition!.longitude}'
            '&radius=50000';
      }
      final response = await http.get(
        Uri.parse(request),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          List<PlaceSuggestion> newSuggestions = [];
          for (var prediction in data['predictions']) {
            newSuggestions.add(
              PlaceSuggestion(
                placeId: prediction['place_id'],
                description: prediction['description'],
                mainText: prediction['structured_formatting']['main_text'],
                secondaryText:
                prediction['structured_formatting']['secondary_text'] ??
                    '',
                types: List<String>.from(prediction['types'] ?? []),
              ),
            );
          }
          setState(() {
            suggestions = newSuggestions;
            showSuggestions =
                suggestions.isNotEmpty && _searchFocusNode.hasFocus;
            isLoading = false;
          });
        } else {
          String errorMessage = 'Search failed: ${data['status']}';
          if (data['error_message'] != null) {
            errorMessage += ' - ${data['error_message']}';
          }
          _showSnackBar(errorMessage, errorColor);
          setState(() {
            isLoading = false;
            suggestions.clear();
            showSuggestions = false;
          });
        }
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      _showSnackBar('Network error: ${e.toString()}', errorColor);
      setState(() {
        isLoading = false;
        suggestions.clear();
        showSuggestions = false;
      });
    }
  }

  Future<void> _initializeDataFromFirebase() async {
    print(dangerZones.toString());
    print(circles.toString());
    try {
      // 1. Get reference to the Firestore collection
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Resources/DangerPoints/dangerpoints')
          .get();
      if (snapshot.docs.isEmpty) {
        print("No data found in Firestore.");
        setState(() => isLoading = false);
        return;
      }
      // 2. Create temporary lists to hold the fetched data
      final List<DangerZone> fetchedZones = [];
      final Set<Circle> fetchedCircles = {};

      // 3. Loop through documents and populate the lists
      for (var i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        final data = doc.data() as Map<String, dynamic>;
        // Create a DangerZone object
        final zone = DangerZone.fromJson(data);
        fetchedZones.add(zone);
        // Create a corresponding Circle object
        fetchedCircles.add(
          Circle(
            circleId: CircleId('dz_$i'), // Unique ID for each circle
            center: LatLng(zone.lat, zone.lon),
            radius: zone.radius,
            fillColor: Colors.yellow.withOpacity(0.2),
            strokeColor: Colors.red.withOpacity(0.2),
            strokeWidth: 20,
          ),
        );
      }
      // 4. Update the state to reflect the fetched data
      setState(() {
        dangerZones = fetchedZones;
        circles = fetchedCircles;
        isLoading = false;
      });
    } catch (e) {
      print("Error initializing data: $e");
      setState(() => isLoading = false);
      // Optionally, show an error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load map data.')),
      );
    }
  }

  // Keep your existing _selectPlace, _initializeDataFromFirebase, and _getDirections methods
  // (I'm keeping them the same but with improved UI feedback)
  Future<void> _getDirections() async {
    _getCurrentLocation();
    if (currentPosition == null || destinationLocation == null) return;
    try {
      setState(() {
        polylines.clear();
        availableRoutes.clear();
        _isNavigating = false; // Reset navigation state
      });
      _showSnackBar('Finding routes...', Colors.black);
      // Strategy 1: Make 2-3 concurrent requests with different parameters
      List<Future<List<RouteInfo>>> routeRequests = [
        // Primary request - fastest/default
        _getSingleRouteSet({
          'avoid': '',
          'description': 'Fastest routes',
          'priority': 1
        }),
        // Secondary request - avoid tolls (most common alternative)
        _getSingleRouteSet({
          'avoid': 'tolls',
          'description': 'Toll-free routes',
          'priority': 2
        }),
      ];
      // Add third request only for longer distances
      double distanceKm = _getDistanceKm();
      if (distanceKm > 5) {
        routeRequests.add(_getSingleRouteSet({
          'avoid': 'highways',
          'description': 'Local roads',
          'priority': 3
        }));
      }
      // Execute all requests concurrently with timeout
      List<List<RouteInfo>> allRouteLists = await Future.wait(
        routeRequests,
        eagerError: false, // Continue even if some requests fail
      ).timeout(
        Duration(seconds: 10), // Overall timeout
        onTimeout: () => routeRequests.map((e) => <RouteInfo>[]).toList(),
      );
      // Combine and deduplicate routes
      Set<String> uniquePolylines = <String>{};
      List<RouteInfo> allRoutes = [];
      for (List<RouteInfo> routeList in allRouteLists) {
        for (RouteInfo route in routeList) {
          // Use a simplified polyline hash for deduplication
          String routeHash = _generateRouteHash(route.points);
          if (!uniquePolylines.contains(routeHash)) {
            uniquePolylines.add(routeHash);
            // Create new RouteInfo with updated index
            RouteInfo updatedRoute = RouteInfo(
              routeIndex: allRoutes.length,
              distance: route.distance,
              duration: route.duration,
              summary: route.summary,
              points: route.points,
              safetyPercentage: route.safetyPercentage,
              totalDistance: route.totalDistance,
            );
            allRoutes.add(updatedRoute);
          }
        }
      }
      // Sort routes by priority (fastest first, then by safety)
      allRoutes.sort((a, b) {
        // Extract priority from summary (hack, but works)
        int priorityA = a.summary.contains('Fastest')
            ? 1
            : a.summary.contains('Toll-free')
            ? 2
            : 3;
        int priorityB = b.summary.contains('Fastest')
            ? 1
            : b.summary.contains('Toll-free')
            ? 2
            : 3;
        if (priorityA != priorityB) return priorityA.compareTo(priorityB);
        // Within same priority, sort by safety percentage (higher first)
        return b.safetyPercentage.compareTo(a.safetyPercentage);
      });
      // Limit to maximum 8 routes to keep UI manageable
      if (allRoutes.length > 8) {
        allRoutes = allRoutes.sublist(0, 8);
      }
      // Update UI
      setState(() {
        availableRoutes = allRoutes;
        // Add polylines with distinct colors
        _updatePolylines(); // Use helper to manage polyline display
      });
      if (allRoutes.isNotEmpty) {
        _showSnackBar('${allRoutes.length} routes found', Colors.green);
        print('Found ${allRoutes.length} unique routes');
      } else {
        _showSnackBar('No routes found', Colors.orange);
      }
    } catch (e) {
      print('Error getting directions: ${e.toString()}');
      _showSnackBar('Error getting directions: ${e.toString()}', Colors.red);
    }
  }

  // *** HELPER TO MANAGE POLYLINE DISPLAY ***
  void _updatePolylines() {
    Set<Polyline> newPolylines = <Polyline>{};
    List<Color> routeColors = [
      primaryColor, // Primary (Selected)
      Colors.green, // Secondary
      Colors.orange, // Third
      Colors.purple, // Fourth
      Colors.red, // Fifth
      Colors.teal, // Sixth
      Colors.brown, // Seventh
      Colors.pink, // Eighth
    ];

    if (_isNavigating && selectedRouteIndex < availableRoutes.length) {
      // Show only the selected route when navigating
      RouteInfo selectedRoute = availableRoutes[selectedRouteIndex];
      newPolylines.add(
        Polyline(
          polylineId: PolylineId('route_${selectedRoute.routeIndex}'),
          points: selectedRoute.points,
          color: primaryColor, // Highlight selected route
          width: 6,
        ),
      );
    } else {
      // Show all available routes (default view)
      for (int i = 0; i < availableRoutes.length; i++) {
        RouteInfo route = availableRoutes[i];
        newPolylines.add(
          Polyline(
            polylineId: PolylineId('route_${route.routeIndex}'),
            points: route.points,
            color: routeColors[i % routeColors.length],
            width: i == selectedRouteIndex ? 6 : 4,
            patterns: i == selectedRouteIndex
                ? []
                : [PatternItem.dash(10), PatternItem.gap(5)],
          ),
        );
      }
    }
    setState(() {
      polylines = newPolylines;
    });
  }


// Helper function to get routes from a single API request
  Future<List<RouteInfo>> _getSingleRouteSet(Map<String, dynamic> params) async {
    List<RouteInfo> routes = [];
    try {
      String baseUrl =
          'https://maps.googleapis.com/maps/api/directions/json';
      String request =
          '$baseUrl?origin=${currentPosition!.latitude},${currentPosition!.longitude}'
          '&destination=${destinationLocation!.latitude},${destinationLocation!.longitude}'
          '&alternatives=true'
          '&region=bd'
          '&language=en'
          '&traffic_model=best_guess'
          '&departure_time=now'
          '&key=$googleApiKey';
      if (params['avoid']?.isNotEmpty == true) {
        request += '&avoid=${params['avoid']}';
      }
      print('API Request (${params['description']}): $request');
      final response = await http.get(Uri.parse(request)).timeout(
        Duration(seconds: 8), // Individual request timeout
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'] != null) {
          for (int i = 0; i < data['routes'].length; i++) {
            try {
              var route = data['routes'][i];
              String encodedPolyline = route['overview_polyline']['points'];
              List<LatLng> routePoints = _decodePolyline(encodedPolyline);
              var leg = route['legs'][0];
              String distance = leg['distance']['text'] ?? 'Unknown';
              String duration = leg['duration']['text'] ?? 'Unknown';
              String summary =
                  '${params['description']} - ${route['summary'] ?? 'Route ${i + 1}'}';
              // Quick safety calculation (simplified for speed)
              double safetyPercentage = 100.0;
              double totalDistance = 0.0;
              try {
                // Use faster calculation if available, or fallback
                if (dangerZones.isEmpty) {
                  // No danger zones, skip safety calculation
                  totalDistance = _calculateFallbackDistance(routePoints);
                } else {
                  // Quick safety check (sample every 10th point for speed)
                  Map<String, dynamic> safetyInfo =
                  _quickSafetyCalculation(routePoints, dangerZones);
                  safetyPercentage = (safetyInfo['safety_percentage'] ??
                      100.0)
                      .toDouble()
                      .clamp(0.0, 100.0);
                  totalDistance = (safetyInfo['total_distance'] ??
                      _calculateFallbackDistance(routePoints))
                      .toDouble();
                }
              } catch (e) {
                safetyPercentage = 100.0;
                totalDistance = _calculateFallbackDistance(routePoints);
              }
              RouteInfo routeInfo = RouteInfo(
                routeIndex: i,
                distance: distance,
                duration: duration,
                summary: summary,
                points: routePoints,
                safetyPercentage: safetyPercentage,
                totalDistance: totalDistance,
              );
              routes.add(routeInfo);
            } catch (routeError) {
              print('Error processing route $i: $routeError');
              continue;
            }
          }
        }
      }
    } catch (e) {
      print('Error in ${params['description']} request: $e');
    }
    return routes;
  }

// Fast safety calculation (samples points instead of checking every segment)
  Map<String, dynamic> _quickSafetyCalculation(
      List<LatLng> polyline, List<DangerZone> dangerZones) {
    if (polyline.length < 2) {
      return {'safety_percentage': 100.0, 'total_distance': 0.0};
    }
    double totalDistance = _calculateFallbackDistance(polyline);
    // Sample every 10th point or minimum 10 points for speed
    int sampleStep = math.max(1, polyline.length ~/ 10);
    double unsafeDistance = 0.0;
    for (int i = 0; i < polyline.length - sampleStep; i += sampleStep) {
      LatLng point1 = polyline[i];
      LatLng point2 = polyline[
      math.min(i + sampleStep, polyline.length - 1)];
      double segmentDistance = haversineDistance(point1, point2);
      // Check if this segment intersects any danger zone
      for (DangerZone zone in dangerZones) {
        LatLng zoneCenter = LatLng(zone.lat, zone.lon);
        if (segmentIntersectsCircle(
            point1, point2, zoneCenter, zone.radius)) {
          unsafeDistance += math.min(segmentDistance, zone.radius * 2);
          break;
        }
      }
    }
    double safetyPercentage = totalDistance > 0
        ? ((totalDistance - unsafeDistance) / totalDistance) * 100
        : 100.0;
    return {
      'safety_percentage': math.max(0, math.min(100, safetyPercentage)),
      'total_distance': totalDistance,
    };
  }

// Generate a simple hash for route deduplication
  String _generateRouteHash(List<LatLng> points) {
    if (points.length < 4) return points.toString();
    // Use start, two middle points, and end for quick comparison
    int mid1 = points.length ~/ 3;
    int mid2 = (points.length * 2) ~/ 3;
    return '${points.first.latitude.toStringAsFixed(4)}_${points.first.longitude.toStringAsFixed(4)}_'
        '${points[mid1].latitude.toStringAsFixed(4)}_${points[mid1].longitude.toStringAsFixed(4)}_'
        '${points[mid2].latitude.toStringAsFixed(4)}_${points[mid2].longitude.toStringAsFixed(4)}_'
        '${points.last.latitude.toStringAsFixed(4)}_${points.last.longitude.toStringAsFixed(4)}';
  }

// Helper function to calculate distance between current position and destination
  double _getDistanceKm() {
    if (currentPosition == null || destinationLocation == null) return 0;
    return haversineDistance(
        LatLng(currentPosition!.latitude, currentPosition!.longitude),
        destinationLocation!) /
        1000;
  }

// Helper function to calculate fallback distance
  double _calculateFallbackDistance(List<LatLng> routePoints) {
    if (routePoints.length < 2) return 0.0;
    double distance = 0.0;
    for (int i = 0; i < routePoints.length - 1; i++) {
      distance += haversineDistance(routePoints[i], routePoints[i + 1]);
    }
    return distance;
  }

  // Decode polyline string to LatLng points
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polylinePoints = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      polylinePoints.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polylinePoints;
  }

  // Move camera to show both current location and destination
  void _moveCameraToShowBothLocations() async {
    if (currentPosition == null || destinationLocation == null) return;
    final GoogleMapController controller = await _controller.future;
    double minLat =
    math.min(currentPosition!.latitude, destinationLocation!.latitude);
    double maxLat =
    math.max(currentPosition!.latitude, destinationLocation!.latitude);
    double minLng =
    math.min(currentPosition!.longitude, destinationLocation!.longitude);
    double maxLng =
    math.max(currentPosition!.longitude, destinationLocation!.longitude);
    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  Future<void> _selectPlace(PlaceSuggestion suggestion) async {
    setState(() {
      showSuggestions = false;
      isLoading = true;
    });
    _routeLoadingController.repeat();
    _searchController.text = suggestion.mainText;
    _searchFocusNode.unfocus();
    try {
      String baseUrl =
          'https://maps.googleapis.com/maps/api/place/details/json';
      String request = '$baseUrl?place_id=${suggestion.placeId}'
          '&key=$googleApiKey'
          '&fields=name,formatted_address,geometry';
      final response = await http
          .get(Uri.parse(request))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          final name = data['result']['name'] ?? suggestion.mainText;
          final address =
              data['result']['formatted_address'] ?? suggestion.description;
          destinationLocation = LatLng(location['lat'], location['lng']);
          setState(() {
            markers.removeWhere(
                    (marker) => marker.markerId.value == 'destination');
            markers.add(
              Marker(
                markerId: const MarkerId('destination'),
                position: destinationLocation!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(
                  title: name,
                  snippet: address,
                ),
              ),
            );
          });
          if (currentPosition != null) {
            await _getDirections();
          } else {
            _showSnackBar('Destination selected', primaryColor);
          }
          if (currentPosition != null) {
            _moveCameraToShowBothLocations();
          } else {
            final GoogleMapController controller = await _controller.future;
            controller.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: destinationLocation!, zoom: 15.0),
              ),
            );
          }
        } else {
          _showSnackBar(
              'Failed to get place details: ${data['status']}', errorColor);
        }
      }
    } catch (e) {
      print('Error selecting place: $e');
      _showSnackBar('Error selecting place: ${e.toString()}', errorColor);
    } finally {
      setState(() {
        isLoading = false;
      });
      _routeLoadingController.stop();
    }
  }

  // *** NEW METHOD TO START NAVIGATION ***
  void _startNavigation() {
    if (availableRoutes.isEmpty) return;
    setState(() {
      _isNavigating = true;
    });
    _updatePolylines(); // Update map to show only the selected route
    // You can add actual navigation logic here (e.g., turn-by-turn instructions)
    _showSnackBar('Navigation started!', secondaryColor);
  }

  // *** METHOD TO STOP NAVIGATION ***
  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
    });
    _updatePolylines(); // Show all routes again
    _showSnackBar('Navigation stopped.', primaryColor);
  }

  // Keep your existing Firebase and direction methods but add the improved UI methods below
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

            const SizedBox(width: 50),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Safe Map',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Navigate to the safest route',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  Widget _buildSearchContainer() {
    return Positioned(
      top: 100, // Fixed position
      left: 20,
      right: 20,
      child: Column(
        children: [
          // NEW: Toggle button for search box
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _toggleSearchBox,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _isSearchExpanded ? Icons.expand_less : Icons.search,
                  color: primaryColor,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Search box (conditionally visible)
          if (_isSearchExpanded) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Where would you like to go?',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.search_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _clearSearch,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.clear_rounded,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                      ),
                    ),
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                onChanged: _searchPlaces,
              ),
            ),
            // Enhanced Suggestions List
            if (showSuggestions) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: suggestions.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Colors.grey.shade200,
                      indent: 60,
                    ),
                    itemBuilder: (context, index) {
                      final suggestion = suggestions[index];
                      IconData icon = _getPlaceIcon(suggestion.types);
                      return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _selectPlace(suggestion),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      icon,
                                      color: primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          suggestion.mainText,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                        if (suggestion.secondaryText.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            suggestion.secondaryText,
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Colors.grey.shade400,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ));
                      }
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  IconData _getPlaceIcon(List<String> types) {
    if (types.contains('restaurant') || types.contains('meal_takeaway')) {
      return Icons.restaurant_rounded;
    } else if (types.contains('hospital')) {
      return Icons.local_hospital_rounded;
    } else if (types.contains('school') || types.contains('university')) {
      return Icons.school_rounded;
    } else if (types.contains('shopping_mall')) {
      return Icons.shopping_bag_rounded;
    } else if (types.contains('gas_station')) {
      return Icons.local_gas_station_rounded;
    }
    return Icons.place_rounded;
  }

  Widget _buildRoutePanel() {
    // Simplified panel logic
    if (availableRoutes.isEmpty) {
      return const SizedBox.shrink(); // Don't show if no routes
    }

    return DraggableScrollableSheet(
      controller: _draggableController,
      initialChildSize: 0.15,
      minChildSize: 0.15,
      maxChildSize: _isNavigating ? 0.3 : 0.6, // Adjust max size based on state
      snap: true,
      snapSizes: _isNavigating
          ? const [0.15, 0.3]
          : const [0.15, 0.4, 0.6], // Different snap sizes for navigation
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Content
              Expanded(
                child: _isNavigating
                    ? _buildNavigationState(scrollController)
                    : _buildRouteSelectionState(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteSelectionState(ScrollController scrollController) {
    // Show route selection UI
    final selectedRoute = availableRoutes[selectedRouteIndex];
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Header with selected route info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected Route',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getSafetyColor(selectedRoute.safetyPercentage),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${selectedRoute.safetyPercentage.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildQuickStat(Icons.directions_rounded, selectedRoute.distance, 'Distance'),
                  const SizedBox(width: 20),
                  _buildQuickStat(Icons.access_time_rounded, selectedRoute.duration, 'Duration'),
                  const SizedBox(width: 20),
                  _buildQuickStat(Icons.security_rounded, _getSafetyRating(selectedRoute.safetyPercentage), 'Safety'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startNavigation,
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('Start Navigation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Route cards for switching
        Text(
          'Other Routes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: availableRoutes.length,
            itemBuilder: (context, index) {
              if (index == selectedRouteIndex) return const SizedBox.shrink(); // Hide selected in list
              final route = availableRoutes[index];
              final safetyColor = _getSafetyColor(route.safetyPercentage);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedRouteIndex = index;
                    _updatePolylines(); // Update map when route changes
                  });
                },
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Safety badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: safetyColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.security_rounded,
                                size: 12,
                                color: safetyColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${route.safetyPercentage.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: safetyColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Route info
                        Text(
                          route.distance,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          route.duration,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Spacer(),
                        // Route type indicator
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getRouteTypeFromSummary(route.summary),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildNavigationState(ScrollController scrollController) {
    // Show minimal navigation UI
    final selectedRoute = availableRoutes[selectedRouteIndex];
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Navigating',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getSafetyColor(selectedRoute.safetyPercentage),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${selectedRoute.safetyPercentage.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildQuickStat(Icons.directions_rounded, selectedRoute.distance, 'Distance'),
                  const SizedBox(width: 20),
                  _buildQuickStat(Icons.access_time_rounded, selectedRoute.duration, 'Duration'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _stopNavigation, // Stop navigation button
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop Navigation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: errorColor, // Red stop button
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildQuickStat(IconData icon, String value, String label) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
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

  Widget _buildMinimalControlButtons() {
    return Positioned(
      bottom: availableRoutes.isNotEmpty ? 140 : 40,
        right: 16,
      child: Column(
        children: [
          FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () {
              setState(() {
                showcircle = !showcircle;
              });
            },
            heroTag: "toggle_danger_points",
            child: HugeIcon(
              icon: showcircle
                  ? HugeIcons.strokeRoundedView
                  : HugeIcons.strokeRoundedViewOffSlash,
              color:showcircle
                  ? Colors.red : Colors.black,
            ),
          ),

          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            onPressed: _getCurrentLocation,
            heroTag: "location_3",
            child: HugeIcon(icon:HugeIcons.strokeRoundedGps01 , color: Colors.black),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () async {
              final GoogleMapController controller = await _controller.future;
              controller.animateCamera(
                CameraUpdate.newCameraPosition(_kDhakaPosition),
              );
            },
            heroTag: "location_4",
            child:HugeIcon(icon:HugeIcons.strokeRoundedMapsLocation02 , color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalLoadingIndicator() {
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _routeLoadingAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _routeLoadingAnimation.value * 2 * math.pi,
                        child: Icon(
                          Icons.route_rounded,
                          color: primaryColor,
                          size: 24,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Finding optimal routes...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Analyzing safety data',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Keep all your existing helper methods but update the colors and styling
  void _clearSearch() {
    setState(() {
      availableRoutes.clear();
      _searchController.clear();
      suggestions.clear();
      showSuggestions = false;
      destinationLocation = null;
      polylines.clear();
      availableRoutes.clear;
      markers.removeWhere((marker) => marker.markerId.value == 'destination');
      _isNavigating = false; // Stop navigation if search is cleared
    });
  }

  // Removed _selectRoute method (handled by _updatePolylines and direct setState)
  Color _getSafetyColor(double percentage) {
    if (percentage >= 80) return const Color(0xFF059669); // Green
    if (percentage >= 60) return const Color(0xFF0891B2); // Teal
    if (percentage >= 40) return const Color(0xFFF59E0B); // Yellow
    if (percentage >= 20) return const Color(0xFFEA580C); // Orange
    return const Color(0xFFDC2626); // Red
  }

  String _getSafetyRating(double percentage) {
    if (percentage >= 80) return 'Very Safe';
    if (percentage >= 60) return 'Safe';
    if (percentage >= 40) return 'Moderate';
    if (percentage >= 20) return 'Risky';
    return 'Dangerous';
  }

  String _getRouteTypeFromSummary(String summary) {
    if (summary.toLowerCase().contains('fastest')) return 'Fastest';
    if (summary.toLowerCase().contains('toll')) return 'Toll-free';
    if (summary.toLowerCase().contains('highway')) return 'Highway';
    if (summary.toLowerCase().contains('local')) return 'Local Roads';
    return 'Alternative';
  }

  // Keep your existing API methods (_initializeDataFromFirebase, _getDirections, etc.)
  // but update any UI feedback to use the new professional styling
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        activePage: 1,
        currentUser: widget.currentUser,
      ),
      backgroundColor: surfaceColor,
      body: Stack(
        children: [
          // Google Map with enhanced styling
          GoogleMap(
            style: '''
            [
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#ebe3cd"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#523735"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#f5f1e6"
      }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#c9b2a6"
      }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#dcd2be"
      }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels",
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
        "color": "#ae9e90"
      }
    ]
  },
  {
    "featureType": "landscape.natural",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#dfd2ae"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#dfd2ae"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#93817c"
      }
    ]
  },
  {
    "featureType": "poi.business",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#a5b076"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#447530"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#f5f1e6"
      }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#fdfcf8"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#f8c967"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#e9bc62"
      }
    ]
  },
  {
    "featureType": "road.highway.controlled_access",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#e98d58"
      }
    ]
  },
  {
    "featureType": "road.highway.controlled_access",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#db8555"
      }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#806b63"
      }
    ]
  },
  {
    "featureType": "transit.line",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#dfd2ae"
      }
    ]
  },
  {
    "featureType": "transit.line",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8f7d77"
      }
    ]
  },
  {
    "featureType": "transit.line",
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#ebe3cd"
      }
    ]
  },
  {
    "featureType": "transit.station",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#dfd2ae"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#b9d3c2"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#92998d"
      }
    ]
  }
]
            ''',
            mapType: MapType.normal,
            initialCameraPosition: _kDhakaPosition,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              mapController = controller;
            },
            markers: markers,
            circles:showcircle? circles: {},
            polylines: polylines, // Polylines managed by _updatePolylines
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            trafficEnabled: false,
          ),

          _buildCustomAppBar(),
          // Search (conditionally visible)
          _buildSearchContainer(),
          // Enhanced control buttons
          _buildMinimalControlButtons(),
          // Professional loading indicator
          if (isLoading) _buildProfessionalLoadingIndicator(),
          // Route panel (simplified and context-aware)
          if (availableRoutes.isNotEmpty) _buildRoutePanel(),
        ],
      ),
    );
  }
}


class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final List<String> types;
  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    required this.types,
  });
}


class RouteInfo {
  final int routeIndex;
  final String distance;
  final String duration;
  final String summary;
  final List<LatLng> points;
  final double safetyPercentage;
  final double totalDistance;
  RouteInfo({
    required this.routeIndex,
    required this.distance,
    required this.duration,
    required this.summary,
    required this.points,
    required this.safetyPercentage,
    required this.totalDistance,
  });
}

//
// final firestore = FirebaseFirestore.instance;
// final collectionRef = firestore.collection('Resources/DangerPoints/dangerpoints');
//
// print("Checking for existing data in 'danger_zones' collection...");
//
// // SAFETY CHECK: Prevents re-uploading if data already exists.
// final snapshot = await collectionRef.limit(1).get();
// if (snapshot.docs.isNotEmpty) {
// print("Data already exists in the 'danger_zones' collection. Aborting upload.");
// return;
// }
//
// print("No existing data found. Starting batch upload...");
//
// // A batch write is more efficient for multiple operations.
// final batch = firestore.batch();
//
// for (final zone in dangerZones) {
//
// final docRef = collectionRef.doc();
// // Add the set operation to the batch.
// batch.set(docRef, zone.toJson());
// }
//
// try {
// // Commit the batch to Firestore.
// await batch.commit();
// print("✅ Success: Uploaded ${dangerZones.length} danger zones to Firestore.");
// } catch (e) {
// print("❌ Error during batch upload: $e");
// }
