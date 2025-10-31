import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../Class Models/Danger zone.dart';

/// Calculate distance between two coordinates using Haversine formula
double haversineDistance(LatLng coord1, LatLng coord2) {
  const double R = 6371000; // Earth radius in meters

  double lat1 = coord1.latitude * math.pi / 180;
  double lon1 = coord1.longitude * math.pi / 180;
  double lat2 = coord2.latitude * math.pi / 180;
  double lon2 = coord2.longitude * math.pi / 180;

  double dlat = lat2 - lat1;
  double dlon = lon2 - lon1;

  double a = math.sin(dlat / 2) * math.sin(dlat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) * math.sin(dlon / 2);
  double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return R * c;
}

/// Check if line segment intersects with circle
/// This is the corrected version that matches the Python logic exactly
bool segmentIntersectsCircle(LatLng start, LatLng end, LatLng center, double radius) {
  // Vector from start to end (in coordinate space)
  double dx = end.longitude - start.longitude;
  double dy = end.latitude - start.latitude;

  // Vector from start to center (in coordinate space)
  double cx = center.longitude - start.longitude;
  double cy = center.latitude - start.latitude;

  // Dot product and length squared
  double dot = dx * cx + dy * cy;
  double lenSq = dx * dx + dy * dy;

  if (lenSq == 0) { // Zero-length segment
    return haversineDistance(start, center) <= radius;
  }

  // Parameter where projection lies on segment (0 to 1)
  double t = math.max(0, math.min(1, dot / lenSq));

  // Closest point on segment to center
  double closestLon = start.longitude + t * dx;
  double closestLat = start.latitude + t * dy;

  // Distance from closest point to center using Haversine
  double distance = haversineDistance(LatLng(closestLat, closestLon), center);

  return distance <= radius;
}



/// Calculate safety percentage for a polyline with detailed analysis
Map<String, dynamic> calculatePolylineSafety(List<LatLng> polyline, List<DangerZone> dangerZones) {
  double totalDistance = 0;
  int unsafeSegments = 0;
  double unsafeDistance = 0;
  Set<int> dangerZoneHits = <int>{};

  // Calculate total distance and check each segment
  for (int i = 0; i < polyline.length - 1; i++) {
    LatLng segmentStart = polyline[i];
    LatLng segmentEnd = polyline[i + 1];
    double segmentLength = haversineDistance(segmentStart, segmentEnd);
    totalDistance += segmentLength;

    bool segmentUnsafe = false;

    // Check if this segment intersects any danger zone
    for (int j = 0; j < dangerZones.length; j++) {
      DangerZone zone = dangerZones[j];
      LatLng zoneCenter = LatLng(zone.lat, zone.lon);

      if (segmentIntersectsCircle(segmentStart, segmentEnd, zoneCenter, zone.radius)) {
        // Cap unsafe distance at diameter of the danger zone
        unsafeDistance += math.min(segmentLength, 2 * zone.radius);
        unsafeSegments++;
        segmentUnsafe = true;
        dangerZoneHits.add(j);
        break; // Only count one danger zone per segment
      }
    }
  }

  double safeDistance = totalDistance - unsafeDistance;
  double safetyPercentage = totalDistance > 0 ? (safeDistance / totalDistance) * 100 : 100.0;

  // Ensure safety percentage is between 0 and 100
  safetyPercentage = math.max(0, math.min(100, safetyPercentage));

  return {
    'safety_percentage': safetyPercentage,
    'total_distance': totalDistance,
    'safe_distance': safeDistance,
    'unsafe_distance': unsafeDistance,
    'unsafe_segments': unsafeSegments,
    'total_segments': polyline.length - 1,
    'danger_zone_hits': dangerZoneHits.toList(),
  };
}

/// Calculate total distance of polyline
double calculatePolylineDistance(List<LatLng> polyline) {
  double total = 0;
  for (int i = 0; i < polyline.length - 1; i++) {
    total += haversineDistance(polyline[i], polyline[i + 1]);
  }
  return total;
}



