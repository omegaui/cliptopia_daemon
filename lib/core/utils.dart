import 'dart:io';

import 'package:cliptopia_daemon/core/logger.dart';
import 'package:uuid/uuid.dart';

final uuid = Uuid();

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

String _pgrep(pattern) {
  return Process.runSync('pgrep', ['-x', pattern]).stdout;
}

int _countPIDs(String output) {
  int count = 0;
  if (output.trim().isNotEmpty) {
    final ids = [];
    if (output.contains('\n')) {
      final lines = output.split('\n');
      for (final line in lines) {
        int? id = int.tryParse(line.trim());
        if (id != null) {
          ids.add(id);
        }
      }
    } else {
      int? id = int.tryParse(output.trim());
      if (id != null) {
        ids.add(id);
      }
    }
    count = ids.length;
  }
  return count;
}

bool isAnotherInstanceAlive() {
  final daemonProcess =
      Process.runSync('pgrep', ['-f', 'cliptopia-daemon']).stdout;
  return _countPIDs(daemonProcess) > 1;
}

bool isDaemonAlive() {
  final daemonProcess = _pgrep('cliptopia-daemon');
  final devProcess = _pgrep('dart:cliptopia_');
  final prodProcess = _pgrep('dart:cliptopia-');
  return daemonProcess.isNotEmpty ||
      devProcess.isNotEmpty ||
      prodProcess.isNotEmpty;
}

String getUniqueImagePath() {
  return combineHomePath(
      ['.config', 'cliptopia', 'cache', 'images', '${uuid.v1()}.png']);
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

void copy(data) {
  final temp = File('/tmp/.cliptopia-temp-text-data');
  temp.writeAsStringSync(data, flush: true);
  // copying using xclip
  Process.start(
    combineHomePath(['.config', 'cliptopia', 'scripts', 'cliptopia-copy.sh']),
    [],
  );
  prettyLog(value: "Copied to clipboard ... ");
}

bool doesPathExists(String path) {
  return File(path).existsSync() || Directory(path).existsSync();
}

extension StringURIUtils on String {
  bool isFileURI() {
    return doesPathExists(this);
  }

  bool isMultiFileURI() {
    if (!contains('\n')) {
      return false;
    }
    return doesPathExists(substring(0, indexOf('\n')));
  }

  List<String> getPaths() {
    List<String> paths = [];
    if (isMultiFileURI()) {
      List<String> px = split('\n');
      for (String p in px) {
        if (p.trim() != '') {
          if (doesPathExists(p)) {
            paths.add(p);
          }
        }
      }
    } else if (isFileURI()) {
      paths.add(this);
    }
    return paths;
  }
}

void restartSelf() {
  Process.runSync(
    '/usr/bin/cliptopia-daemon',
    ['--restart'],
    runInShell: true,
  );
}
