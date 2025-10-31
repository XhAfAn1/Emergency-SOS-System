import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackMessage {
  final String id;
  final String userId;
  final String message;
  final DateTime createdAt;

  FeedbackMessage({
    required this.id,
    required this.userId,
    required this.message,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory FeedbackMessage.fromJson(String id, Map<String, dynamic> json) {
    return FeedbackMessage(
      id: id,
      userId: json['userId'] as String,
      message: json['message'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }
}
