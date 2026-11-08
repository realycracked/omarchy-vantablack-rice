# Redémarrer sous Windows — plugin Omarchy

Un bouton dans la barre d'Omarchy qui redémarre **directement sous Windows**, une seule fois, sans avoir à guetter le menu de démarrage.

Le plugin règle la variable UEFI `BootNext` sur l'entrée « Windows Boot Manager », puis redémarre proprement (comme le menu Omarchy : les applications sont d'abord fermées). Le chargeur de démarrage (Limine, GRUB…) n'est pas modifié : au redémarrage suivant, votre PC revient à son ordre habituel.

## Utilisation

| Action | Effet |
|---|---|
| Clic gauche | Arme le bouton : l'icône passe en couleur d'alerte |
| Second clic gauche (dans les 4 s) | Redémarre sous Windows |
| Clic droit | Notification indiquant l'entrée Windows détectée |
| Clic du milieu | Annule et relance la détection |

Si aucune entrée Windows n'est trouvée, l'icône est grisée et un clic explique pourquoi.

## Installation

Il faut Omarchy 4 (« Quattro »), qui gère les plugins.

```bash
mkdir -p ~/.config/omarchy/plugins
cp -r pmollaret.reboot-windows ~/.config/omarchy/plugins/
omarchy-shell shell rescanPlugins
omarchy plugin enable pmollaret.reboot-windows
```

Le logo Windows apparaît à droite de la barre. On peut le déplacer à la souris.

### Sans mot de passe (facultatif, recommandé)

Modifier `BootNext` demande les droits administrateur. Sans réglage, Omarchy affiche sa fenêtre de mot de passe à chaque fois. Pour l'éviter :

```bash
~/.config/omarchy/plugins/pmollaret.reboot-windows/bin/reboot-to-windows --setup
```

Le script ajoute une règle sudo qui n'autorise **qu'une seule commande exacte** : `efibootmgr --bootnext <numéro de Windows>`. Elle est vérifiée par `visudo` avant d'être installée. Pour la retirer : `--unsetup`.

## Réglages

Dans les réglages du widget (ou `~/.config/omarchy/shell.json`) :

- `confirm` (oui par défaut) : exiger le second clic. Le désactiver fait redémarrer dès le premier clic.
- `bootEntry` : forcer un numéro d'entrée EFI (par exemple `0001`) si la détection automatique ne trouve pas la bonne. La commande `efibootmgr` liste les entrées.

## En ligne de commande

Le script marche aussi sans la barre, sur n'importe quel Linux en UEFI :

```bash
bin/reboot-to-windows --check    # quelle entrée sera utilisée ?
bin/reboot-to-windows            # redémarrer sous Windows
```

## Limites

- Il faut un démarrage UEFI et une entrée « Windows Boot Manager » dans le firmware. C'est le cas d'une installation normale de Windows 10/11.
- De rares cartes mères ignorent `BootNext`. Dans ce cas, le PC redémarre simplement sur Linux.
- Le plugin, comme tout plugin Omarchy, tourne sans bac à sable avec vos droits d'utilisateur. Le code tient en deux fichiers courts : `BarWidget.qml` et `bin/reboot-to-windows`.
