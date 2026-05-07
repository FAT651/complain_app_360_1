import 'reply_model.dart';

enum ComplaintStatus { pending, inProgress, resolved, closed }

extension ComplaintStatusExtension on ComplaintStatus {
  /// Convert enum to database format (snake_case)
  String toDatabaseString() {
    switch (this) {
      case ComplaintStatus.pending:
        return 'pending';
      case ComplaintStatus.inProgress:
        return 'in_progress';
      case ComplaintStatus.resolved:
        return 'resolved';
      case ComplaintStatus.closed:
        return 'closed';
    }
  }
}

class ComplaintModel {
  final String id;
  final String studentId;
  final String title;
  final String description;
  final List<String> attachmentUrls;
  final ComplaintStatus status;
  final DateTime createdAt;
  final List<ReplyModel> replies;

  ComplaintModel({
    required this.id,
    required this.studentId,
    required this.title,
    required this.description,
    this.attachmentUrls = const [],
    this.status = ComplaintStatus.pending,
    required this.createdAt,
    this.replies = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'title': title,
      'description': description,
      'attachment_urls': attachmentUrls,
      'status': status.toDatabaseString(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'replies': replies.map((reply) => reply.toJson()).toList(),
    };
  }

  factory ComplaintModel.fromJson(String id, Map<String, dynamic> json) {
    final rawReplies = json['replies'] as List<dynamic>?;
    final replyList =
        rawReplies
            ?.map(
              (item) =>
                  ReplyModel.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList() ??
        [];
    final attachmentUrlsList =
        (json['attachment_urls'] as List<dynamic>?)
            ?.map((item) => item as String)
            .toList() ??
        [];

    // Convert status name to enum and support common variants.
    ComplaintStatus statusEnum = ComplaintStatus.pending;
    final statusStr = (json['status'] as String?)?.trim().toLowerCase();
    if (statusStr != null && statusStr.isNotEmpty) {
      switch (statusStr) {
        case 'pending':
          statusEnum = ComplaintStatus.pending;
          break;
        case 'inprogress':
        case 'in_progress':
        case 'in progress':
        case 'review':
        case 'inreview':
          statusEnum = ComplaintStatus.inProgress;
          break;
        case 'resolved':
          statusEnum = ComplaintStatus.resolved;
          break;
        case 'closed':
          statusEnum = ComplaintStatus.closed;
          break;
        default:
          statusEnum = ComplaintStatus.pending;
      }
    }

    return ComplaintModel(
      id: id,
      studentId: json['student_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      attachmentUrls: attachmentUrlsList,
      status: statusEnum,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      replies: replyList,
    );
  }
}
