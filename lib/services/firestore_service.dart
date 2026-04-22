import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/complaint_model.dart';
import '../models/reply_model.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';

class FirestoreService {
  late FirebaseFirestore _firestore;

  // Dummy data for Linux testing
  static final _dummyUserSnapshot = {
    'uid': 'linux-test-user',
    'email': 'test@complaintapp.app',
    'studentId': 'test001',
    'role': 'student',
    'displayName': 'Test User',
    'createdAt': DateTime.now().toIso8601String(),
  };

  FirestoreService() {
    if (!Platform.isLinux) {
      _firestore = FirebaseFirestore.instance;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _userCollection =>
      Platform.isLinux ? null : _firestore.collection('users');
  CollectionReference<Map<String, dynamic>>? get _complaintCollection =>
      Platform.isLinux ? null : _firestore.collection('complaints');
  CollectionReference<Map<String, dynamic>>? get _notificationCollection =>
      Platform.isLinux ? null : _firestore.collection('notifications');

  Future<void> createUser(UserModel user) async {
    if (Platform.isLinux) return; // Skip on Linux
    final doc = _userCollection!.doc(user.uid);
    await doc.set(user.toJson(), SetOptions(merge: true));
  }

  Future<UserModel?> fetchUserByUid(String uid) async {
    if (Platform.isLinux) return null; // Return null on Linux
    final snapshot = await _userCollection!.doc(uid).get();
    if (!snapshot.exists) return null;
    return UserModel.fromJson(snapshot.id, snapshot.data()!);
  }

  Future<UserModel?> fetchUserByStudentId(String studentId) async {
    if (Platform.isLinux) return null; // Return null on Linux
    final snapshot = await _userCollection!
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return UserModel.fromJson(
      snapshot.docs.first.id,
      snapshot.docs.first.data(),
    );
  }

  Future<UserModel?> fetchUserByEmail(String email) async {
    if (Platform.isLinux) return null; // Return null on Linux
    final snapshot = await _userCollection!
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return UserModel.fromJson(
      snapshot.docs.first.id,
      snapshot.docs.first.data(),
    );
  }

  Future<void> createComplaint(ComplaintModel complaint) async {
    if (Platform.isLinux) return; // Skip on Linux
    final doc = _complaintCollection!.doc(complaint.id);
    await doc.set(complaint.toJson());
  }

  Future<void> updateComplaintStatus(
    String complaintId,
    ComplaintStatus status,
  ) async {
    if (Platform.isLinux) return; // Skip on Linux
    if (kDebugMode) {
      print(
        'FirestoreService: Updating status for complaint $complaintId to ${status.name}',
      );
    }
    await _complaintCollection!.doc(complaintId).update({
      'status': status.name,
    });
    if (kDebugMode) {
      print('FirestoreService: Status updated successfully');
    }

    // Create notification for student
    await _createStatusChangeNotification(complaintId, status);
  }

  Future<void> addReply(String complaintId, ReplyModel reply) async {
    if (Platform.isLinux) return; // Skip on Linux
    if (kDebugMode) {
      print('FirestoreService: Adding reply to complaint $complaintId');
    }
    await _complaintCollection!.doc(complaintId).update({
      'replies': FieldValue.arrayUnion([reply.toJson()]),
    });
    if (kDebugMode) {
      print('FirestoreService: Reply added successfully');
    }

    // Create notification for student
    await _createReplyNotification(complaintId, reply);
  }

  Future<void> addAttachmentsToComplaint(
    String complaintId,
    List<String> attachmentUrls,
  ) async {
    if (Platform.isLinux) return; // Skip on Linux
    try {
      if (kDebugMode) {
        print(
          'FirestoreService: Adding ${attachmentUrls.length} attachments to complaint $complaintId',
        );
      }
      await _complaintCollection!.doc(complaintId).update({
        'attachmentUrls': FieldValue.arrayUnion(attachmentUrls),
      });
      if (kDebugMode) {
        print('FirestoreService: Attachments added successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('FirestoreService ERROR adding attachments: $e');
      }
      rethrow;
    }
  }

  Future<void> deleteAttachmentFromComplaint(
    String complaintId,
    String fileUrl,
    List<String> updatedUrls,
  ) async {
    if (Platform.isLinux) return; // Skip on Linux
    try {
      if (kDebugMode) {
        print(
          'FirestoreService: Deleting attachment from complaint $complaintId',
        );
      }
      await _complaintCollection!.doc(complaintId).update({
        'attachmentUrls': updatedUrls,
      });
      if (kDebugMode) {
        print('FirestoreService: Attachment deleted successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('FirestoreService ERROR deleting attachment: $e');
      }
      rethrow;
    }
  }

  Stream<List<ComplaintModel>> studentComplaints(String studentId) {
    if (Platform.isLinux) {
      // Return empty stream on Linux for testing
      return Stream.value([]);
    }

    if (kDebugMode) {
      print('FirestoreService: Fetching complaints for studentId: $studentId');
    }
    return _complaintCollection!
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .handleError((error) {
          if (kDebugMode) {
            print('FirestoreService ERROR in studentComplaints: $error');
          }
        })
        .map((snapshot) {
          final complaints = snapshot.docs
              .map(ComplaintModel.fromDocument)
              .toList();
          // Sort client-side to avoid requiring composite index
          complaints.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (kDebugMode) {
            print(
              'FirestoreService: Got ${complaints.length} complaints for $studentId',
            );
          }
          return complaints;
        });
  }

  Stream<List<ComplaintModel>> allComplaints() {
    if (Platform.isLinux) {
      // Return empty stream on Linux for testing
      return Stream.value([]);
    }

    return _complaintCollection!
        .snapshots()
        .handleError((error) {
          if (kDebugMode) {
            print('FirestoreService ERROR in allComplaints: $error');
          }
        })
        .map((snapshot) {
          final complaints = snapshot.docs
              .map(ComplaintModel.fromDocument)
              .toList();
          // Sort client-side by creation date
          complaints.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (kDebugMode) {
            print(
              'FirestoreService: Got ${complaints.length} total complaints',
            );
          }
          return complaints;
        });
  }

  Stream<ComplaintModel?> complaintStream(String complaintId) {
    if (Platform.isLinux) {
      return Stream.value(null);
    }

    return _complaintCollection!.doc(complaintId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return ComplaintModel.fromDocument(snapshot);
    });
  }

  Future<void> _createStatusChangeNotification(
    String complaintId,
    ComplaintStatus status,
  ) async {
    if (Platform.isLinux) return; // Skip on Linux
    try {
      // Get complaint to find student ID
      final complaintDoc = await _complaintCollection!.doc(complaintId).get();
      if (!complaintDoc.exists) return;

      final complaintData = complaintDoc.data()!;
      final studentId = complaintData['studentId'] as String?;

      if (studentId == null) return;

      // Get user ID from student ID
      final userDoc = await _userCollection!
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (userDoc.docs.isEmpty) return;

      final userId = userDoc.docs.first.id;

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

      await _notificationCollection!.add(notification.toJson());
      if (kDebugMode) {
        print('FirestoreService: Status change notification created');
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          'FirestoreService: Error creating status change notification: $e',
        );
      }
    }
  }

  Future<void> _createReplyNotification(
    String complaintId,
    ReplyModel reply,
  ) async {
    if (Platform.isLinux) return; // Skip on Linux
    try {
      // Get complaint to find student ID
      final complaintDoc = await _complaintCollection!.doc(complaintId).get();
      if (!complaintDoc.exists) return;

      final complaintData = complaintDoc.data()!;
      final studentId = complaintData['studentId'] as String?;

      if (studentId == null) return;

      // Get user ID from student ID
      final userDoc = await _userCollection!
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (userDoc.docs.isEmpty) return;

      final userId = userDoc.docs.first.id;

      final notification = NotificationModel(
        id: '',
        userId: userId,
        complaintId: complaintId,
        title: 'New Reply',
        message: 'You have received a new reply to your complaint',
        type: 'reply',
        createdAt: DateTime.now(),
      );

      await _notificationCollection!.add(notification.toJson());
      if (kDebugMode) {
        print('FirestoreService: Reply notification created');
      }
    } catch (e) {
      if (kDebugMode) {
        print('FirestoreService: Error creating reply notification: $e');
      }
    }
  }

  Stream<List<NotificationModel>> userNotifications(String userId) {
    if (Platform.isLinux) {
      return Stream.value([]);
    }

    if (kDebugMode) {
      print('FirestoreService: Fetching notifications for user: $userId');
    }
    return _notificationCollection!
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
          if (kDebugMode) {
            print('FirestoreService ERROR in userNotifications: $error');
          }
        })
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) => NotificationModel.fromDocument(doc))
              .toList();
          if (kDebugMode) {
            print(
              'FirestoreService: Got ${notifications.length} notifications for $userId',
            );
          }
          return notifications;
        });
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    if (Platform.isLinux) return; // Skip on Linux
    await _notificationCollection!.doc(notificationId).update({'isRead': true});
  }

  Future<void> deleteNotification(String notificationId) async {
    if (Platform.isLinux) return; // Skip on Linux
    await _notificationCollection!.doc(notificationId).delete();
  }

  // User Management CRUD Operations

  Stream<List<UserModel>> fetchAllUsers() {
    if (Platform.isLinux) {
      return Stream.value([]);
    }

    return _userCollection!
        .snapshots()
        .handleError((error) {
          if (kDebugMode) {
            print('FirestoreService ERROR in fetchAllUsers: $error');
          }
        })
        .map((snapshot) {
          final users = snapshot.docs
              .map((doc) => UserModel.fromJson(doc.id, doc.data()))
              .toList();
          // Sort by email
          users.sort((a, b) => a.email.compareTo(b.email));
          return users;
        });
  }

  Stream<List<UserModel>> fetchUsersByRole(String role) {
    if (Platform.isLinux) {
      return Stream.value([]);
    }

    return _userCollection!
        .where('role', isEqualTo: role.toLowerCase())
        .snapshots()
        .handleError((error) {
          if (kDebugMode) {
            print('FirestoreService ERROR in fetchUsersByRole: $error');
          }
        })
        .map((snapshot) {
          final users = snapshot.docs
              .map((doc) => UserModel.fromJson(doc.id, doc.data()))
              .toList();
          users.sort((a, b) => a.email.compareTo(b.email));
          return users;
        });
  }

  Future<void> updateUser(String uid, UserModel user) async {
    if (Platform.isLinux) return; // Skip on Linux
    try {
      if (kDebugMode) {
        print('FirestoreService: Updating user $uid');
      }
      await _userCollection!.doc(uid).update(user.toJson());
      if (kDebugMode) {
        print('FirestoreService: User updated successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('FirestoreService ERROR updating user: $e');
      }
      rethrow;
    }
  }

  Future<void> updateUserRole(String uid, String newRole) async {
    if (Platform.isLinux) return; // Skip on Linux
    try {
      if (kDebugMode) {
        print('FirestoreService: Updating role for user $uid to $newRole');
      }
      await _userCollection!.doc(uid).update({'role': newRole.toLowerCase()});
      if (kDebugMode) {
        print('FirestoreService: User role updated successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('FirestoreService ERROR updating user role: $e');
      }
      rethrow;
    }
  }

  Future<void> deleteUser(String uid) async {
    if (Platform.isLinux) return; // Skip on Linux
    try {
      if (kDebugMode) {
        print('FirestoreService: Deleting user $uid');
      }
      await _userCollection!.doc(uid).delete();
      if (kDebugMode) {
        print('FirestoreService: User deleted successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('FirestoreService ERROR deleting user: $e');
      }
      rethrow;
    }
  }
}
