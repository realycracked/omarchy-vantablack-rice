#!/bin/bash
# Installe Dark Reader (thème sombre sur tous les sites) via les politiques Firefox,
# depuis addons.mozilla.org. Garde le reste des politiques.
set -euo pipefail
FILE=/usr/lib/firefox/distribution/policies.json
tmp=$(mktemp)
jq '.policies.ExtensionSettings["addon@darkreader.org"] = {
      "installation_mode": "normal_installed",
      "install_url": "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi"
    }' "$FILE" >"$tmp"
sudo install -m 644 -o root -g root -T "$tmp" "$FILE"
rm -f "$tmp"
echo "OK : Dark Reader sera installé au prochain démarrage de Firefox."
jq '.policies | {SearchEngines, ExtensionSettings}' "$FILE"
