// Conditional export based on platform
// On web (no dart:io), exports file_helper_stub.dart
// On native (has dart:io), exports file_helper_io.dart
export 'file_helper_stub.dart' if (dart.library.io) 'file_helper_io.dart';
