
import 'dart:io';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';
import 'package:cliptopia_daemon/core/logger.dart';

final _uuid = Uuid();

String combinePath(List<String> locations, {bool absolute = false}) {
  String path = locations.join(Platform.pathSeparator);
  return absolute ? File(path).absolute.path : path;
}

String combineHomePath(List<String> locations, {bool absolute = false}) {
  locations.insert(0, Platform.environment['HOME']!);
  return combinePath(locations, absolute: absolute);
}

void mkdir(String path, String logMessage) {
  var dir = Directory(path);
  if (!dir.existsSync()) {
    dir.createSync();
    prettyLog(value: logMessage);
  }
}

bool containsIgnoreCase(String mainString, String subString) {
  final mainLower = mainString.toLowerCase();
  final subLower = subString.toLowerCase();
  return mainLower.contains(subLower);
}

String _pgrep(pattern){
  return Process.runSync('pgrep', ['-x', pattern]).stdout;
}

bool isDaemonAlive() {
  final daemonProcess = _pgrep('cliptopia-daemon');
  final devProcess = _pgrep('dart:cliptopia_');
  final prodProcess = _pgrep('dart:cliptopia-');
  return daemonProcess.isNotEmpty || devProcess.isNotEmpty || prodProcess.isNotEmpty;
}

String getUniqueImagePath() {
  return combineHomePath(['.config', 'cliptopia', 'cache', 'images', '${_uuid.v1()}.png']);
}
/// Naive [List] equality implementation.
bool listEquals<E>(List<E> list1, List<E> list2) {
  if (identical(list1, list2)) {
    return true;
  }

  if (list1.length != list2.length) {
    return false;
  }

  for (var i = 0; i < list1.length; i += 1) {
    if (list1[i] != list2[i]) {
      return false;
    }
  }

  return true;
}

/// Compares two [Uint8List]s by comparing 8 bytes at a time.
bool memEquals(Uint8List bytes1, Uint8List bytes2) {
  if (identical(bytes1, bytes2)) {
    return true;
  }

  if (bytes1.lengthInBytes != bytes2.lengthInBytes) {
    return false;
  }

  // Treat the original byte lists as lists of 8-byte words.
  var numWords = bytes1.lengthInBytes ~/ 8;
  var words1 = bytes1.buffer.asUint64List(0, numWords);
  var words2 = bytes2.buffer.asUint64List(0, numWords);

  for (var i = 0; i < words1.length; i += 1) {
    if (words1[i] != words2[i]) {
      return false;
    }
  }

  // Compare any remaining bytes.
  for (var i = words1.lengthInBytes; i < bytes1.lengthInBytes; i += 1) {
    if (bytes1[i] != bytes2[i]) {
      return false;
    }
  }

  return true;
}