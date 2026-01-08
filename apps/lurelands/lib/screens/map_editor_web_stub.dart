/// Stub for non-web platforms
/// On web, this is replaced by map_editor_web.dart
void downloadJsonFile(String jsonContent, String filename) {
  // No-op on non-web platforms
  // The UI will show a dialog with copyable JSON instead
}

/// Pick and read a JSON file (stub for non-web)
Future<String?> pickJsonFile() async {
  // Not implemented on non-web platforms
  return null;
}

