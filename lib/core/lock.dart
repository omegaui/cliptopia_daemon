import 'dart:io';

import 'package:cliptopia_daemon/core/utils.dart';

class Lock {
  Lock._();

  static File lockFile =
      File(combinePath([Directory.systemTemp.path, '.cliptopia-daemon-lock']));

  static void apply() {
    if (!isLocked()) {
      lockFile.createSync();
    }
  }

  static void remove() {
    if (isLocked()) {
      lockFile.deleteSync();
    }
  }

  static bool isLocked() {
    return lockFile.existsSync();
  }
}

class StartupLock {
  StartupLock._();

  static File lockFile =
      File(combinePath([Directory.systemTemp.path, '.cliptopia-startup-lock']));

  static void apply() {
    if (!isLocked()) {
      lockFile.createSync();
    }
  }

  static bool isLocked() {
    return lockFile.existsSync();
  }
}

class StateLock {
  StateLock._();

  static File lockFile =
      File(combinePath([Directory.systemTemp.path, '.cliptopia-state-lock']));

  static void apply() {
    if (!isLocked()) {
      lockFile.createSync();
    }
  }

  static bool isLocked() {
    return lockFile.existsSync();
  }
}

class IncognitoLock {
  IncognitoLock._();

  static File lockFile =
      File(combineHomePath(['.config', 'cliptopia', '.incognito-mode']));

  static void apply() {
    if (!isLocked()) {
      lockFile.createSync();
    }
  }

  static void remove() {
    if (isLocked()) {
      lockFile.deleteSync();
    }
  }

  static bool isLocked() {
    return lockFile.existsSync();
  }
}
