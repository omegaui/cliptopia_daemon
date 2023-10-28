
import 'dart:io';

import 'package:cliptopia_daemon/constants/meta_info.dart';
import 'package:cliptopia_daemon/core/argument_handler.dart';
import 'package:cliptopia_daemon/core/cliptopia.dart';
import 'package:cliptopia_daemon/core/lock.dart';
import 'package:cliptopia_daemon/core/logger.dart';
import 'package:cliptopia_daemon/core/utils.dart';

class Daemon {
  static final _cacheDir = Directory(combineHomePath(['.config', 'cliptopia', 'cache']));
  
  late final ClipboardManager manager;

  void startDaemon() {
    if(Lock.isLocked()){
      prettyLog(value: 'Daemon is already alive ...');
      if(ArgumentHandler.isDebugMode()) {
        restartDaemon();
      }
      return;
    }
    Lock.apply();
    _launch();
  }

  void _launch() async {
    prettyLog(value: 'Daemon Started ...');
    manager = ClipboardManager.withStorage();
    while(Lock.isLocked()) {
      await Future.delayed(Duration(seconds: 1));
      manager.read();
    }
    prettyLog(value: 'Daemon Stopped!');
  }

  Future<void> stopDaemon() async {
    if(!Lock.isLocked()){
      status();
      return;
    }
    prettyLog(value: 'Removing Lock File ...');
    Lock.remove();
    await Future.delayed(Duration(milliseconds: 500));
    status();
  }

  void status() {
    if(Lock.isLocked()) {
      stdout.writeln('Daemon Status: Alive');
    } else {
      stdout.writeln('Daemon Status: Stopped');
    }
  }

  void restartDaemon() {
    stopDaemon();
    startDaemon();
  }

  void resetCache() async {
    if(_cacheDir.existsSync()) {
      await stopDaemon();
      _cacheDir.deleteSync(recursive: true);
      stdout.writeln("Cache Cleared!");
      stdout.writeln("Cache Location: ${Platform.environment['HOME']}/.config/cliptopia/cache");
      stdout.writeln();
      stdout.writeln("Please Note that cache should not be cleared manually, it should only be cleared when you think it has taken a considerable amount of space on your system.");
      stdout.writeln("Scheduling Cache Deletion from Cliptopia's Clipboard Manager is the recommended way.");
      stdout.writeln("You can specify duration in days or months.");
    } else {
      stdout.writeln("Nothing in cache to clear.");
    }
  }

  void version() async {
    stdout.writeln("Cliptopia Daemon version ${MetaInfo.version}");
  }

}
