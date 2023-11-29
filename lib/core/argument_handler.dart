class ArgumentHandler {
  ArgumentHandler._();

  static const _args = [
    '--start',
    '--stop',
    '--status',
    '--restart',
    '--enable-incognito-mode',
    '--disable-incognito-mode',
    '--debug',
    '--reset-cache',
    '--cache-size',
    '--version',
    '--help',
  ];

  static late List<String> _arguments;

  static void init(List<String> arguments) {
    _arguments = arguments;
  }

  static bool shouldRestart() {
    return _arguments.contains('--restart');
  }

  static bool shouldStop() {
    return _arguments.contains('--stop');
  }

  static bool shouldStart() {
    return _arguments.contains('--start');
  }

  static bool shouldShowStatus() {
    return _arguments.contains('--status');
  }

  static bool shouldShowHelp() {
    return _arguments.contains('--help');
  }

  static bool shouldResetCache() {
    return _arguments.contains('--reset-cache');
  }

  static bool shouldShowCacheSize() {
    return _arguments.contains('--cache-size');
  }

  static bool shouldEnableIncognitoMode() {
    return _arguments.contains('--enable-incognito-mode');
  }

  static bool shouldDisableIncognitoMode() {
    return _arguments.contains('--disable-incognito-mode');
  }

  static bool shouldShowVersion() {
    return _arguments.contains('--version');
  }

  static bool isDebugMode() {
    return _arguments.contains('--debug');
  }

  static bool validate() {
    for (final arg in _arguments) {
      if (!_args.contains(arg)) {
        return false;
      }
    }
    return _arguments.isNotEmpty;
  }

  static Iterable<String> getUnknownOptions() sync* {
    for (final arg in _arguments) {
      if (!_args.contains(arg)) {
        yield arg;
      }
    }
  }
}
