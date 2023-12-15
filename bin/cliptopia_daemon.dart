import 'dart:io';

import 'package:cliptopia_daemon/core/argument_handler.dart';
import 'package:cliptopia_daemon/core/shell_scripts.dart';
import 'package:cliptopia_daemon/daemon.dart';

void main(List<String> arguments) async {
  ArgumentHandler.init(arguments);

  if (!ArgumentHandler.validate()) {
    final unknownOptions = ArgumentHandler.getUnknownOptions();
    if (unknownOptions.isNotEmpty) {
      stdout.writeln("Incorrect Usage: ${unknownOptions.join(" ")}");
    }
    logUsage(describe: unknownOptions.isEmpty);
    return;
  }

  if (ArgumentHandler.shouldShowHelp()) {
    logUsage();
    return;
  }

  final daemon = Daemon();

  if (ArgumentHandler.shouldStart()) {
    ShellScripts.ensure();
    daemon.startDaemon();
  } else if (ArgumentHandler.shouldStop()) {
    daemon.stopDaemon();
  } else if (ArgumentHandler.shouldRestart()) {
    daemon.restartDaemon();
  } else if (ArgumentHandler.shouldShowStatus()) {
    daemon.status();
  } else if (ArgumentHandler.shouldShowCacheSize()) {
    daemon.cacheSize();
  } else if (ArgumentHandler.shouldEnableIncognitoMode()) {
    daemon.incognito(true);
  } else if (ArgumentHandler.shouldDisableIncognitoMode()) {
    daemon.incognito(false);
  } else if (ArgumentHandler.shouldResetCache()) {
    daemon.resetCache();
  } else if (ArgumentHandler.shouldShowVersion()) {
    daemon.version();
  } else {
    stdout.writeln("No Option Provided.");
    daemon.status();
  }
}

void logUsage({describe = true}) {
  if (describe) {
    stdout.writeln();
    stdout
        .writeln("Watches the system clipboard to provide clipboard caching.");
    stdout.writeln(
        "Cache is located at: ${Platform.environment['HOME']}/.config/cliptopia/cache");
    stdout.writeln();
  }
  stdout.writeln("Usage: cliptopia-daemon [OPTIONS]");
  stdout.writeln("where OPTIONS could be one of these:");
  stdout.writeln();
  stdout.writeln("\t--start                    Start Daemon");
  stdout.writeln("\t--stop                     Stop Daemon");
  stdout.writeln("\t--status                   Show Daemon Status");
  stdout.writeln("\t--cache-size               Show Cache Size in MB");
  stdout.writeln("\t--enable-incognito-mode    Pause clipboard watching");
  stdout.writeln("\t--disable-incognito-mode   Continue clipboard watching");
  stdout.writeln("\t--restart                  Stop and Restart Daemon");
  stdout.writeln(
      "\t--reset-cache              Stops the Daemon and clears the clipboard cache (not-recommended)");
  stdout.writeln("\t--version                  Prints program version");
  stdout.writeln("\t--help                     Prints this help message");
  stdout.writeln();
  stdout.writeln("and optionally:");
  stdout.writeln(
      "\t--debug                    Enable printing logs to the terminal (should only be used when debugging)");
  if (describe) {
    stdout.writeln();
    stdout.writeln("examples:");
    stdout.writeln(
        "\tcliptopia-daemon --start --debug  # to start the daemon in debug mode");
    stdout.writeln(
        "\tcliptopia-daemon --stop           # to stop any running instance of the daemon");
    stdout.writeln(
        "\tcliptopia-daemon --status         # to check if the daemon is alive or stopped");
    stdout.writeln(
        "\tcliptopia-daemon --restart        # to stop the running instance and restart the daemon");
  }
}
