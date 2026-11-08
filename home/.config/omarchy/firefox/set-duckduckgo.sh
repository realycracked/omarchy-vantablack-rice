#!/bin/bash
# Ajoute « DuckDuckGo par défaut » aux politiques Firefox d'Omarchy (garde le reste).
# Firefox l'applique une fois au démarrage ; tu peux toujours changer de moteur ensuite.
set -euo pipefail
FILE=/usr/lib/firefox/distribution/policies.json
tmp=$(mktemp)
jq '.policies.SearchEngines.Default = "DuckDuckGo"' "$FILE" >"$tmp"
sudo install -m 644 -o root -g root -T "$tmp" "$FILE"
rm -f "$tmp"
echo "OK : DuckDuckGo défini comme moteur par défaut."
jq '.policies.SearchEngines' "$FILE"
