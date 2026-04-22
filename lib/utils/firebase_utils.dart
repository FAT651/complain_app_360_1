import 'dart:io';

/// Utility class to check if Firebase is available on the current platform
class FirebaseUtils {
  /// Returns true if Firebase is supported on the current platform
  static bool isFirebaseSupported() {
    return !Platform.isLinux;
  }

  /// Call this before using any Firebase functionality
  static void ensureFirebaseAvailable() {
    if (!isFirebaseSupported()) {
      throw UnsupportedError('Firebase is not supported on Linux');
    }
  }
}
