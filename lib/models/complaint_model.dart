import 'package:cloud_firestore/cloud_firestore.dart';
import 'reply_model.dart';

enum ComplaintStatus { submitted, inReview, resolved }

class ComplaintModel {
  final String id;
  final String studentId;
  final String studentEmail;
  final String category;
  final String description;
  final String? attachmentUrl;
  final List<String> attachmentUrls;
  final ComplaintStatus status;
  final DateTime createdAt;
  final List<ReplyModel> replies;

  ComplaintModel({
    required this.id,
    required this.studentId,
    required this.studentEmail,
    required this.category,
    required this.description,
    this.attachmentUrl,
    this.attachmentUrls = const [],
    this.status = ComplaintStatus.submitted,
    required this.createdAt,
    this.replies = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'studentEmail': studentEmail,
      'category': category,
      'description': description,
      'attachmentUrl': attachmentUrl,
      'attachmentUrls': attachmentUrls,
      'status': status.name,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'replies': replies.map((reply) => reply.toJson()).toList(),
    };
  }

  factory ComplaintModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final replyList =
        (data['replies'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final attachmentUrlsList =
        (data['attachmentUrls'] as List<dynamic>?)?.cast<String>() ?? [];
    return ComplaintModel(
      id: doc.id,
      studentId: data['studentId'] as String? ?? '',
      studentEmail: data['studentEmail'] as String? ?? '',
      category: data['category'] as String? ?? '',
      description: data['description'] as String? ?? '',
      attachmentUrl: data['attachmentUrl'] as String?,
      attachmentUrls: attachmentUrlsList,
      status: ComplaintStatus.values.firstWhere(
        (status) => status.name == (data['status'] as String? ?? 'submitted'),
        orElse: () => ComplaintStatus.submitted,
      ),
      createdAt: DateTime.parse(
        data['createdAt'] as String? ??
            DateTime.now().toUtc().toIso8601String(),
      ),
      replies: replyList.map((reply) => ReplyModel.fromJson(reply)).toList(),
    );
  }
}
