// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';

/// Download a JSON string as a file in web browsers
void downloadJsonFile(String jsonContent, String filename) {
  final bytes = jsonContent.codeUnits;
  final blob = html.Blob([bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  
  final anchor = html.AnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  
  html.Url.revokeObjectUrl(url);
}

/// Pick and read a JSON file from the user's filesystem (web)
Future<String?> pickJsonFile() async {
  final completer = Completer<String?>();
  
  final input = html.FileUploadInputElement()
    ..accept = '.json,application/json'
    ..style.display = 'none';
  
  input.onChange.listen((event) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    
    final file = files.first;
    final reader = html.FileReader();
    
    reader.onLoadEnd.listen((event) {
      final result = reader.result as String?;
      completer.complete(result);
    });
    
    reader.onError.listen((event) {
      completer.complete(null);
    });
    
    reader.readAsText(file);
  });
  
  // Handle cancel (user closes dialog without selecting)
  input.onAbort.listen((_) {
    completer.complete(null);
  });
  
  html.document.body?.append(input);
  input.click();
  
  // Clean up after a delay
  Future.delayed(const Duration(seconds: 30), () {
    input.remove();
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  });
  
  return completer.future;
}

