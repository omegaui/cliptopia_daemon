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

  static final cliptopiaCopyExecutorPath =
      combineHomePath(['.config', 'cliptopia', 'scripts', 'cliptopia-copy.sh']);

  static const _cliptopiaCopyExecutorSource = """
#!/bin/bash

if [ -z "\$1" ]; then
    echo "Usage: cliptopia-copy.sh <TARGET>"
    exit 1
fi

xclip -selection clipboard -t "\$1" < /tmp/.cliptopia-temp-text-data &> /dev/null
""";

  static void ensure() {
    final wlPasteScript = File(wlPasteExecutorPath);
    if (!wlPasteScript.existsSync()) {
      prettyLog(value: "Writing wl paste executor script ...");
      wlPasteScript.writeAsStringSync(_wlPasteExecutorSource, flush: true);
      Process.runSync(
        'chmod',
        ['+x', wlPasteExecutorPath],
      );
    }
    final copyScript = File(cliptopiaCopyExecutorPath);
    if (!copyScript.existsSync()) {
      prettyLog(value: "Writing Cliptopia copy executor script ...");
      copyScript.writeAsStringSync(_cliptopiaCopyExecutorSource, flush: true);
      Process.runSync(
        'chmod',
        ['+x', cliptopiaCopyExecutorPath],
      );
    }
  }
}
