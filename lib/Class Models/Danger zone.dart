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