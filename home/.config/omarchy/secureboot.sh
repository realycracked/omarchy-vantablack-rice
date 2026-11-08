#!/bin/bash
# Secure Boot pour Omarchy (Limine + UKI) en dual boot avec Windows (Vanguard).
#
#   secureboot.sh preparer   1. installe sbctl, crée tes clés, signe Limine + noyaux (sans risque)
#   (BIOS)                   2. active le Secure Boot en mode « Custom » et efface les clés
#                               (« Setup Mode »), puis redémarre sur Omarchy
#   secureboot.sh enroler    3. installe tes clés + celles de Microsoft (Windows, Vanguard,
#                               carte graphique) dans la carte mère
#   secureboot.sh etat       affiche l'état
#
# Les mises à jour du noyau et de Limine sont ensuite re-signées automatiquement
# (hook pacman de sbctl + intégration sbctl des outils Limine).
set -euo pipefail

ESP=/boot

sign_all() {
  # Tous les exécutables EFI de la partition Omarchy (Limine, secours, noyaux UKI)
  while IFS= read -r -d '' file; do
    echo "  signature : $file"
    sudo sbctl sign -s "$file" >/dev/null
  done < <(sudo find "$ESP/EFI" -type f -iname '*.efi' -print0)
}

case ${1:-etat} in
  preparer)
    pacman -Q sbctl &>/dev/null || sudo pacman -S --needed --noconfirm sbctl
    if sudo sbctl status 2>/dev/null | grep -qiE "Owner GUID:\s+[0-9a-f]"; then
      echo "Clés déjà créées."
    else
      sudo sbctl create-keys
    fi
    echo "Signature des fichiers de démarrage :"
    sign_all
    echo; sudo sbctl verify || true
    echo; sudo sbctl status
    cat <<'EOT'

Étape suivante, dans le BIOS MSI (Suppr au démarrage) :
  Settings > Security > Secure Boot
    - Secure Boot : Enabled
    - Secure Boot Mode : Custom
    - Key Management > « Delete All Secure Boot Variables » (passe en Setup Mode)
  Enregistrer (F10), redémarrer sur Omarchy, puis lancer : secureboot.sh enroler
EOT
    ;;

  enroler)
    if ! sudo sbctl status | grep -qiE "Setup Mode:.*Enabled"; then
      echo "La carte mère n'est pas en « Setup Mode » : efface d'abord les clés dans le BIOS."
      sudo sbctl status
      exit 1
    fi
    sign_all
    # -m : clés Microsoft (Windows, Vanguard, ROM de la carte graphique) — indispensable
    # -f : clés d'origine de la carte mère MSI (firmware, ROM des périphériques)
    sudo sbctl enroll-keys -m -f
    echo; sudo sbctl status
    echo
    echo "C'est fait. Redémarre : le Secure Boot sera actif pour Omarchy et Windows."
    ;;

  etat)
    sudo sbctl status 2>/dev/null || echo "sbctl n'est pas installé."
    sudo sbctl verify 2>/dev/null || true
    ;;

  *)
    sed -n '2,13p' "$0"; exit 1 ;;
esac
