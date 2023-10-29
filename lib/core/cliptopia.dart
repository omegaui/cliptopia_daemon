import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cliptopia_daemon/core/json_configurator.dart';
import 'package:cliptopia_daemon/core/logger.dart';
import 'package:cliptopia_daemon/core/utils.dart';

class ClipboardCache {
  static final configurator = ClipboardConfigurator();

  static dynamic _recentTextData;
  static Uint8List? _recentImageData;

  static void init() {
    final objects = configurator.get('cache');
    if (objects != null) {
      final mostRecent = objects.last;
      if (mostRecent['type'] == 'ClipboardEntityType.image') {
        _recentImageData = File(mostRecent['data']).readAsBytesSync();
      } else {
        _recentTextData = mostRecent['data'];
      }
    }
  }

  static void addText(dynamic data) {
    if (_recentTextData == data) {
      return;
    }
    _recentTextData = data;

    var type = ClipboardEntityType.text;

    String path = data.toString();
    if (path.startsWith('file://')) {
      path = path.substring(7);
    }

    if (FileSystemEntity.isDirectorySync(path) ||
        FileSystemEntity.isFileSync(path)) {
      if (configurator.containsPath(path)) {
        return;
      }
      type = ClipboardEntityType.path;
    } else if (path.contains('\n')) {
      List<String> lines = path.split('\n');
      List<String> paths = lines.where((line) {
        return FileSystemEntity.isDirectorySync(line) ||
            FileSystemEntity.isFileSync(line);
      }).toList();
      if (paths.length == lines.length) {
        for (final path in lines) {
          addText(path);
        }
        return;
      }
    }

    prettyLog(
        value:
            "Adding a New ${type == ClipboardEntityType.text ? "Text" : "Path"} Entry ...");

    configurator.add(
        'cache', ClipboardEntity(data, DateTime.now(), type).toMap());
  }

  static void addImage(ClipboardImageObject object) {
    if (_recentImageData != null) {
      if (listEquals(_recentImageData!, object.data)) {
        return;
      }
    }

    _recentImageData = object.data;

    File(object.path).writeAsBytesSync(object.data, flush: true);

    prettyLog(value: "Adding a New Image Entry ... ");

    configurator.add(
        'cache',
        ClipboardEntity(object.path, DateTime.now(), ClipboardEntityType.image)
            .toMap());
  }
}

class ClipboardManager {
  ClipboardManager.withStorage() {
    init();
  }

  void init() {
    mkdir(combineHomePath(['.config', 'cliptopia']),
        "Creating Cliptopia Storage Route ...");
    mkdir(combineHomePath(['.config', 'cliptopia', 'cache']),
        "Creating Cliptopia Cache Storage ...");
    mkdir(combineHomePath(['.config', 'cliptopia', 'cache', 'images']),
        "Creating Cliptopia Image Cache Storage ...");
    ClipboardCache.init();
  }

  void read() {
    _tryReadText();
    _tryReadImage();
  }

  void _tryReadText() {
    dynamic data = _tryExecuteXClip(target: Targets.text);
    if (data != null && data.trim().isNotEmpty) {
      ClipboardCache.addText(data);
    }
  }

  void _tryReadImage() {
    ClipboardImageObject? data = _tryExecuteXClip(target: Targets.image);
    if (data != null) {
      ClipboardCache.addImage(data);
    }
  }

  dynamic _tryExecuteXClip({required String target}) {
    try {
      dynamic path;
      if (target == Targets.image) {
        path = getUniqueImagePath();
      }
      final args = <String>[
        '-selection',
        'clipboard',
        '-t',
        target,
        '-o',
      ];

      final result = Process.runSync(
        'xclip',
        args,
        stdoutEncoding: null,
        stderrEncoding: null,
        runInShell: true,
        workingDirectory: Platform.environment['HOME']!,
      );

      if (result.exitCode == 0) {
        final data = result.stdout;
        if (path != null) {
          return ClipboardImageObject(data, path);
        }
        return utf8.decode(data);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}

class ClipboardConfigurator extends JsonConfigurator {
  ClipboardConfigurator()
      : super(
          configName: combinePath(
            [
              'cache',
              "clipboard.json",
            ],
          ),
        );

  bool containsPath(String path) {
    dynamic objects = get('cache');
    if (objects == null) {
      return false;
    }
    final now = DateTime.now();
    for (final entity in objects) {
      if (entity['data'] == path) {
        if (!DateTime.parse(entity['time']).isAtSameMomentAs(now)) {
          entity['time'] = now.toString();
        }
        return true;
      }
    }
    return false;
  }
}

class ClipboardEntity {
  dynamic data;
  DateTime time;
  ClipboardEntityType type;

  ClipboardEntity(this.data, this.time, this.type);

  Map<String, dynamic> toMap() {
    return {
      'data': data,
      'time': time.toString(),
      'type': type.toString(),
    };
  }
}

enum ClipboardEntityType { text, image, path }

class Targets {
  static const image = 'image/png';
  static const text = 'UTF8_STRING';
}

class ClipboardImageObject {
  Uint8List data;
  String path;

  ClipboardImageObject(this.data, this.path);
}
