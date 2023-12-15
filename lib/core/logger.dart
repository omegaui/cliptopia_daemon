import 'dart:io';

import 'package:cliptopia_daemon/core/argument_handler.dart';

enum DebugType { error, info, warning, url, response, statusCode }

prettyLog({
  String? tag,
  required dynamic value,
  DebugType type = DebugType.info,
}) {
  if (!ArgumentHandler.isDebugMode()) {
    return;
  }
  switch (type) {
    case DebugType.statusCode:
      stdout.writeln(
          '\x1B[33m${"💎 STATUS CODE ${tag != null ? "$tag: " : ""}$value"}\x1B[0m');
      break;
    case DebugType.info:
      stdout.writeln("⚡ ${tag != null ? "$tag: " : ""}$value");
      break;
    case DebugType.warning:
      stdout.writeln(
          '\x1B[36m${"⚠️ > Warning ${tag != null ? "$tag: " : ""}$value"}\x1B[0m');
      break;
    case DebugType.error:
      stdout.writeln(
          '\x1B[31m${"🚨 ERROR ${tag != null ? "$tag: " : ""}$value"}\x1B[0m');
      break;
    case DebugType.response:
      stdout.writeln(
          '\x1B[36m${"💡 RESPONSE ${tag != null ? "$tag: " : ""}$value"}\x1B[0m');
      break;
    case DebugType.url:
      stdout.writeln(
          '\x1B[34m${"📌 URL ${tag != null ? "$tag: " : ""}$value"}\x1B[0m');
      break;
  }
}
