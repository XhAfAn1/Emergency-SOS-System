
import 'package:cloud_firestore/cloud_firestore.dart';
class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String userProfileImage;
  final String content;
  final bool temp;
  final DateTime createdAt;
  final List<String> upvotes;
  List<String> downvotes;
  final int commentCount;

  PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userProfileImage,
    required this.content,
    required this.temp,
    required this.createdAt,
    required this.upvotes,
    required this.downvotes,
    required this.commentCount,
  });

  factory PostModel.fromJson(Map<String, dynamic> map, String id) {
    return PostModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userProfileImage: map['userProfileImage'] ?? '',
      content: map['content'] ?? '',
      temp: map['temp'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      upvotes: List<String>.from(map['upvotes'] ?? []),
      downvotes: List<String>.from(map['downvotes'] ?? []),
      commentCount: map['commentCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userProfileImage': userProfileImage,
      'content': content,
      'temp': temp,
      'createdAt': Timestamp.fromDate(createdAt),
      'upvotes': upvotes,
      'downvotes': downvotes,
      'commentCount': commentCount,
    };
  }
}

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String userProfileImage;
  final String content;
  final DateTime createdAt;
  final List<String> upvotes;
  final List<String> downvotes;
  final String? parentCommentId;
  final int replyCount;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.userProfileImage,
    required this.content,
    required this.createdAt,
    required this.upvotes,
    required this.downvotes,
    this.parentCommentId,
    required this.replyCount,
  });

  factory CommentModel.fromJson(Map<String, dynamic> map, String id) {
    return CommentModel(
      id: id,
      postId: map['postId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userProfileImage: map['userProfileImage'] ?? '',
      content: map['content'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      upvotes: List<String>.from(map['upvotes'] ?? []),
      downvotes: List<String>.from(map['downvotes'] ?? []),
      parentCommentId: map['parentCommentId'],
      replyCount: map['replyCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userProfileImage': userProfileImage,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'upvotes': upvotes,
      'downvotes': downvotes,
      'parentCommentId': parentCommentId,
      'replyCount': replyCount,
    };
  }
}