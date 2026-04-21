import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../models/complaint_model.dart';
import '../../models/reply_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';

class ComplaintReviewScreen extends StatefulWidget {
  final String complaintId;

  const ComplaintReviewScreen({required this.complaintId, super.key});

  @override
  State<ComplaintReviewScreen> createState() => _ComplaintReviewScreenState();
}

class _ComplaintReviewScreenState extends State<ComplaintReviewScreen> {
  final _replyController = TextEditingController();
  bool _isSaving = false;

  Future<void> _updateStatus(
    ComplaintModel complaint,
    ComplaintStatus newStatus,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);
    try {
      await FirestoreService().updateComplaintStatus(complaint.id, newStatus);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Status updated to ${newStatus.name}.')),
      );
    } catch (error) {
      if (!mounted) return;
      String errorMessage = 'Failed to update status. Please try again.';

      // Provide more specific error messages
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('network') ||
          errorString.contains('unavailable')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (errorString.contains('permission') ||
          errorString.contains('denied')) {
        errorMessage = 'Permission error. Please try again.';
      }

      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sendReply(ComplaintModel complaint) async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final message = _replyController.text.trim();
    if (currentUser == null || message.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);
    try {
      final reply = ReplyModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: currentUser.studentId,
        senderRole: currentUser.role,
        message: message,
        createdAt: DateTime.now().toUtc(),
      );

      // Add reply first
      await FirestoreService().addReply(complaint.id, reply);

      // Then automatically mark as "In Review" if still submitted
      if (complaint.status == ComplaintStatus.submitted) {
        await FirestoreService().updateComplaintStatus(
          complaint.id,
          ComplaintStatus.inReview,
        );
      }

      if (!mounted) return;
      _replyController.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Reply sent and status updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      String errorMessage = 'Failed to send reply. Please try again.';

      // Provide more specific error messages
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('network') ||
          errorString.contains('unavailable')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (errorString.contains('permission') ||
          errorString.contains('denied')) {
        errorMessage = 'Permission error. Please try again.';
      }

      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _openAttachment(String fileUrl) async {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Opening attachment...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final uri = Uri.parse(fileUrl);
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        if (mounted) Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to download file: ${response.statusCode}'),
          ),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = Uri.decodeFull(uri.pathSegments.last);
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      if (mounted) Navigator.pop(context);

      final extension = fileName.split('.').last.toLowerCase();
      if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                _ImagePreviewScreen(filePath: file.path, fileName: fileName),
          ),
        );
      } else if (extension == 'pdf') {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PdfViewerScreen(filePath: file.path, fileName: fileName),
          ),
        );
      } else {
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
          messenger.showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}')),
          );
        }
      }
    } catch (error) {
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Error opening attachment: $error')),
      );
    }
  }

  Color _getStatusColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.submitted:
        return Colors.orange;
      case ComplaintStatus.inReview:
        return Colors.purple;
      case ComplaintStatus.resolved:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Complaint')),
      body: StreamBuilder<ComplaintModel?>(
        stream: FirestoreService().complaintStream(widget.complaintId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final complaint = snapshot.data;
          if (complaint == null) {
            return const Center(child: Text('Complaint not found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                complaint.category,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'From: ${complaint.studentId}',
                                style: const TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Status updated: ${complaint.status.name}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          label: Text(
                            complaint.status.name.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(complaint.status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: _getStatusColor(
                            complaint.status,
                          ).withOpacity(0.15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      complaint.description,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[800],
                        height: 1.55,
                      ),
                    ),
                    if (complaint.attachmentUrls.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.attachment,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Attachments (${complaint.attachmentUrls.length})',
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Column(
                              children: complaint.attachmentUrls.map((fileUrl) {
                                final fileName = Uri.decodeFull(
                                  Uri.parse(fileUrl).pathSegments.last,
                                );
                                return InkWell(
                                  onTap: () => _openAttachment(fileUrl),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.black12,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.insert_drive_file,
                                          color: AppTheme.primary,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            fileName,
                                            style: const TextStyle(
                                              color: AppTheme.primary,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ] else if (complaint.attachmentUrl != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.attachment,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () =>
                                    _openAttachment(complaint.attachmentUrl!),
                                child: Text(
                                  complaint.attachmentUrl!,
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(134, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            backgroundColor:
                                complaint.status == ComplaintStatus.inReview
                                ? Colors.purple
                                : Colors.white,
                            foregroundColor:
                                complaint.status == ComplaintStatus.inReview
                                ? Colors.white
                                : Colors.purple,
                            elevation: 0,
                            side: const BorderSide(
                              color: Colors.purple,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed:
                              _isSaving ||
                                  complaint.status == ComplaintStatus.inReview
                              ? null
                              : () => _updateStatus(
                                  complaint,
                                  ComplaintStatus.inReview,
                                ),
                          child: const Text('Mark In Review'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(134, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            backgroundColor:
                                complaint.status == ComplaintStatus.resolved
                                ? Colors.green
                                : Colors.white,
                            foregroundColor:
                                complaint.status == ComplaintStatus.resolved
                                ? Colors.white
                                : Colors.green,
                            elevation: 0,
                            side: const BorderSide(
                              color: Colors.green,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed:
                              _isSaving ||
                                  complaint.status == ComplaintStatus.resolved
                              ? null
                              : () => _updateStatus(
                                  complaint,
                                  ComplaintStatus.resolved,
                                ),
                          child: const Text('Mark Resolved'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Conversation',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (complaint.replies.isEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'No replies yet. Send the first response to start the conversation.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              else
                Column(
                  children: complaint.replies.map((reply) {
                    final isAdmin = reply.senderRole.toLowerCase() != 'student';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: isAdmin
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isAdmin
                                ? AppTheme.primary.withOpacity(0.14)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAdmin ? 'Admin' : 'Student',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isAdmin
                                      ? AppTheme.primary
                                      : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                reply.message,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${reply.createdAt.toLocal()}'.split('.').first,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Send Reply',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _replyController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Write a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isSaving ? null : () => _sendReply(complaint),
                      child: Text(
                        _isSaving ? 'Sending...' : 'Send reply',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ImagePreviewScreen extends StatelessWidget {
  final String filePath;
  final String fileName;

  const _ImagePreviewScreen({
    required this.filePath,
    required this.fileName,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(fileName, overflow: TextOverflow.ellipsis)),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.file(File(filePath)),
        ),
      ),
    );
  }
}

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PdfViewerScreen({
    required this.filePath,
    required this.fileName,
    super.key,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  @override
  void initState() {
    super.initState();
    _openFile();
  }

  Future<void> _openFile() async {
    try {
      print('Opening file: ${widget.filePath}');
      final result = await OpenFile.open(widget.filePath);
      print('OpenFile result: ${result.type}');

      if (result.type != ResultType.done) {
        print('Failed to open file: ${result.message}');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${result.message}')));
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        // File opened successfully, close this screen
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      print('Error opening file: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening file: $e')));
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName, overflow: TextOverflow.ellipsis),
        elevation: 0,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Opening file...'),
          ],
        ),
      ),
    );
  }
}
