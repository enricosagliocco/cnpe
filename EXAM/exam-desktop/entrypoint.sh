#!/usr/bin/env bash
set -uo pipefail

SSH_SRC="${SSH_MOUNT_PATH:-/tmp/host-ssh}"
USER_HOME="$(getent passwd headless | cut -d: -f6)"
USER_HOME="${USER_HOME:-$(eval echo ~headless)}"
SSH_DST="${USER_HOME}/.ssh"

# --- Copia le chiavi SSH se disponibili ---
if [ -d "$SSH_SRC" ] && [ "$(ls -A "$SSH_SRC" 2>/dev/null)" ]; then
  mkdir -p "$SSH_DST"
  cp -R "$SSH_SRC"/. "$SSH_DST"/
  chown -R headless:headless "$SSH_DST"
  chmod 700 "$SSH_DST"
  find "$SSH_DST" -type f -name "*.pub" -exec chmod 644 {} \;
  find "$SSH_DST" -type f ! -name "*.pub" -exec chmod 600 {} \;
fi

# --- Configurazione VSCodium ---
mkdir -p "$USER_HOME/.config/VSCodium/User"
cat > "$USER_HOME/.config/VSCodium/User/settings.json" <<'SETTINGS'
{
  "window.menuBarVisibility": "classic",
  "telemetry.telemetryLevel": "off",
  "update.mode": "none",
  "security.workspace.trust.enabled": false,
  "editor.fontSize": 13,
  "terminal.integrated.fontSize": 13
}
SETTINGS
chown -R headless:headless "$USER_HOME/.config"

# --- Configurazione Firefox ---
mkdir -p "$USER_HOME/.mozilla/firefox/exam.default"
cat > "$USER_HOME/.mozilla/firefox/profiles.ini" <<'PROFILES'
[Profile0]
Name=default
IsRelative=1
Path=exam.default
Default=1

[General]
StartWithLastProfile=1
Version=2
PROFILES

cat > "$USER_HOME/.mozilla/firefox/exam.default/user.js" <<'FIREFOX'
user_pref("gfx.webrender.software", true);
user_pref("media.hardware-video-decoding.enabled", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.uidensity", 1);
FIREFOX

chown -R headless:headless "$USER_HOME/.mozilla"

# --- Workspace ---
mkdir -p "$USER_HOME/workspace"
chown headless:headless "$USER_HOME/workspace"

exec "$@"
