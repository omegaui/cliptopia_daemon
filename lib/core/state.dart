import 'dart:convert';
import 'dart:io';

class State {
  State._();

  // static int _stateRestartTest = 0;

  static final _config = File('/tmp/.cliptopia-daemon-state');

  static void update() {
    _config.writeAsString(
        '{"last-activity-at": "${DateTime.now().toString()}"}',
        flush: true);
  }

  static void reset() {
    _config.deleteSync();
  }

  static bool isResponsive() {
    if (!_config.existsSync()) {
      return true;
    }
    // if (_stateRestartTest == 5) {
    //   return false;
    // }
    // _stateRestartTest++;
    String contents = _config.readAsStringSync();
    if (contents.trim().isNotEmpty) {
      final json = jsonDecode(contents);
      final time = DateTime.parse(json['last-activity-at']);
      final now = DateTime.now();
      final threeMinutes = Duration(minutes: 3);
      final threeMinBefore = now.subtract(threeMinutes);
      if (time.isAfter(threeMinBefore)) {
        return true;
      } else {
        stdout.writeln("This Daemon is no longer responsive ...");
        return false;
      }
    } else {
      return true;
    }
  }
}
