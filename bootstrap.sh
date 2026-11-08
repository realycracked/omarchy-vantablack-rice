#!/usr/bin/env bash
# One-line install of the Omarchy Vantablack rice:
#
#   curl -fsSL https://raw.githubusercontent.com/realycracked/omarchy-vantablack-rice/main/bootstrap.sh | bash
#
# Preview first (changes nothing):
#
#   curl -fsSL https://raw.githubusercontent.com/realycracked/omarchy-vantablack-rice/main/bootstrap.sh | bash -s -- --dry-run
#
# Clones (or updates) the repo into ~/.local/share/omarchy-vantablack-rice, then runs install.sh
# with the same arguments. Set RICE_DIR to clone somewhere else.
set -euo pipefail
REPO_URL=https://github.com/realycracked/omarchy-vantablack-rice.git
DEST=${RICE_DIR:-$HOME/.local/share/omarchy-vantablack-rice}

command -v omarchy >/dev/null || { echo "This needs Omarchy (https://omarchy.org)." >&2; exit 1; }
command -v git >/dev/null || { echo "git is missing." >&2; exit 1; }

if [[ -d $DEST/.git ]]; then
  echo "==> Updating $DEST"
  git -C "$DEST" pull -q --ff-only
else
  echo "==> Cloning into $DEST"
  git clone -q --depth 1 "$REPO_URL" "$DEST"
fi
exec "$DEST/install.sh" "$@"
