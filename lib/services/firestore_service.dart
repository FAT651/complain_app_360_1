import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/complaint_model.dart';
import '../models/reply_model.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';

class FirestoreService {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isMissingRpcFunction(Object error, String functionName) {
    final message = error.toString().toLowerCase();
    return message.contains('pgrst202') &&
        message.contains(functionName.toLowerCase());
  }

  Future<void> _ensureAdminUser(String currentUserId) async {
    final userCheck = await _supabase
        .from('users')
        .select('role')
        .eq('id', currentUserId)
        .eq('role', 'admin')
        .maybeSingle();

    if (userCheck == null) {
      throw Exception('Access denied: Admin privileges required');
    }
  }

  Future<String> _getStudentIdentifier(String currentUserId) async {
    final userData = await _supabase
        .from('users')
        .select('student_id')
        .eq('id', currentUserId)
        .maybeSingle();

    final studentId = userData?['student_id'] as String?;
    if (studentId == null || studentId.isEmpty) {
      throw Exception('Unable to resolve the current student profile');
    }

    return studentId;
  }

  Future<void> createUser(UserModel user) async {
    await _supabase
        .from('users')
        .insert({...user.toJson(), 'id': user.id})
        .select()
        .single();
  }

  Future<UserModel?> fetchUserByUid(String uid) async {
    final Map<String, dynamic>? data = await _supabase
        .from('users')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (data == null) return null;
    return UserModel.fromJson(uid, data);
  }

  Future<UserModel?> fetchUserByStudentId(String studentId) async {
    final Map<String, dynamic>? data = await _supabase
        .from('users')
        .select()
        .eq('student_id', studentId)
        .maybeSingle();
    if (data == null) return null;
    return UserModel.fromJson(data['id'] as String, data);
  }

  Future<UserModel?> fetchUserByEmail(String email) async {
    final Map<String, dynamic>? data = await _supabase
        .from('users')
        .select()
        .eq('email', email)
        .maybeSingle();
    if (data == null) return null;
    return UserModel.fromJson(data['id'] as String, data);
  }

  Future<void> createComplaint(ComplaintModel complaint) async {
    final row = {...complaint.toJson(), 'id': complaint.id};
    try {
      debugPrint('Submitting complaint to Supabase: ${complaint.id}');
      debugPrint('Complaint payload: $row');
      await _supabase.from('complaints').insert(row).select().single();
    } catch (e, stackTrace) {
      debugPrint('Create complaint failed: $e');
      debugPrint('$stackTrace');
      throw Exception('Failed to save complaint: $e');
    }
  }

  Future<void> updateComplaintStatus(
    String complaintId,
    ComplaintStatus status,
    String currentUserId,
    String currentUserRole,
  ) async {
    try {
      debugPrint('Updating complaint $complaintId status to ${status.name}');
      debugPrint('Current user: $currentUserId, role: $currentUserRole');

      // For admin users, use RPC function that bypasses RLS
      if (currentUserRole == 'admin') {
        await _ensureAdminUser(currentUserId);

        try {
          final response = await _supabase.rpc(
            'update_complaint_by_admin',
            params: {
              'complaint_id': complaintId,
              'new_status': status.toDatabaseString(),
            },
          );

          debugPrint('Admin update response: $response');

          if (response == null) {
            throw Exception('Admin update failed');
          }
        } catch (error) {
          if (!_isMissingRpcFunction(error, 'update_complaint_by_admin')) {
            rethrow;
          }

          debugPrint(
            'RPC update_complaint_by_admin missing; falling back to direct complaints update for $complaintId',
          );

          final response = await _supabase
              .from('complaints')
              .update({'status': status.toDatabaseString()})
              .eq('id', complaintId)
              .select();

          debugPrint('Admin fallback update response: $response');

          if (response.isEmpty) {
            throw Exception('Admin update failed - no rows updated');
          }
        }
      } else {
        // For students, use regular RLS-protected update
        final studentId = await _getStudentIdentifier(currentUserId);
        final response = await _supabase
            .from('complaints')
            .update({'status': status.toDatabaseString()})
            .eq('id', complaintId)
            .eq(
              'student_id',
              studentId,
            ) // Ensure students can only update their own complaints
            .select();

        debugPrint('Student update response: $response');
        debugPrint('Rows affected: ${response.length}');

        if (response.isEmpty) {
          throw Exception('No rows updated - check permissions');
        }
      }

      debugPrint('Complaint status update succeeded for $complaintId');
      await _createStatusChangeNotification(complaintId, status);
    } catch (error, stackTrace) {
      debugPrint(
        'Supabase updateComplaintStatus error for $complaintId: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> addReply(
    String complaintId,
    ReplyModel reply,
    String currentUserId,
    String currentUserRole,
  ) async {
    try {
      debugPrint(
        'Adding reply to complaint $complaintId by user $currentUserId (role: $currentUserRole)',
      );

      // For admin users, use RPC function that bypasses RLS
      if (currentUserRole == 'admin') {
        await _ensureAdminUser(currentUserId);

        try {
          final response = await _supabase.rpc(
            'add_reply_by_admin',
            params: {'complaint_id': complaintId, 'reply_data': reply.toJson()},
          );

          debugPrint('Admin add reply response: $response');
          if (response == null) {
            throw Exception('Admin add reply failed');
          }
        } catch (error) {
          if (!_isMissingRpcFunction(error, 'add_reply_by_admin')) {
            rethrow;
          }

          debugPrint(
            'RPC add_reply_by_admin missing; falling back to direct complaints update for $complaintId',
          );

          final Map<String, dynamic>? complaintData = await _supabase
              .from('complaints')
              .select('replies')
              .eq('id', complaintId)
              .maybeSingle();

          if (complaintData == null) {
            throw Exception('Complaint not found');
          }

          final existingReplies =
              (complaintData['replies'] as List<dynamic>?) ?? <dynamic>[];
          final updatedReplies = List<Map<String, dynamic>>.from(
            existingReplies.map((item) => Map<String, dynamic>.from(item as Map)),
          );
          updatedReplies.add(reply.toJson());

          final response = await _supabase
              .from('complaints')
              .update({'replies': updatedReplies})
              .eq('id', complaintId)
              .select();

          debugPrint('Admin fallback add reply response: $response');
          if (response.isEmpty) {
            throw Exception('Admin add reply failed - no rows updated');
          }
        }
      } else {
        // For students, use regular RLS-protected update
        final studentId = await _getStudentIdentifier(currentUserId);
        final Map<String, dynamic>? complaintData = await _supabase
            .from('complaints')
            .select('replies')
            .eq('id', complaintId)
            .eq(
              'student_id',
              studentId,
            ) // Ensure students can only reply to their own complaints
            .maybeSingle();

        if (complaintData == null) {
          throw Exception('Complaint not found or access denied');
        }

        final existingReplies =
            (complaintData['replies'] as List<dynamic>?) ?? <dynamic>[];
        final updatedReplies = List<Map<String, dynamic>>.from(
          existingReplies.map((item) => Map<String, dynamic>.from(item as Map)),
        );
        updatedReplies.add(reply.toJson());

        final response = await _supabase
            .from('complaints')
            .update({'replies': updatedReplies})
            .eq('id', complaintId)
            .eq('student_id', studentId)
            .select();

        debugPrint('Student add reply response: $response');
        if (response.isEmpty) {
          throw Exception('No rows updated - check permissions');
        }
      }

      debugPrint('Reply added successfully to complaint $complaintId');
      await _createReplyNotification(complaintId, reply);
    } catch (error, stackTrace) {
      debugPrint('Supabase addReply error for $complaintId: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> addAttachmentsToComplaint(
    String complaintId,
    List<String> attachmentUrls,
  ) async {
    try {
      await _supabase
          .from('complaints')
          .update({'attachment_urls': attachmentUrls})
          .eq('id', complaintId);

      debugPrint('Attachments added successfully to complaint $complaintId');
    } catch (error, stackTrace) {
      debugPrint(
        'Supabase addAttachmentsToComplaint error for $complaintId: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> deleteAttachmentFromComplaint(
    String complaintId,
    String fileUrl,
    List<String> updatedUrls,
  ) async {
    await _supabase
        .from('complaints')
        .update({'attachment_urls': updatedUrls})
        .eq('id', complaintId);
  }

  Stream<List<ComplaintModel>> studentComplaints(String studentId) {
    return _supabase
        .from('complaints')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .order('created_at', ascending: false)
        .map((records) {
          final rows = List<Map<String, dynamic>>.from(records as List);
          return rows
              .map((row) => ComplaintModel.fromJson(row['id'] as String, row))
              .toList();
        });
  }

  Stream<List<ComplaintModel>> allComplaints() {
    return _supabase
        .from('complaints')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((records) {
          final rows = List<Map<String, dynamic>>.from(records as List);
          return rows
              .map((row) => ComplaintModel.fromJson(row['id'] as String, row))
              .toList();
        });
  }

  Stream<ComplaintModel?> complaintStream(String complaintId) {
    debugPrint('Setting up stream for complaint $complaintId');
    return _supabase
        .from('complaints')
        .stream(primaryKey: ['id'])
        .eq('id', complaintId)
        .map((records) {
          debugPrint(
            'Stream received ${records.length} records for complaint $complaintId',
          );
          final rows = List<Map<String, dynamic>>.from(records as List);
          if (rows.isEmpty) {
            debugPrint('No records found for complaint $complaintId');
            return null;
          }
          final complaint = ComplaintModel.fromJson(
            rows.first['id'] as String,
            rows.first,
          );
          debugPrint(
            'Stream emitting complaint with ${complaint.replies.length} replies, status: ${complaint.status}',
          );
          return complaint;
        });
  }

  Future<void> _createStatusChangeNotification(
    String complaintId,
    ComplaintStatus status,
  ) async {
    final Map<String, dynamic>? complaintData = await _supabase
        .from('complaints')
        .select('student_id')
        .eq('id', complaintId)
        .maybeSingle();
    final studentId = complaintData?['student_id'] as String?;
    if (studentId == null) return;

    final Map<String, dynamic>? userData = await _supabase
        .from('users')
        .select('id')
        .eq('student_id', studentId)
        .maybeSingle();
    final userId = userData?['id'] as String?;
    if (userId == null) return;

    final notification = NotificationModel(
      id: '',
      userId: userId,
      complaintId: complaintId,
      title: 'Complaint Status Updated',
      message:
          'Your complaint status has been changed to ${status.name.toLowerCase().replaceAll('_', ' ')}',
      type: 'status_change',
      createdAt: DateTime.now(),
    );

    await _supabase.from('notifications').insert(notification.toJson());
  }

  Future<void> _createReplyNotification(
    String complaintId,
    ReplyModel reply,
  ) async {
    final Map<String, dynamic>? complaintData = await _supabase
        .from('complaints')
        .select('student_id')
        .eq('id', complaintId)
        .maybeSingle();
    final studentId = complaintData?['student_id'] as String?;
    if (studentId == null) return;

    final Map<String, dynamic>? userData = await _supabase
        .from('users')
        .select('id')
        .eq('student_id', studentId)
        .maybeSingle();
    final userId = userData?['id'] as String?;
    if (userId == null) return;

    final notification = NotificationModel(
      id: '',
      userId: userId,
      complaintId: complaintId,
      title: 'New Reply',
      message: 'You have received a new reply to your complaint',
      type: 'reply',
      createdAt: DateTime.now(),
    );

    await _supabase.from('notifications').insert(notification.toJson());
  }

  Stream<List<NotificationModel>> userNotifications(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((records) {
          final rows = List<Map<String, dynamic>>.from(records as List);
          return rows.map(NotificationModel.fromJson).toList();
        });
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'isRead': true})
        .eq('id', notificationId);
  }

  Future<void> deleteNotification(String notificationId) async {
    await _supabase.from('notifications').delete().eq('id', notificationId);
  }

  Stream<List<UserModel>> fetchAllUsers() {
    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .order('email', ascending: true)
        .map((records) {
          final rows = List<Map<String, dynamic>>.from(records as List);
          return rows
              .map((row) => UserModel.fromJson(row['id'] as String, row))
              .toList();
        });
  }

  Stream<List<UserModel>> fetchUsersByRole(String role) {
    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('role', role.toLowerCase())
        .order('email', ascending: true)
        .map((records) {
          final rows = List<Map<String, dynamic>>.from(records as List);
          return rows
              .map((row) => UserModel.fromJson(row['id'] as String, row))
              .toList();
        });
  }

  Future<void> updateUser(String uid, UserModel user) async {
    try {
      debugPrint('🔄 Updating user: $uid');
      debugPrint('📝 Update payload: ${user.toJson()}');
      await _supabase.from('users').update(user.toJson()).eq('id', uid);
      debugPrint('✅ User updated successfully');
    } catch (e) {
      debugPrint('❌ Failed to update user: $e');
      rethrow;
    }
  }

  Future<void> updateUserRole(String uid, String newRole) async {
    await _supabase
        .from('users')
        .update({'role': newRole.toLowerCase()})
        .eq('id', uid);
  }

  Future<void> deleteUser(String uid) async {
    await _supabase.from('users').delete().eq('id', uid);
  }
}
