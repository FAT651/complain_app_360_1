import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String complaintId;
  final String title;
  final String message;
  final String type; // 'reply' or 'status_change'
  final DateTime createdAt;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.complaintId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'complaintId': complaintId,
      'title': title,
      'message': message,
      'type': type,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'isRead': isRead,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      complaintId: json['complaintId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'reply',
      createdAt: DateTime.parse(
        json['createdAt'] as String? ??
            DateTime.now().toUtc().toIso8601String(),
      ),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  factory NotificationModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      complaintId: data['complaintId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      type: data['type'] as String? ?? 'reply',
      createdAt: DateTime.parse(
        data['createdAt'] as String? ??
            DateTime.now().toUtc().toIso8601String(),
      ),
      isRead: data['isRead'] as bool? ?? false,
    );
  }
}
