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
    String valueOrEmpty(String camel, String snake) {
      return json[camel] as String? ?? json[snake] as String? ?? '';
    }

    final createdAtValue = json['createdAt'] ?? json['created_at'];
    DateTime createdAt;
    if (createdAtValue is String) {
      createdAt = DateTime.tryParse(createdAtValue) ?? DateTime.now().toUtc();
    } else if (createdAtValue is DateTime) {
      createdAt = createdAtValue.toUtc();
    } else {
      createdAt = DateTime.now().toUtc();
    }

    return ReplyModel(
      id: valueOrEmpty('id', 'id'),
      senderId: valueOrEmpty('senderId', 'sender_id'),
      senderRole:
          valueOrEmpty('senderRole', 'sender_role').toLowerCase().isNotEmpty
          ? valueOrEmpty('senderRole', 'sender_role')
          : 'student',
      message: valueOrEmpty('message', 'message'),
      createdAt: createdAt,
    );
  }
}
