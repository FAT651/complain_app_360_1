class NotificationModel {
  final String id;
  final String userId;
  final String complaintId;
  final String title;
  final String message;
  final String type; // 'reply', 'status_change', or 'system'
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
      'user_id': userId,
      'complaint_id': complaintId,
      'title': title,
      'message': message,
      'type': type,
      'created_at': createdAt.toUtc().toIso8601String(),
      'is_read': isRead,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      complaintId: json['complaint_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'system',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}
