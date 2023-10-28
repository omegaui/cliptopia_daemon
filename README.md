
# Cliptopia Daemon (Linux)

[**Cliptopia's**](https://github.com/omegaui/cliptopia) Clipboard Watcher **Daemon** for Linux


## Usage

Watches the system clipboard to provide clipboard caching.

**Maintained Cache is located at: /home/omegaui/.config/cliptopia/cache**

```shell
Usage: cliptopia-daemon [OPTIONS]
where OPTIONS could be one of these:

	--start         Start Daemon
	--stop          Stop Daemon
	--status        Show Daemon Status
	--restart       Stop and Restart Daemon
	--reset-cache   Stops the Daemon and clears the clipboard cache (not-recommended)
	--version       Prints program version
	--help          Prints this help message

and optionally:
	--debug         Enable printing logs to the terminal (should only be used when debugging)
```

## Examples

```shell
cliptopia-daemon --start --debug  # to start the daemon in debug mode
cliptopia-daemon --stop           # to stop any running instance of the daemon
cliptopia-daemon --status         # to check if the daemon is alive or stopped
cliptopia-daemon --restart        # to stop the running instance and restart the daemon
```

## Install

```shell
git clone https://github.com/omegaui/cliptopia_daemon
cd cliptopia_daemon
./installer.sh
```

## Install from source

```shell
git clone https://github.com/omegaui/cliptopia_daemon
cd cliptopia_daemon
dart compile exe --target-os linux --output cliptopia-daemon bin/cliptopia_daemon.dart
./installer.sh
```

## Build from source

```shell
dart compile exe --target-os linux --output cliptopia-daemon bin/cliptopia_daemon.dart
```
