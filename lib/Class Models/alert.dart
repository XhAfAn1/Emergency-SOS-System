import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String alertId;
  final String userId;
  final String userName;
  final String userPhone;
  final String? address;
  final String? pstation;
  final String? hpital;
  final String? message;
  final String? etype;
  final String status;
  final Timestamp timestamp;
  final Timestamp? safeTime;
  final int severity;
  final int notified;
  final List<String>? responders;
  final List<String>? reached;
  final Map<String, dynamic>? location;

  AlertModel({
    required this.alertId,
    required this.userId,
    required this.userName,
    required this.userPhone,
    this.address,
    this.pstation,
    this.hpital,
    this.message,
    this.etype,
    required this.status,
    required this.timestamp,
    this.safeTime,
    required this.severity,
    this.notified = 0,
     this.responders,
    this.reached,
    this.location
  });


  factory AlertModel.fromJson(Map<String, dynamic> json, String docId) {
    return AlertModel(
      alertId: docId,
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userPhone: json['userPhone'] ?? '',
      address: json['address'] ?? '',
      pstation: json['pstation'] ?? '',
      hpital: json['hpital'] ?? '',
      message: json['message'] ?? '',
      etype: json['etype'] ?? 'unknown',
      status: json['status'] ?? 'active',
      timestamp: json['timestamp'] ?? Timestamp.now(),
      safeTime: json['safeTime'],
      severity: json['severity'] ?? 1,
      notified: json['notified'] ?? 0,
      responders: List<String>.from(json['responders'] ?? []),
      reached: List<String>.from(json['reached'] ?? []),
      location: (json['location'] != null)
          ? {
        'latitude': json['location']['latitude']?.toDouble(),
        'longitude': json['location']['longitude']?.toDouble(),
      }
          : null,
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'alertId':alertId,
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'address': address,
      'pstation': pstation,
      'hpital': hpital,
      'message': message,
      'etype': etype,
      'status': status,
      'timestamp': timestamp,
      'safeTime': safeTime,
      'severity': severity,
      'notified': notified,
      'responders': responders,
      'reached': reached,
      'location': location,
    };
  }
}
