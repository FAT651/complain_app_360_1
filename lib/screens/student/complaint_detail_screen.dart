import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'dart:typed_data';

import '../../models/complaint_model.dart';
import '../../models/reply_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../utils/app_theme.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final String complaintId;

  const ComplaintDetailScreen({required this.complaintId, super.key});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  final _replyController = TextEditingController();
  bool _isSending = false;
  List<String> _newAttachmentNames = [];
  List<Uint8List> _newAttachmentBytes = [];
  bool _isUploadingFiles = false;

  Future<void> _sendReply(ComplaintModel complaint) async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final message = _replyController.text.trim();
    if (currentUser == null || message.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final reply = ReplyModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: currentUser.studentId,
        senderRole: currentUser.role,
        message: message,
        createdAt: DateTime.now().toUtc(),
      );
      await FirestoreService().addReply(complaint.id, reply);
      if (!mounted) return;
      _replyController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Response sent.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send response: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickMoreAttachments() async {
    final result = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
    );

    if (result == null || result.files.isEmpty) return;

    const maxSizeInBytes = 4 * 1024 * 1024;
    List<String> failedFiles = [];

    for (var file in result.files) {
      if (file.size > maxSizeInBytes) {
        failedFiles.add(file.name);
      }
    }

    if (failedFiles.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('These files exceed 4MB: ${failedFiles.join(", ")}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      for (var file in result.files) {
        if (!_newAttachmentNames.contains(file.name)) {
          _newAttachmentNames.add(file.name);
          _newAttachmentBytes.add(file.bytes!);
        }
      }
    });
  }

  void _removeNewAttachment(int index) {
    setState(() {
      _newAttachmentNames.removeAt(index);
      _newAttachmentBytes.removeAt(index);
    });
  }

  Future<void> _uploadNewAttachments(String complaintId) async {
    if (_newAttachmentNames.isEmpty) return;

    setState(() => _isUploadingFiles = true);
    try {
      List<String> uploadedUrls = [];
      for (int i = 0; i < _newAttachmentBytes.length; i++) {
        try {
          final url = await StorageService().uploadComplaintAttachment(
            complaintId: complaintId,
            fileBytes: _newAttachmentBytes[i],
            fileName: _newAttachmentNames[i],
          );
          uploadedUrls.add(url);
        } catch (e) {
          print('Error uploading file ${_newAttachmentNames[i]}: $e');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload ${_newAttachmentNames[i]}'),
            ),
          );
        }
      }

      if (uploadedUrls.isNotEmpty) {
        await FirestoreService().addAttachmentsToComplaint(
          complaintId,
          uploadedUrls,
        );
        if (!mounted) return;
        setState(() {
          _newAttachmentNames.clear();
          _newAttachmentBytes.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Files uploaded successfully')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading files: $error')));
    } finally {
      if (mounted) setState(() => _isUploadingFiles = false);
    }
  }

  Future<void> _deleteAttachment(
    String complaintId,
    String fileUrl,
    List<String> attachmentUrls,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: const Text('Are you sure you want to delete this file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final updatedUrls = List<String>.from(attachmentUrls);
      updatedUrls.remove(fileUrl);

      await FirestoreService().deleteAttachmentFromComplaint(
        complaintId,
        fileUrl,
        updatedUrls,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File deleted successfully')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting file: $error')));
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Color _getStatusColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.submitted:
        return Colors.orange;
      case ComplaintStatus.inReview:
        return Colors.blue;
      case ComplaintStatus.resolved:
        return Colors.green;
    }
  }

  IconData _getStatusIcon(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.submitted:
        return Icons.hourglass_empty;
      case ComplaintStatus.inReview:
        return Icons.autorenew;
      case ComplaintStatus.resolved:
        return Icons.check_circle;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _openAttachment(String fileUrl) async {
    try {
      if (!mounted) return;

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Downloading file...'),
            ],
          ),
        ),
      );

      // Extract file extension from URL
      String fileName = fileUrl.split('/').last;
      String? fileExtension = fileName.split('.').last.toLowerCase();

      print('Downloading file: $fileName with extension: $fileExtension');

      // Download file from URL
      final response = await http.get(Uri.parse(fileUrl));

      if (response.statusCode != 200) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download file: ${response.statusCode}'),
          ),
        );
        return;
      }

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);

      // Write file to temporary directory
      await file.writeAsBytes(response.bodyBytes);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Determine file type and open accordingly
      if (fileExtension == 'pdf') {
        _openPdfFile(filePath, fileName);
      } else if ([
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
      ].contains(fileExtension)) {
        _openImageFile(filePath, fileName);
      } else if (['txt', 'doc', 'docx'].contains(fileExtension)) {
        // For document files, show a message and option to open
        _showFileOptionsDialog(fileUrl, fileName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'File type .$fileExtension not supported for in-app viewing',
            ),
          ),
        );
      }
    } catch (e) {
      print('Error in _openAttachment: $e');
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog if open
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening attachment: $e')));
    }
  }

  void _openPdfFile(String filePath, String fileName) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PdfViewerScreen(filePath: filePath, fileName: fileName),
      ),
    );
  }

  void _openImageFile(String filePath, String fileName) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(fileName, overflow: TextOverflow.ellipsis),
            elevation: 0,
          ),
          body: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(child: Image.file(File(filePath))),
          ),
        ),
      ),
    );
  }

  void _showFileOptionsDialog(String fileUrl, String fileName) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open File'),
        content: Text(
          '$fileName cannot be opened in-app. Would you like to download it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fileUrl));
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('URL copied to clipboard')),
              );
            },
            child: const Text('Copy URL'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Complaint Details'), elevation: 0),
      body: StreamBuilder<ComplaintModel?>(
        stream: FirestoreService().complaintStream(widget.complaintId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading complaint',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }
          final complaint = snapshot.data;
          if (complaint == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Complaint not found',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final statusColor = _getStatusColor(complaint.status);
          final statusIcon = _getStatusIcon(complaint.status);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header card with status
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                complaint.category,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Submitted ${_formatDate(complaint.createdAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(statusIcon, color: statusColor, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                complaint.status.name.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Description card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      complaint.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Attachments card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Attachments (${complaint.attachmentUrls.length})',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                              ),
                              InkWell(
                                onTap: _pickMoreAttachments,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.add,
                                        size: 16,
                                        color: AppTheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Add',
                                        style: TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (complaint.attachmentUrls.isEmpty &&
                              _newAttachmentNames.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'No files attached',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Existing attachments
                    if (complaint.attachmentUrls.isNotEmpty)
                      Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Divider(height: 1),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Files',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: complaint.attachmentUrls.length,
                                  itemBuilder: (context, index) {
                                    final fileUrl =
                                        complaint.attachmentUrls[index];
                                    final fileName = fileUrl
                                        .split('/')
                                        .last
                                        .split('_')
                                        .last;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: InkWell(
                                        onTap: () => _openAttachment(fileUrl),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withValues(
                                              alpha: 0.05,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.primary
                                                  .withValues(alpha: 0.2),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.picture_as_pdf,
                                                size: 20,
                                                color: AppTheme.primary,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      fileName,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Tap to open',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[500],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () => _deleteAttachment(
                                                  complaint.id,
                                                  fileUrl,
                                                  complaint.attachmentUrls,
                                                ),
                                                child: Icon(
                                                  Icons.delete_outline,
                                                  size: 18,
                                                  color: Colors.red[400],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    // New attachments to upload
                    if (_newAttachmentNames.isNotEmpty)
                      Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Divider(height: 1),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'New Files (${_newAttachmentNames.length})',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[600],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: _isUploadingFiles
                                          ? null
                                          : () => _uploadNewAttachments(
                                              complaint.id,
                                            ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                      ),
                                      child: _isUploadingFiles
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                          : const Text(
                                              'Upload',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _newAttachmentNames.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(
                                            alpha: 0.05,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.orange.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.picture_as_pdf,
                                              size: 20,
                                              color: Colors.orange[400],
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _newAttachmentNames[index],
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Pending upload',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[500],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () =>
                                                  _removeNewAttachment(index),
                                              child: Icon(
                                                Icons.close,
                                                size: 18,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Replies section
              Text(
                'Replies (${complaint.replies.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),

              if (complaint.replies.isEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 40,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No replies yet',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: List.generate(complaint.replies.length, (index) {
                    final reply = complaint.replies[index];
                    final isAdmin = reply.senderRole.toLowerCase() == 'admin';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: isAdmin
                            ? Border(
                                left: BorderSide(
                                  color: AppTheme.primary,
                                  width: 4,
                                ),
                              )
                            : null,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isAdmin
                                      ? AppTheme.primary.withValues(alpha: 0.1)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  isAdmin
                                      ? Icons.admin_panel_settings
                                      : Icons.person,
                                  size: 16,
                                  color: isAdmin
                                      ? AppTheme.primary
                                      : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isAdmin
                                        ? 'ADMIN SUPPORT'
                                        : reply.senderRole.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isAdmin
                                          ? AppTheme.primary
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  if (!isAdmin)
                                    Text(
                                      reply.senderId,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                '${reply.createdAt.month}/${reply.createdAt.day}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            reply.message,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              const SizedBox(height: 24),

              // Reply input
              Text(
                'Send a follow-up',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _replyController,
                maxLines: 4,
                decoration: AppTheme.formInputDecoration(
                  label: 'Write a message',
                  icon: Icons.chat_bubble_outline,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppTheme.primary, width: 2),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isSending ? null : () => _sendReply(complaint),
                  child: Text(
                    _isSending ? 'Sending...' : 'Send follow-up',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
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
