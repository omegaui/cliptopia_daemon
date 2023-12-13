import 'dart:io';

import 'package:cliptopia_daemon/core/logger.dart';
import 'package:cliptopia_daemon/core/utils.dart';

class ShellScripts {
  ShellScripts._();

  static final wlPasteExecutorPath = combineHomePath(
      ['.config', 'cliptopia', 'scripts', 'wl-paste-executor.sh']);

  static const _wlPasteExecutorSource = """
#!/bin/bash
# this is a utility to run wl-paste from dart code
wl-paste --type \$1 > \$2
""";

  static void ensure() {
    final script = File(wlPasteExecutorPath);
    if (!script.existsSync()) {
      prettyLog(value: "Writing wl paste executor script ...");
      script.writeAsStringSync(_wlPasteExecutorSource, flush: true);
      Process.runSync(
        'chmod',
        ['+x', wlPasteExecutorPath],
      );
    }
  }
}
