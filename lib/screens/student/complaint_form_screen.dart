import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/complaint_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

class ComplaintFormScreen extends StatefulWidget {
  const ComplaintFormScreen({super.key});

  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = complaintCategories.first;
  final List<String> _attachmentNames = [];
  final List<Uint8List> _attachmentBytes = [];
  bool _isSubmitting = false;

  Future<void> _pickAttachment() async {
    final result = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowMultiple: true, // Allow multiple files
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'txt',
        'jpg',
        'jpeg',
        'png',
      ], // Common file types
    );

    if (result == null || result.files.isEmpty) return;

    // Check file size (4MB limit per file)
    const maxSizeInBytes = 4 * 1024 * 1024; // 4MB
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
        if (!_attachmentNames.contains(file.name)) {
          _attachmentNames.add(file.name);
          _attachmentBytes.add(file.bytes!);
        }
      }
    });
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachmentNames.removeAt(index);
      _attachmentBytes.removeAt(index);
    });
  }

  Future<void> _submitComplaint() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    if (currentUser == null) return;
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a complaint title.')),
      );
      return;
    }
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add complaint details.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final complaintId = const Uuid().v4();
      final complaint = ComplaintModel(
        id: complaintId,
        studentId: currentUser.studentId,
        title: title,
        description: description,
        attachmentUrls: [],
        status: ComplaintStatus.pending,
        createdAt: DateTime.now().toUtc(),
        replies: [],
      );

      // Create complaint record first to avoid orphaned files if the DB insert fails.
      await FirestoreService().createComplaint(complaint);

      List<String> attachmentUrls = [];
      bool attachmentUploadFailed = false;
      String? attachmentErrorMessage;

      if (_attachmentBytes.isNotEmpty) {
        for (int i = 0; i < _attachmentBytes.length; i++) {
          try {
            final url = await StorageService().uploadComplaintAttachment(
              complaintId: complaintId,
              fileBytes: _attachmentBytes[i],
              fileName: _attachmentNames[i],
            );
            attachmentUrls.add(url);
          } catch (e) {
            attachmentUploadFailed = true;
            attachmentErrorMessage = e.toString();
            debugPrint('Error uploading file ${_attachmentNames[i]}: $e');
            // Continue trying the remaining files, but keep the complaint record.
          }
        }

        if (attachmentUrls.isNotEmpty) {
          await FirestoreService().addAttachmentsToComplaint(
            complaintId,
            attachmentUrls,
          );
        }
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            attachmentUploadFailed
                ? 'Complaint submitted, but some attachments failed to upload. ${attachmentErrorMessage ?? ''}'
                : 'Complaint submitted successfully.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrint('Complaint submission failed: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      String errorMessage = 'Failed to submit complaint. Please try again.';

      final errorString = error.toString().toLowerCase();
      if (errorString.contains('row-level security') ||
          errorString.contains('permission denied') ||
          errorString.contains('42501') ||
          errorString.contains('policy')) {
        errorMessage =
            'Saving the complaint failed due to database permissions. Update your Supabase complaint table policy.';
      } else if (errorString.contains('network') ||
          errorString.contains('unavailable')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (errorString.contains('storage')) {
        errorMessage =
            'File upload failed. Please check your file and try again.';
      } else if (errorString.contains('failed to save complaint')) {
        errorMessage = 'Failed to save complaint. ${error.toString()}';
      }

      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Submit Complaint'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header card
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
                  'New Complaint',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please provide details about your issue',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Title card
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
                  'Complaint Title',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: AppTheme.formInputDecoration(
                    label: 'Enter a short title for your complaint',
                    icon: Icons.title,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Category card
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
                  'Category',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  items: complaintCategories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                  decoration: AppTheme.formInputDecoration(
                    label: 'Choose category',
                    icon: Icons.category_outlined,
                  ),
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
                  'Complaint Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 6,
                  decoration: AppTheme.formInputDecoration(
                    label: 'Describe your issue in detail',
                    icon: Icons.message_outlined,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Attachment card
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Material(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _pickAttachment,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Supporting Documents',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _attachmentNames.isEmpty
                                    ? Colors.grey[50]
                                    : AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _attachmentNames.isEmpty
                                      ? Colors.grey[200]!
                                      : AppTheme.primary.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _attachmentNames.isEmpty
                                        ? Icons.attach_file
                                        : Icons.insert_drive_file,
                                    color: _attachmentNames.isEmpty
                                        ? Colors.grey[400]
                                        : AppTheme.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _attachmentNames.isEmpty
                                              ? 'No files selected'
                                              : '${_attachmentNames.length} file(s) selected',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: _attachmentNames.isEmpty
                                                ? Colors.grey[600]
                                                : AppTheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _attachmentNames.isEmpty
                                              ? 'Tap to attach documents'
                                              : 'Tap to add more files',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.add_circle_outline,
                                    color: _attachmentNames.isEmpty
                                        ? Colors.grey[400]
                                        : AppTheme.primary,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_attachmentNames.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Text(
                              'Selected files:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _attachmentNames.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.picture_as_pdf,
                                        size: 16,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _attachmentNames[index],
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _removeAttachment(index),
                                        child: Icon(
                                          Icons.close,
                                          size: 18,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.primary, width: 2),
                ),
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
                elevation: 0,
              ),
              onPressed: _isSubmitting ? null : _submitComplaint,
              child: Text(
                _isSubmitting ? 'Submitting...' : 'Submit Complaint',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
