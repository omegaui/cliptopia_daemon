import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cliptopia_daemon/core/json_configurator.dart';
import 'package:cliptopia_daemon/core/logger.dart';
import 'package:cliptopia_daemon/core/utils.dart';
import 'package:cliptopia_daemon/daemon.dart';

final _now = DateTime.now();

class ClipboardCache {
  static final imageCacheDir = Directory(combineHomePath([
    '.config',
    'cliptopia',
    'cache',
    'images',
  ]));

  static final configurator = ClipboardConfigurator();

  static final exclusionConfig =
      JsonConfigurator(configName: 'exclusion-config.json');

  static dynamic _lastPathData;

  static bool isAddable(data) {
    dynamic exclusions = exclusionConfig.get('exclusions');
    if (exclusions != null && exclusions.isNotEmpty) {
      for (final exclusion in exclusions) {
        if (exclusion['pattern'].allMatches(data).isNotEmpty) {
          return false;
        }
      }
    }

    dynamic objects = configurator.get('cache');
    if (objects != null && objects.isNotEmpty) {
      dynamic texts = objects
          .where((e) => e['type'] != 'ClipboardEntityType.image')
          .toList();
      for (final textObject in texts) {
        final textData = textObject['data'];
        if (textData == data) {
          final currentTime = DateTime.parse(textObject['time']);
          if (!currentTime.isAtSameMomentAs(_now)) {
            textObject['time'] = _now.toString();
            configurator.save();
          }
          return false;
        }
      }
    }
    return true;
  }

  static void addText(dynamic data, {recursive = false}) {
    if (!isAddable(data)) {
      return;
    }

    var type = ClipboardEntityType.text;

    String path = data.toString();
    if (path.startsWith('file://')) {
      path = path.substring(7);
    }

    if (FileSystemEntity.isDirectorySync(path) ||
        FileSystemEntity.isFileSync(path)) {
      type = ClipboardEntityType.path;
      if (!recursive) {
        if (_lastPathData == path) {
          return;
        }
        _lastPathData = path;
      }
    } else if (path.contains('\n')) {
      List<String> lines = path.split('\n');
      List<String> paths = lines.where((line) {
        return FileSystemEntity.isDirectorySync(line) ||
            FileSystemEntity.isFileSync(line);
      }).toList();
      if (_lastPathData == path) {
        return;
      }
      if (paths.length == lines.length) {
        _lastPathData = path;
        for (final path in lines) {
          addText(path, recursive: true);
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

  static bool findImageInCache(ClipboardImageObject object) {
    dynamic objects = configurator.get('cache');
    if (objects != null && objects.isNotEmpty) {
      dynamic images = objects
          .where((e) => e['type'] == 'ClipboardEntityType.image')
          .toList();
      if (images.isNotEmpty) {
        for (final imageObject in images) {
          final path = imageObject['data'];
          final imageFile = File(path);
          if (imageFile.existsSync()) {
            final imageData = imageFile.readAsBytesSync();
            if (listEquals(imageData, object.data)) {
              final currentTime = DateTime.parse(imageObject['time']);
              if (!currentTime.isAtSameMomentAs(_now)) {
                imageObject['time'] = _now.toString();
                configurator.save();
              }
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  static void addImage(ClipboardImageObject object) {
    if (findImageInCache(object)) {
      return;
    }

    File(object.path).writeAsBytesSync(object.data, flush: true);

    prettyLog(value: "Adding a New Image Entry ... ");

    configurator.add(
        'cache',
        ClipboardEntity(object.path, DateTime.now(), ClipboardEntityType.image)
            .toMap());
  }

  static void optimizeCache() {
    if (DaemonConfig.shouldLimitCache()) {
      int size = DaemonConfig.getCacheSize();
      String unit = DaemonConfig.getCacheSizeUnit();
      int base = _getBase(unit);
      int limitInBytes = size * base;
      int currentSize = _getCacheDirSizeInBytes();
      prettyLog(value: "Cache Size: ${currentSize / base} $unit");
      if (currentSize > limitInBytes) {
        prettyLog(
          value:
              "Cache has exceeded the limit of $size $unit !!!\nDaemon will now try to delete old entries ...",
          type: DebugType.warning,
        );
        clearCache(currentSize - limitInBytes);
      }
    }
  }

  static void displayCacheSize() {
    String unit = "MB";
    int base = _getBase(unit);
    int currentSize = _getCacheDirSizeInBytes();
    stdout.writeln("Cache Size: ${currentSize / base} $unit");
  }

  static void clearCache(final int exceededSize) {
    int deletedCacheSize = 0;
    int index = 0;
    dynamic objects = configurator.get('cache');
    while (deletedCacheSize <= exceededSize && index < objects.length) {
      dynamic object = objects[index++];
      int objectSize = utf8.encode(jsonEncode(object)).length;
      int extra = 0;
      if (object['type'] == 'ClipboardEntityType.image') {
        dynamic path = object['data'];
        File imageFile = File(path);
        if (imageFile.existsSync()) {
          extra = imageFile.statSync().size;
          imageFile.deleteSync();
          prettyLog(value: ">> Deleting Cached Image ...");
        }
      }
      deletedCacheSize += (objectSize - extra);
      configurator.remove('cache', object);
    }
    prettyLog(value: "Cleared $exceededSize bytes of storage ...");
  }

  static int _getBase(String unit) {
    int base = 1000;
    switch (unit) {
      case "MB":
        base = 1000000;
        break;
      case "GB":
        base = 1000000000;
    }
    return base;
  }

  static int _getCacheDirSizeInBytes() {
    var files = Daemon.cacheDir.listSync(recursive: true).toList();
    var dirSize = files.fold(0, (int sum, file) => sum + file.statSync().size);
    return dirSize;
  }
}

class DaemonConfig extends JsonConfigurator {
  DaemonConfig._() : super(configName: "daemon-config.json");

  static late DaemonConfig _config;

  static DaemonConfig get configuration => _config;

  static void init() {
    _config = DaemonConfig._();
  }

  static bool shouldLimitCache() {
    _config.reload();
    return _config.get('limit-cache') ?? false;
  }

  static bool shouldKeepHistory() {
    return _config.get('keep-history') ?? true;
  }

  static int getCacheSize() {
    return _config.get('cache-size') ?? "10";
  }

  static String getCacheSizeUnit() {
    return _config.get('unit') ?? "KB";
  }
}

class ClipboardManager {
  ClipboardManager.withStorage() {
    initStorage();
  }

  static void initStorage() {
    mkdir(combineHomePath(['.config', 'cliptopia']),
        "Creating Cliptopia Storage Route ...");
    mkdir(combineHomePath(['.config', 'cliptopia', 'cache']),
        "Creating Cliptopia Cache Storage ...");
    mkdir(combineHomePath(['.config', 'cliptopia', 'cache', 'images']),
        "Creating Cliptopia Image Cache Storage ...");
    DaemonConfig.init();
  }

  void read() {
    _tryReadText();
    _tryReadImage();
    // removes corrupted or objects marked for removal
    // by Cliptopia's Clipboard Manager
    ClipboardCache.configurator.optimize();
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

  String findMostRecentTextEntry() {
    final objects = ClipboardCache.configurator.get('cache');
    if (objects != null && objects.isNotEmpty) {
      final texts =
          objects.where((e) => e['type'] == 'ClipboardEntityType.text');
      if (texts.isNotEmpty) {
        return texts.first['data'];
      }
    }
    return "";
  }
}

class ClipboardConfigurator extends JsonConfigurator {
  final removablesStorage = JsonConfigurator(
    configName: combinePath(
      [
        'cache',
        'user-removables.json',
      ],
    ),
  );

  ClipboardConfigurator()
      : super(
          configName: combinePath(
            [
              'cache',
              "clipboard.json",
            ],
          ),
        );

  void optimize() {
    dynamic objects = get('cache');

    removablesStorage.reload();

    dynamic removableObjects = removablesStorage.get('removables') ?? [];

    if (objects != null) {
      dynamic removables = [];
      for (final object in objects) {
        if (object['type'] != 'ClipboardEntityType.text') {
          if (!File(object['data']).existsSync()) {
            removables.add(object);
          }
        }
        if (removableObjects.contains(object['id'])) {
          prettyLog(value: "Marking Entity for Removal :${object['id']}");
          removables.add(object);
        }
      }
      for (final object in removables) {
        remove('cache', object);
        removablesStorage.remove('cache', object['id']);
      }
    }
  }

  @override
  void add(key, value) {
    super.add(key, value);
    ClipboardCache.optimizeCache();
  }
}

class ClipboardEntity {
  dynamic data;
  DateTime time;
  ClipboardEntityType type;
  final String id;

  ClipboardEntity(this.data, this.time, this.type) : id = uuid.v1();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
