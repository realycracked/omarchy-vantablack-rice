#!/usr/bin/env python3
"""Turn `hyprctl binds -j` (stdin) into KEYBINDINGS.md.

Bindings whose description appears in the user's own Hyprland Lua files
(argv[1], e.g. ~/.config/hypr) are marked with a star: those are the ones this
rice adds or changes on top of Omarchy's defaults.
"""
import json, os, re, sys

binds = json.load(sys.stdin)
hypr = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.config/hypr")
own = set()
for f in os.listdir(hypr):
    if f.endswith(".lua") and ".bak" not in f:
        own |= set(re.findall(r'"([^"]{3,})"', open(os.path.join(hypr, f), encoding="utf-8").read()))

MODS = [(64, "Super"), (4, "Ctrl"), (8, "Alt"), (1, "Shift")]
KEYS = {"mouse:272": "Left click", "mouse:273": "Right click", "mouse_down": "Wheel down", "mouse_up": "Wheel up",
        "RETURN": "Enter", "SPACE": "Space", "TAB": "Tab", "ESCAPE": "Esc", "BACKSPACE": "Backspace",
        "COMMA": ",", "PERIOD": ".", "SLASH": "/", "MINUS": "-", "EQUAL": "=", "PRINT": "Print",
        "LEFT": "←", "RIGHT": "→", "UP": "↑", "DOWN": "↓", "code:20": "-", "code:21": "=",
        # AZERTY keysyms
        "parenright": ")", "parenleft": "(", "dollar": "$", "dead_circumflex": "^", "ampersand": "&",
        "eacute": "é", "quotedbl": '"', "apostrophe": "'", "minus": "-", "egrave": "è", "underscore": "_",
        "ccedilla": "ç", "agrave": "à", "asterisk": "*", "ugrave": "ù", "exclam": "!", "colon": ":",
        "semicolon": ";", "less": "<", "equal": "=", "comma": ",", "period": ".", "slash": "/"}

def key(b):
    k = b["key"] or (f"code:{b['keycode']}" if b["keycode"] else "")
    k = KEYS.get(k, KEYS.get(k.upper(), k))
    k = re.sub(r"^XF86", "", k)
    return k if len(k) != 1 else k.upper()

def mods(m):
    return " + ".join(n for bit, n in MODS if m & bit)

groups = {}
for b in binds:
    if b["key"].startswith("switch:") or not b["description"]:
        continue
    m = mods(b["modmask"])
    combo = (m + " + " if m else "") + key(b)
    groups.setdefault(m or "No modifier", []).append((combo, b["description"], b["description"] in own))

order = ["Super", "Super + Shift", "Super + Ctrl", "Super + Alt", "Super + Ctrl + Shift", "Super + Alt + Shift",
         "Super + Ctrl + Alt", "Ctrl", "Alt", "Shift", "No modifier"]
names = sorted(groups, key=lambda g: (order.index(g) if g in order else len(order), g))

total = sum(len(v) for v in groups.values())
mine = sum(1 for v in groups.values() for x in v if x[2])
print("# Keyboard shortcuts\n")
print(f"All {total} Hyprland bindings of this setup, generated from `hyprctl binds` by `sync.sh`.")
print(f"★ marks the {mine} that this rice adds or changes on top of Omarchy's defaults.")
print("On an AZERTY keyboard the number row works without Shift (see `home/.config/hypr/azerty-keys.lua`).\n")
for g in names:
    rows = sorted(set(groups[g]), key=lambda r: (r[0].split(" + ")[-1], r[1]))
    print(f"## {g}\n")
    print("| Keys | Action |")
    print("|---|---|")
    for combo, desc, star in rows:
        desc = desc.replace("|", "\\|")
        print(f"| `{combo}` | {desc}{' ★' if star else ''} |")
    print()
