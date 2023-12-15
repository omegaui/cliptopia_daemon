import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cliptopia_daemon/core/json_configurator.dart';
import 'package:cliptopia_daemon/core/logger.dart';
import 'package:cliptopia_daemon/core/shell_scripts.dart';
import 'package:cliptopia_daemon/core/utils.dart';

DateTime get _now => DateTime.now();

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

  static bool findTextInCache(data) {
    dynamic exclusions = exclusionConfig.get('exclusions');
    if (exclusions != null && exclusions.isNotEmpty) {
      for (final exclusion in exclusions) {
        try {
          if (exclusion['pattern'].allMatches(data).isNotEmpty) {
            return true; // #ContentProtection
          }
        } catch (e) {
          prettyLog(
              value: "Error checking ${exclusion['name']} against $data",
              type: DebugType.error);
          rethrow;
        }
      }
    }
    return updateRef(data);
  }

  static bool updateRef(data) {
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
          return true;
        }
      }
    }
    return false;
  }

  static void addText(dynamic data, {bool isPath = false}) {
    if (findTextInCache(data)) {
      return;
    }

    var type = isPath ? ClipboardEntityType.path : ClipboardEntityType.text;

    // Checking if data is a list of URIs
    final paths = data.toString().getPaths();
    if (!isPath && _lastPathData != data) {
      if (paths.isNotEmpty) {
        for (final path in paths) {
          addText(path, isPath: true);
        }
        _lastPathData = data;
        return;
      }
    }

    if (_lastPathData == data) {
      for (final path in paths) {
        updateRef(path);
      }
      return;
    }

    prettyLog(
        value:
            "Adding a New ${type == ClipboardEntityType.text ? "Text" : "Path"} Entry ...");

    int sizeInBytes = utf8.encode(data).length;

    configurator.add('cache',
        ClipboardEntity(data, DateTime.now(), type, sizeInBytes).toMap());
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
        ClipboardEntity(object.path, DateTime.now(), ClipboardEntityType.image,
                File(object.path).statSync().size)
            .toMap());
  }

  static void optimizeCache() {
    if (DaemonConfig.shouldLimitCache()) {
      int size = DaemonConfig.getCacheSize();
      String unit = DaemonConfig.getCacheSizeUnit();
      int base = _getBase(unit);
      int limitInBytes = size * base;
      int currentSize = _getTotalStoredCacheSize();
      prettyLog(value: "Cache Size: ${currentSize / base} $unit");
      prettyLog(
          value:
              "Cache Length: ${(configurator.get('cache') ?? []).length} Items");
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
    int currentSize = _getTotalStoredCacheSize();
    String? unit;
    if (currentSize <= 999999) {
      unit = "KB";
    } else if (currentSize <= 99999999) {
      unit = "MB";
    } else {
      unit = "KB";
    }
    int base = _getBase(unit);
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
      deletedCacheSize += (objectSize + extra);
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

  static int _getTotalStoredCacheSize() {
    int size = 0;
    final objects = configurator.get('cache');
    for (final entity in objects) {
      size += int.parse(entity['size'].toString());
    }
    return size;
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

  static bool shouldForceXClip() {
    _config.reload();
    return _config.get('force-xclip') ?? false;
  }
}

class ClipboardManager {
  final pasteBin = combineHomePath(
      ['.config', 'cliptopia', 'cache', '.paste-bin-for-wayland']);

  bool waylandSession = false;
  bool wasWaylandSession = false;

  ClipboardManager.withStorage() {
    initStorage();
    _identifySession();
  }

  void _identifySession() {
    final output = Platform.environment['WAYLAND_DISPLAY'];
    if (output != null && output.contains('wayland')) {
      waylandSession = true;
    }
    if (waylandSession) {
      wasWaylandSession = true;
      prettyLog(value: "Running in a wayland session ...");
    } else {
      prettyLog(value: "This is not a wayland session ...");
    }
  }

  static void initStorage() {
    mkdir(combineHomePath(['.config', 'cliptopia']),
        "Creating Cliptopia Storage Route ...");
    mkdir(combineHomePath(['.config', 'cliptopia', 'scripts']),
        "Creating Cliptopia Scripts Storage ...");
    mkdir(combineHomePath(['.config', 'cliptopia', 'cache']),
        "Creating Cliptopia Cache Storage ...");
    mkdir(combineHomePath(['.config', 'cliptopia', 'cache', 'images']),
        "Creating Cliptopia Image Cache Storage ...");
    DaemonConfig.init();
  }

  void read() {
    // check if the user has forced X11 mode
    watchSessionSwitch();
    // Read clipboard ...
    _tryReadText();
    _tryReadImage();
    // removes corrupted or objects marked for removal
    // by Cliptopia's Clipboard Manager
    ClipboardCache.configurator.optimize();
  }

  void _tryReadText() {
    dynamic data = waylandSession
        ? _tryExecuteWLPaste(target: Targets.text)
        : _tryExecuteXClip(target: Targets.text);
    if (data != null && data.trim().isNotEmpty) {
      ClipboardCache.addText(data);
    }
  }

  void _tryReadImage() {
    ClipboardImageObject? data = waylandSession
        ? _tryExecuteWLPaste(target: Targets.image)
        : _tryExecuteXClip(target: Targets.image);
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

  dynamic _tryExecuteWLPaste({required String target}) {
    final typeIdentificationProcess = Process.runSync(
      'wl-paste',
      ['--list-types'],
      runInShell: true,
    );
    var stdout = typeIdentificationProcess.stdout.toString();
    stdout = stdout.split('\n').join();
    if (stdout.isEmpty) {
      return null;
    } else {
      String? availableTarget;
      if (stdout.contains(Targets.text)) {
        // either its a path or text
        // no matter what it is, Cliptopia will automatically handle
        availableTarget = Targets.text;
      } else if (stdout.contains(Targets.image)) {
        // this means the currently available target an image
        availableTarget = Targets.image;
      } else {
        // We don't support other types right now
        return null;
      }

      if (availableTarget == target) {
        // reading and getting data
        String wlPasteType =
            target == Targets.text ? 'text/plain' : 'image/png';
        final writeProcess = Process.runSync(
          ShellScripts.wlPasteExecutorPath,
          [wlPasteType, pasteBin],
          runInShell: true,
        );
        if (writeProcess.exitCode == 0) {
          dynamic path;
          if (target == Targets.image) {
            path = getUniqueImagePath();
          }
          final data = File(pasteBin).readAsBytesSync();
          if (path != null) {
            return ClipboardImageObject(data, path);
          }
          return utf8.decode(data);
        } else {
          // it failed somehow ...
          // may be logs can tell why?
          return null;
        }
      } else {
        // requested target is not currently available
        return null;
      }
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

  void watchSessionSwitch() {
    if (DaemonConfig.shouldForceXClip()) {
      if (waylandSession) {
        waylandSession = false;
        prettyLog(
          value: "Using xclip in a wayland session ...",
          type: DebugType.warning,
        );
      }
    } else if (wasWaylandSession && !waylandSession) {
      waylandSession = true;
      prettyLog(
        value: "Switching back to wayland session ...",
      );
    }
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

  final commentsStorage = JsonConfigurator(
    configName: combinePath(
      [
        'cache',
        'entity-infos.json',
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
    commentsStorage.reload();

    dynamic removableObjects = removablesStorage.get('removables') ?? [];
    dynamic comments = commentsStorage.get('infos') ?? [];

    if (objects != null) {
      dynamic removables = [];
      for (final object in objects) {
        // image no longer exists
        if (object['type'] == 'ClipboardEntityType.image') {
          if (!File(object['data']).existsSync()) {
            removables.add(object);
          }
        }
        // file/folder no longer exists
        if (object['type'] == 'ClipboardEntityType.path') {
          if (FileSystemEntity.isFileSync(object['data'])) {
            if (!File(object['data']).existsSync()) {
              removables.add(object);
            }
          } else if (FileSystemEntity.isDirectorySync(object['data'])) {
            if (!Directory(object['data']).existsSync()) {
              removables.add(object);
            }
          }
        }
        // deletion requested by user
        if (removableObjects.contains(object['id'])) {
          prettyLog(value: "Marking Entity for Removal :${object['id']}");
          removables.add(object);
        }
      }
      for (final object in removables) {
        remove('cache', object);
        removablesStorage.remove('removables', object['id']);
        if (object['type'] == 'ClipboardEntityType.image') {
          File imageFile = File(object['data']);
          if (imageFile.existsSync()) {
            imageFile.deleteSync();
          }
        }

        // Removing any corresponding comment on object
        List<dynamic> removableComments = [];
        for (final comment in comments) {
          if (comment['refID'] == object['id']) {
            removableComments.add(comment);
            // an object can have only one comment object
            // a comment object can hold more than one comment
            // using line separator
            break;
          }
        }
        for (final removableComment in removableComments) {
          commentsStorage.remove('comments', removableComment);
        }
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
  final int size;

  ClipboardEntity(this.data, this.time, this.type, this.size) : id = uuid.v1();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'data': data,
      'time': time.toString(),
      'type': type.toString(),
      'size': size,
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
