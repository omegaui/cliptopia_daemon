#!/bin/bash
flutter pub get
cliptopia-daemon --stop
echo ">> Building ..."
dart compile exe --target-os linux --output cliptopia-daemon bin/cliptopia_daemon.dart
chmod +x cliptopia-daemon
echo ">> Integrating ..."
sudo cp cliptopia-daemon /usr/bin/cliptopia-daemon
echo ">> Integration Successful"