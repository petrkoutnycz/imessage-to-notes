#!/bin/bash
# Unloads the per-user launchd agent and removes its plist. The app, the configuration and the
# State Store stay.
set -euo pipefail

label="cz.petrkoutny.imessage-to-notes"
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$label.plist"
echo "Unloaded $label."
