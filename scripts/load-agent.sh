#!/bin/bash
# Installs build/ImessageToNotes.app in ~/Applications and loads the per-user launchd agent.
# The agent starts the tool at login and every 5 minutes, in the user session, so Notes and
# notifications work. Each start does one run and exits.
set -euo pipefail

cd "$(dirname "$0")/.."
label="cz.petrkoutny.imessage-to-notes"
app="$HOME/Applications/ImessageToNotes.app"
plist="$HOME/Library/LaunchAgents/$label.plist"
logs="$HOME/Library/Logs/imessage-to-notes"
domain="gui/$(id -u)"

if [ ! -d build/ImessageToNotes.app ]; then
    echo "build/ImessageToNotes.app does not exist. Run scripts/build-app.sh first." >&2
    exit 1
fi

# Unload the old agent first, so that launchd does not start the app while the copy is incomplete.
launchctl bootout "$domain/$label" 2>/dev/null || true
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents" "$logs"
rm -rf "$app"
ditto build/ImessageToNotes.app "$app"

cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$label</string>
	<key>AssociatedBundleIdentifiers</key>
	<string>$label</string>
	<key>ProgramArguments</key>
	<array>
		<string>$app/Contents/MacOS/imessage-to-notes</string>
		<string>run</string>
	</array>
	<key>LimitLoadToSessionType</key>
	<string>Aqua</string>
	<key>RunAtLoad</key>
	<true/>
	<key>StartInterval</key>
	<integer>300</integer>
	<key>StandardOutPath</key>
	<string>$logs/agent.log</string>
	<key>StandardErrorPath</key>
	<string>$logs/agent.log</string>
</dict>
</plist>
PLIST
plutil -lint "$plist"

launchctl bootstrap "$domain" "$plist"
echo "Loaded $label. It starts $app now and every 5 minutes. Output goes to $logs/agent.log."
