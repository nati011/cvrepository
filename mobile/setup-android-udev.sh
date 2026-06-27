#!/usr/bin/env bash
# One-time setup so ADB can access Samsung/Android devices over USB.
set -euo pipefail

RULES_FILE="/etc/udev/rules.d/51-android.rules"
RULE='SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666", GROUP="plugdev"'

echo "Installing udev rules for Android USB debugging..."
echo "$RULE" | sudo tee "$RULES_FILE" > /dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo usermod -aG plugdev "$USER"

echo ""
echo "Done. Unplug and replug your phone, then log out/in (or run: newgrp plugdev)."
echo "Verify with: adb devices"
