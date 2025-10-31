class HospitalModel {
  final String hospitalName;
  final String phone;
  final String address;
  final Map<String, dynamic> location;

  HospitalModel({
    required this.hospitalName,
    required this.phone,
    required this.address,
    required this.location,
  });

  factory HospitalModel.fromJson(Map<String, dynamic> json) {
    return HospitalModel(
      hospitalName: json['hospitalName'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      location: {
        'latitude': (json['location']?['latitude'] ?? 0.0) as double,
        'longitude': (json['location']?['longitude'] ?? 0.0) as double,
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hospitalName': hospitalName,
      'phone': phone,
      'address': address,
      'location': {
        'latitude': location['latitude'],
        'longitude': location['longitude'],
      },
    };
  }
}
