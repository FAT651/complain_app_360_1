import 'dart:typed_data';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../config/supabase_config.dart';

class StorageService {
  static const int MAX_FILE_SIZE_MB = 4;
  static const int MAX_FILE_SIZE_BYTES = MAX_FILE_SIZE_MB * 1024 * 1024;

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> uploadComplaintAttachment({
    required String complaintId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    // Validate file size
    if (fileBytes.length > MAX_FILE_SIZE_BYTES) {
      throw Exception('File size exceeds ${MAX_FILE_SIZE_MB}MB limit');
    }

    // Validate file name
    if (fileName.isEmpty || fileName.contains('..')) {
      throw Exception('Invalid file name');
    }

    try {
      // Create a unique file path in Supabase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = 'complaints/$complaintId/${timestamp}_$fileName';

      print('Uploading file to path: $filePath');
      print('File size: ${fileBytes.length} bytes');
      print('Storage bucket: ${SupabaseConfig.storageBucket}');

      // Upload file to Supabase Storage
      await _supabase.storage
          .from(SupabaseConfig.storageBucket)
          .uploadBinary(
            filePath,
            fileBytes,
            fileOptions: FileOptions(cacheControl: '3600', upsert: false),
          );

      // Get the public URL after successful upload
      final url = _supabase.storage
          .from(SupabaseConfig.storageBucket)
          .getPublicUrl(filePath);

      print('File uploaded successfully: $url');
      return url;
    } catch (e) {
      print('Upload error: $e');
      throw Exception('Failed to upload file to Supabase: $e');
    }
  }

  Future<String?> getComplaintAttachmentUrl(String filePath) async {
    try {
      // Get the public URL of the uploaded file
      final url = _supabase.storage
          .from(SupabaseConfig.storageBucket)
          .getPublicUrl(filePath);
      return url;
    } catch (e) {
      print('Error getting file URL: $e');
      return null;
    }
  }

  Future<File?> getComplaintAttachment(String filePath) async {
    try {
      // Download file from Supabase Storage
      final data = await _supabase.storage
          .from(SupabaseConfig.storageBucket)
          .download(filePath);

      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(path.join(tempDir.path, path.basename(filePath)));
      await tempFile.writeAsBytes(data);

      return tempFile;
    } catch (e) {
      print('Error downloading file from Supabase: $e');
      return null;
    }
  }

  Future<void> deleteComplaintAttachment(String filePath) async {
    try {
      await _supabase.storage.from(SupabaseConfig.storageBucket).remove([
        filePath,
      ]);
    } catch (e) {
      print('Error deleting file from Supabase: $e');
    }
  }

  Future<void> deleteComplaintAttachments(String complaintId) async {
    try {
      // List all files for this complaint
      final files = await _supabase.storage
          .from(SupabaseConfig.storageBucket)
          .list(path: 'complaints/$complaintId');

      // Delete all files
      if (files.isNotEmpty) {
        final filePaths = files
            .map((file) => 'complaints/$complaintId/${file.name}')
            .toList();
        await _supabase.storage
            .from(SupabaseConfig.storageBucket)
            .remove(filePaths);
      }
    } catch (e) {
      print('Error deleting complaint attachments: $e');
    }
  }
}
