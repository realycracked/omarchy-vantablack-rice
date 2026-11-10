#!/usr/bin/env bash
# Capture this PC's rice into the repo (packages, configs, plugins, wallpaper).
# Run it on the source machine, review `git diff`, commit.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
cd "$HOME"

# ---------------------------------------------------------------- files
# Paths relative to $HOME. Browser profiles, caches, keys and tokens are never captured.
PATHS=(
  .bashrc
  .config/hypr
  .config/omarchy/shell.json
  .config/omarchy/branding
  .config/omarchy/extensions
  .config/omarchy/hooks
  .config/omarchy/firefox
  .config/omarchy/backgrounds
  .config/omarchy/themed
  .config/omarchy/defaults
  .config/omarchy/language
  .config/omarchy/secureboot.sh
  .config/quickshell/zenitsu
  .config/btop/btop.conf
  .config/git/config
  .config/xdg-desktop-portal
  .config/nvim
  .config/spicetify
  .config/spotify-flags.conf
  .config/superwhisper/preferences.json
  .config/superwhisper/shortcuts.lua
  .config/superwhisper/hypr-block.lua
  .config/superwhisper/shortcuts.active.json
  .config/superwhisper/settings
  .config/mimeapps.list
  .config/user-dirs.dirs
  .config/environment.d
  .config/uwsm
  .config/gtk-3.0
  .config/fcitx
  .config/ZapZap
  .config/telmic
  .config/vantamic
  .config/foot
  .config/systemd/user/firefox-omarchy-sync.path
  .config/systemd/user/firefox-omarchy-sync.service
  .local/share/applications
  .local/share/zenitsu-wall
  .local/bin/firefox-omarchy-sync
  .local/bin/show-desktop
  .local/bin/spotify-omarchy-sync
  .local/share/nautilus/scripts
  .local/share/nautilus-python/extensions
  .local/state/flea/ui.json
  Pictures/Wallpapers/zenitsu.png
)
# every local Omarchy shell plugin (git ones are pinned in packages/omarchy-plugins.txt)
for d in .config/omarchy/plugins/*/; do
  [[ -d $d/.git ]] || PATHS+=("${d%/}")
done
rm -rf "$REPO/home"; mkdir -p "$REPO/home"
for p in "${PATHS[@]}"; do
  [[ -e $p ]] || { echo "skip (missing): $p"; continue; }
  rsync -a --relative --exclude '*.bak*' --exclude '.git' --exclude 'mimeinfo.cache' --exclude '__pycache__' "./$p" "$REPO/home/"
done

# machine-specific credential helpers (added by `gh auth login`) would break git elsewhere
if [[ -f $REPO/home/.config/git/config ]]; then
  awk '/^\[credential/{skip=1; next} /^\[/{skip=0} !skip' "$REPO/home/.config/git/config" > "$REPO/home/.config/git/config.tmp"
  mv "$REPO/home/.config/git/config.tmp" "$REPO/home/.config/git/config"
fi

# ---------------------------------------------------------------- packages
# Explicit packages that a stock Omarchy install doesn't have, plus a few
# dependencies the rice needs directly.
base=$(cat /usr/share/omarchy/install/omarchy-{base,other,x86_64-only}.packages 2>/dev/null | sed 's/#.*//' | tr -s ' \t' '\n' | grep -v '^$' | sort -u)
foreign=$(pacman -Qqem | sort)
mkdir -p "$REPO/packages"
{ comm -23 <(pacman -Qqe | sort) <(echo "$base") | comm -23 - <(echo "$foreign")
  printf '%s\n' quickshell qt6-shadertools superwhisper-bin; } | sort -u > "$REPO/packages/pacman.txt"
comm -23 <(echo "$foreign") <(echo "$base") > "$REPO/packages/aur.txt"

# ---------------------------------------------------------------- Omarchy shell plugins
# Git plugins are pinned to their commit; local ones are in home/ above.
: > "$REPO/packages/omarchy-plugins.txt"
for d in .config/omarchy/plugins/*/; do
  id=$(basename "$d")
  if url=$(git -C "$d" remote get-url origin 2>/dev/null); then
    echo "$id $url $(git -C "$d" rev-parse HEAD)" >> "$REPO/packages/omarchy-plugins.txt"
  fi
done

# ---------------------------------------------------------------- GNOME/GTK settings (dconf)
mkdir -p "$REPO/packages/dconf"
for path in /org/gnome/nautilus/ /org/gnome/desktop/interface/ /org/gtk/settings/file-chooser/ /org/gtk/gtk4/settings/file-chooser/; do
  name=$(echo "$path" | tr '/' '_' | sed 's/^_//; s/_$//')
  out=$(dconf dump "$path" 2>/dev/null || true)
  [[ -n $out ]] && printf '%s\n' "$out" > "$REPO/packages/dconf/$name.ini"
done

# ---------------------------------------------------------------- keybindings
if command -v hyprctl >/dev/null && hyprctl binds -j >/dev/null 2>&1; then
  hyprctl binds -j | python3 "$REPO/tools/keybindings.py" "$HOME/.config/hypr" > "$REPO/KEYBINDINGS.md"
fi

# ---------------------------------------------------------------- state
{ echo "theme=$(omarchy theme current 2>/dev/null)"
  echo "background=$(readlink ~/.local/state/omarchy/current/background 2>/dev/null | sed "s#^$HOME/##")"
  echo "omarchy=$(omarchy version 2>/dev/null)"
} > "$REPO/packages/state.txt"

echo "Captured into $REPO — review with: git -C \"$REPO\" status"
