class ReplyModel {
  final String id;
  final String senderId;
  final String senderRole;
  final String message;
  final DateTime createdAt;

  ReplyModel({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.message,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderRole': senderRole,
      'message': message,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  factory ReplyModel.fromJson(Map<String, dynamic> json) {
    return ReplyModel(
      id: json['id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderRole: json['senderRole'] as String? ?? 'student',
      message: json['message'] as String? ?? '',
      createdAt: DateTime.parse(
        json['createdAt'] as String? ??
            DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }
}
