#!/usr/bin/env bash
# Reproduce this rice on a fresh Omarchy install.
#
#   ./install.sh            install everything (asks for sudo for packages)
#   ./install.sh --dry-run  show what would change, change nothing
#   ./install.sh --no-packages   skip pacman/AUR (configs, plugins, theme only)
#
# Safe to run again: packages use --needed, every file it would overwrite is
# backed up first to ~/.rice-backup/<date>/.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
DRY=0; PKGS=1
for a in "$@"; do
  case $a in
    --dry-run) DRY=1 ;;
    --no-packages) PKGS=0 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 1 ;;
  esac
done

say()  { printf '\033[1m==> %s\033[0m\n' "$*"; }
note() { printf '    %s\n' "$*"; }
run()  { if ((DRY)); then printf '    + %s\n' "$*"; else "$@"; fi; }
state() { sed -n "s/^$1=//p" "$REPO/packages/state.txt"; }

# ------------------------------------------------------------------ checks
[[ $EUID -ne 0 ]] || { echo "Run as your user, not root." >&2; exit 1; }
command -v omarchy >/dev/null || { echo "Omarchy is not installed (https://omarchy.org)." >&2; exit 1; }
want=$(state omarchy); have=$(omarchy version 2>/dev/null || echo "?")
say "Omarchy $have (captured on $want)"
[[ $have == "$want" ]] || note "different version: configs may need a look after install"
((DRY)) && note "dry run: nothing will be changed"

# ------------------------------------------------------------------ packages
if ((PKGS)); then
  say "Packages (pacman)"
  mapfile -t want_pkgs < <(grep -v '^\s*$' "$REPO/packages/pacman.txt")
  missing=(); unavailable=()
  for p in "${want_pkgs[@]}"; do
    pacman -Qq "$p" &>/dev/null && continue
    if pacman -Si "$p" &>/dev/null; then missing+=("$p"); else unavailable+=("$p"); fi
  done
  note "${#want_pkgs[@]} listed, ${#missing[@]} to install"
  ((${#unavailable[@]})) && note "not in your repos, skipped: ${unavailable[*]}"
  ((${#missing[@]})) && run sudo pacman -S --needed --noconfirm "${missing[@]}"

  say "Packages (AUR)"
  mapfile -t aur < <(grep -v '^\s*$' "$REPO/packages/aur.txt")
  aur_missing=(); for p in "${aur[@]}"; do pacman -Qq "$p" &>/dev/null || aur_missing+=("$p"); done
  note "${#aur[@]} listed, ${#aur_missing[@]} to install"
  if ((${#aur_missing[@]})); then
    command -v yay >/dev/null || { echo "yay is missing (Omarchy ships it)." >&2; exit 1; }
    run yay -S --needed --noconfirm "${aur_missing[@]}"
  fi
fi

# ------------------------------------------------------------------ files
say "Config files"
backup="$HOME/.rice-backup/$(date +%Y%m%d-%H%M%S)"
changed=0; new=0
while IFS= read -r -d '' f; do
  rel=${f#"$REPO/home/"}; dst="$HOME/$rel"
  [[ $rel == .config/git/config && -e $dst ]] && continue   # seed only: keep an existing git config
  if [[ -e $dst ]]; then
    cmp -s "$f" "$dst" && continue
    changed=$((changed + 1))
    ((DRY)) && note "update  $rel" || { mkdir -p "$(dirname "$backup/$rel")"; cp -a "$dst" "$backup/$rel"; }
  else
    new=$((new + 1)); ((DRY)) && note "new     $rel"
  fi
done < <(find "$REPO/home" -type f -print0)
note "$new new, $changed updated$( ((changed && !DRY)) && echo ", old versions in $backup")"
run rsync -a --exclude '/.config/git/config' "$REPO/home/" "$HOME/"
[[ -e $HOME/.config/git/config ]] || run install -Dm644 "$REPO/home/.config/git/config" "$HOME/.config/git/config"
# the configs were captured in /home/lucien; point them at this home if it differs
if [[ $HOME != /home/lucien ]] && ((!DRY)); then
  grep -rlI '/home/lucien' "$REPO/home" | sed "s#^$REPO/home/##" | while read -r rel; do
    sed -i "s#/home/lucien#$HOME#g" "$HOME/$rel"; done
fi

# ------------------------------------------------------------------ Omarchy shell plugins
say "Omarchy shell plugins"
while read -r id url rev; do
  [[ -n ${id:-} ]] || continue
  dir="$HOME/.config/omarchy/plugins/$id"
  if [[ -d $dir/.git ]]; then
    [[ $(git -C "$dir" rev-parse HEAD) == "$rev" ]] && { note "$id: up to date"; continue; }
    run git -C "$dir" fetch -q origin
  else
    run git clone -q "$url" "$dir"
  fi
  run git -C "$dir" -c advice.detachedHead=false checkout -q "$rev"
  note "$id @ ${rev:0:7}"
done < "$REPO/packages/omarchy-plugins.txt"
note "local plugins: pmollaret.reboot-windows, superwhisper-panel (copied with the configs)"

# ------------------------------------------------------------------ wallpaper
say "Animated wallpaper (Quickshell + AI depth)"
if command -v /usr/lib/qt6/bin/qsb >/dev/null; then
  run /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 \
    -o "$HOME/.config/quickshell/zenitsu/depth.frag.qsb" "$HOME/.config/quickshell/zenitsu/depth.frag"
else
  note "qsb not found: using the precompiled shader"
fi

# ------------------------------------------------------------------ theme + background
say "Theme"
theme=$(state theme | tr '[:upper:] ' '[:lower:]-'); bg="$HOME/$(state background)"
[[ $(omarchy theme current 2>/dev/null) == "$(state theme)" ]] && note "already $(state theme)" || run omarchy theme set "$theme"
[[ -f $bg ]] && run omarchy theme bg set "$bg"

# ------------------------------------------------------------------ services, reload
say "Services and reload"
run systemctl --user daemon-reload
run systemctl --user enable --now firefox-omarchy-sync.path
if ((!DRY)); then
  hyprctl reload >/dev/null 2>&1 || true
  errs=$(hyprctl configerrors 2>/dev/null | grep -v '^\s*$' || true)
  [[ -z $errs ]] && note "Hyprland config OK" || { note "Hyprland reports:"; echo "$errs"; }
  omarchy-shell -q shell rescanPlugins || true
  pgrep -f '^qs -c zenitsu' >/dev/null || hyprctl eval \
    'hl.exec_cmd("uwsm-app -- env QT_LOGGING_RULES=quickshell.io.socket.warning=false qs -c zenitsu")' >/dev/null 2>&1 || true
fi

say "Done"
note "Not automated: Claude Code plugins come back when you sign in to Claude;"
note "~/.local/bin/vantamic is built from its own project (~/Work/vantamic);"
note "Secure Boot stays manual: ~/.config/omarchy/secureboot.sh"
