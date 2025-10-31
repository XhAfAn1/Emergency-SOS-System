import 'emergency contact.dart';

class UserModel {
  String id;
  String name;
  String email;
  String profileImageUrl;
  String phoneNumber;
  String address;
  DateTime createdAt;
  String token;
  String msg;
  bool admin;
  bool isInDanger;
  Map<String, dynamic>? location;
  List<EmergencyContact> emergencyContacts;

  UserModel({
    required this.id,
    required this.name,
    required this.admin,
    required this.email,
    this.profileImageUrl = '',
    this.phoneNumber = '',
    this.address = '',
    this.token = '',
    this.msg = '',
    this.location,
    this.isInDanger = false,
    this.emergencyContacts = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'admin': admin,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'phoneNumber': phoneNumber,
      'address': address,
      'token': token,
      'msg': msg,
      'location': location,
      'isInDanger': isInDanger,
      'emergencyContacts': emergencyContacts.map((contact) => contact.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<EmergencyContact> contacts = [];
    if (json['emergencyContacts'] != null) {
      contacts = (json['emergencyContacts'] as List)
          .map((contactJson) => EmergencyContact.fromJson(contactJson))
          .toList();
    }

    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      admin: json['admin'] is bool
          ? json['admin']
          : json['admin'].toString().toLowerCase() == 'true',
      email: json['email'] ?? '',
      profileImageUrl: json['profileImageUrl'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      address: json['address'] ?? '',
      token: json['token'] ?? '',
      msg: json['msg'] ?? '',
      isInDanger: json['isInDanger'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      location: json['location'] != null ? Map<String, dynamic>.from(json['location']) : null,
      emergencyContacts: contacts,
    );
  }
}
