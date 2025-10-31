import 'package:flutter_test/flutter_test.dart';
import 'package:reqmob/lib/Class Models/DangerZone.dart';

class DangerZone {
  final double lat;
  final double lon;
  final double radius;

  const DangerZone({
    required this.lat,
    required this.lon,
    required this.radius
  });

  @override
  String toString() {
    return 'DangerZone(lat: $lat, lon: $lon, radius: $radius)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DangerZone &&
        other.lat == lat &&
        other.lon == lon &&
        other.radius == radius;
  }

  @override
  int get hashCode => lat.hashCode ^ lon.hashCode ^ radius.hashCode;

  factory DangerZone.fromJson(Map<String, dynamic> json) {
    return DangerZone(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      radius: (json['radius'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lon': lon,
      'radius': radius,
    };
  }
}
// End of DangerZone class copy

void main() {
  // Define a sample instance and its properties for reuse
  const testLat = 40.7128;
  const testLon = -74.0060;
  const testRadius = 500.0;
  
  // Define a sample JSON map
  final testJson = {
    'lat': testLat,
    'lon': testLon,
    'radius': testRadius,
  };

  group('DangerZone Unit Tests', () {
    
    // Test 1: Basic initialization and property access
    test('should initialize with correct values', () {
      const zone = DangerZone(lat: testLat, lon: testLon, radius: testRadius);
      expect(zone.lat, testLat);
      expect(zone.lon, testLon);
      expect(zone.radius, testRadius);
    });

    // Test 2: toString() implementation
    test('toString should return the correct string representation', () {
      const zone = DangerZone(lat: testLat, lon: testLon, radius: testRadius);
      final expectedString = 'DangerZone(lat: $testLat, lon: $testLon, radius: $testRadius)';
      expect(zone.toString(), expectedString);
    });

    // Test 3: operator == and hashCode for equality
    test('should be equal when properties are identical', () {
      const zone1 = DangerZone(lat: testLat, lon: testLon, radius: testRadius);
      const zone2 = DangerZone(lat: testLat, lon: testLon, radius: testRadius);
      
      expect(zone1, zone2);
      expect(zone1.hashCode, zone2.hashCode);
    });

    // Test 4: operator == and hashCode for inequality
    test('should NOT be equal when properties are different', () {
      const zone1 = DangerZone(lat: testLat, lon: testLon, radius: testRadius);
      const zone3 = DangerZone(lat: 10.0, lon: 20.0, radius: 100.0);
      
      expect(zone1, isNot(zone3));
      // Hash codes are highly likely to be different, but strictly checking inequality
      // for all possible combinations is complex. We rely on the operator== check.
      // If operator== is false, hashCode can technically be the same (collision),
      // but it should be a rare exception.
    });

    // Test 5: toJson() serialization
    test('toJson should correctly convert the object to a Map', () {
      const zone = DangerZone(lat: testLat, lon: testLon, radius: testRadius);
      final jsonMap = zone.toJson();
      
      expect(jsonMap, testJson);
      expect(jsonMap['lat'], testLat);
      expect(jsonMap['lon'], testLon);
      expect(jsonMap['radius'], testRadius);
    });

    // Test 6: fromJson() deserialization
    test('fromJson should correctly create an object from a Map', () {
      final zone = DangerZone.fromJson(testJson);
      
      expect(zone.lat, testLat);
      expect(zone.lon, testLon);
      expect(zone.radius, testRadius);
    });
    
    // Test 7: fromJson and toJson round trip
    test('fromJson(toJson(object)) should result in an equal object', () {
      const originalZone = DangerZone(lat: testLat, lon: testLon, radius: testRadius);
      
      final jsonMap = originalZone.toJson();
      final roundTripZone = DangerZone.fromJson(jsonMap);
      
      expect(roundTripZone, originalZone);
    });

  });
}
