import 'dart:io';

import 'package:cliptopia_daemon/constants/meta_info.dart';
import 'package:cliptopia_daemon/core/cliptopia.dart';
import 'package:cliptopia_daemon/core/lock.dart';
import 'package:cliptopia_daemon/core/logger.dart';
import 'package:cliptopia_daemon/core/utils.dart';

class Daemon {
  static final cacheDir = Directory(combineHomePath([
    '.config',
    'cliptopia',
    'cache',
  ]));

  late final ClipboardManager manager;

  void startDaemon({restart = false}) {
    if (!restart && isAnotherInstanceAlive()) {
      stdout.writeln('Another Instance of Daemon is already alive!');
      stdout.writeln('Please run the following to stop it');
      stdout.writeln('> cliptopia-daemon --stop');
      stdout.writeln(
          'Or you can restart the daemon by running the following command');
      stdout.writeln('> cliptopia-daemon --restart');
      return;
    }
    if (!restart && Lock.isLocked()) {
      prettyLog(value: 'Lock file already exists ...');
      restartDaemon();
      return;
    }
    prettyLog(value: 'Applying Runtime lock ...');
    Lock.apply();
    manager = ClipboardManager.withStorage();
    if (!DaemonConfig.shouldKeepHistory()) {
      prettyLog(
          value: "\"HISTORY WILL NOT BE AVAILABLE AFTER A RESTART\"",
          type: DebugType.warning);
      // Checking if cliptopia-startup-lock-exists
      // if the lock exists, this means the history of this session
      // has already been cleared else we reset the cache and create the lock
      if (!StartupLock.isLocked()) {
        resetCache(stop: false);
        ClipboardManager.initStorage();
        StartupLock.apply();
      }
    } else if (!StateLock.isLocked()) {
      copy(manager.findMostRecentTextEntry());
      StateLock.apply();
    }
    _launch();
  }

  void _launch() async {
    prettyLog(value: 'Daemon Started ...');
    while (Lock.isLocked()) {
      if (IncognitoLock.isLocked()) {
        continue;
      }
      await Future.delayed(Duration(seconds: 1));
      manager.read();
    }
    prettyLog(value: 'Daemon Stopped!');
  }

  Future<void> stopDaemon({silent = false}) async {
    if (!Lock.isLocked() && !silent) {
      status();
      return;
    }
    prettyLog(value: 'Removing Lock File ...');
    Lock.remove();
    await Future.delayed(Duration(milliseconds: 500));
    if (!silent) {
      status();
    }
  }

  void status() {
    if (Lock.isLocked()) {
      stdout.writeln('Daemon Status: Alive');
    } else {
      stdout.writeln('Daemon Status: Stopped');
    }
  }

  void restartDaemon() async {
    stopDaemon(silent: true);
    stdout.writeln('Waiting for Previous Daemon to exit ...');
    await Future.delayed(Duration(seconds: 2));
    startDaemon(restart: true);
  }

  void incognito(bool enabled) {
    if (enabled) {
      IncognitoLock.apply();
    } else {
      IncognitoLock.remove();
    }
  }

  void resetCache({stop = true}) async {
    if (cacheDir.existsSync()) {
      if (stop) {
        await stopDaemon();
      }
      cacheDir.deleteSync(recursive: true);
      stdout.writeln("Cache Cleared!");
      stdout.writeln(
          "Cache Location: ${Platform.environment['HOME']}/.config/cliptopia/cache");
      stdout.writeln();
      stdout.writeln("Please Note that cache should not be cleared manually,");
      stdout.writeln(
          "The Daemon is itself capable of clearing cache automatically");
      stdout.writeln(
          "Use Cliptopia's Clipboard Manager to set the cache limit in KB, MB or GB as you want.");
    } else {
      stdout.writeln("Nothing in cache to clear.");
    }
  }

  void cacheSize() {
    ClipboardCache.displayCacheSize();
  }

  void version() async {
    stdout.writeln("Cliptopia Daemon version ${MetaInfo.version}");
  }
}
