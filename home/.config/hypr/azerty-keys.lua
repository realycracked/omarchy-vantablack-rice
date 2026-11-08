-- Correctif AZERTY : Hyprland 0.56 enregistre mal les raccourcis Omarchy écrits
-- en "code:N" (touche vide, code 0) : ils se déclenchaient tous dès qu'on
-- appuyait sur un modificateur (Win+Ctrl ouvrait les panneaux de la barre,
-- Win+Shift envoyait la fenêtre sur les espaces 1 à 10, etc.).
-- On les remplace par les mêmes raccourcis sur les touches AZERTY nommées.

local row = { "ampersand", "eacute", "quotedbl", "apostrophe", "parenleft",
              "minus", "egrave", "underscore", "ccedilla", "agrave" }
local function code(n) return "code:" .. tostring(n) end
local function swap(mods, n, key, description, action)
  hl.unbind(mods .. code(n))
  o.bind(mods .. key, description, action)
end

-- Espaces de travail 1-10 (Win + & é " ' ( - è _ ç à)
for ws = 1, 10 do
  local n, key = ws + 9, row[ws]
  swap("SUPER + ", n, key, "Switch to workspace " .. ws, o.workspaces.focus(ws))
  swap("SUPER + SHIFT + ", n, key, "Move window to workspace " .. ws, o.workspaces.move_window(ws))
  swap("SUPER + SHIFT + ALT + ", n, key, "Move window silently to workspace " .. ws, o.workspaces.move_window(ws, false))
end

-- Panneaux de la barre 1-9 (Win + Ctrl + & é " ...)
for panel = 1, 9 do
  swap("SUPER + CTRL + ", panel + 9, row[panel], "Bar panel " .. panel,
    "omarchy-shell -q shell togglePanelAt right " .. panel)
end

-- Fenêtre de groupe 1-5 (Win + Alt + & é " ' ()
for index = 1, 5 do
  swap("SUPER + ALT + ", index + 9, row[index], "Switch to group window " .. index,
    hl.dsp.group.active({ index = index }))
end

-- Redimensionnement (touches ) et =)
local function resize(x, y) return hl.dsp.window.resize({ x = x, y = y, relative = true }) end
swap("SUPER + ", 20, "parenright", "Expand window left", resize(-100, 0))
swap("SUPER + ", 21, "equal", "Shrink window left", resize(100, 0))
swap("SUPER + SHIFT + ", 20, "parenright", "Shrink window up", resize(0, -100))
swap("SUPER + SHIFT + ", 21, "equal", "Expand window down", resize(0, 100))
swap("SUPER + ALT + ", 20, "parenright", "Expand window left a little", resize(-25, 0))
swap("SUPER + ALT + ", 21, "equal", "Shrink window left a little", resize(25, 0))
swap("SUPER + SHIFT + ALT + ", 20, "parenright", "Shrink window up a little", resize(0, -25))
swap("SUPER + SHIFT + ALT + ", 21, "equal", "Expand window down a little", resize(0, 25))
swap("SUPER + CTRL + ", 20, "parenright", "Expand window left a lot", resize(-300, 0))
swap("SUPER + CTRL + ", 21, "equal", "Shrink window left a lot", resize(300, 0))
swap("SUPER + CTRL + SHIFT + ", 20, "parenright", "Shrink window up a lot", resize(0, -300))
swap("SUPER + CTRL + SHIFT + ", 21, "equal", "Expand window down a lot", resize(0, 300))

-- Webcam (touches ^ et $)
swap("SUPER + ALT + ", 34, "dead_circumflex", "Make webcam overlay smaller", "omarchy-capture-webcam-resize smaller")
swap("SUPER + ALT + ", 35, "dollar", "Make webcam overlay larger", "omarchy-capture-webcam-resize larger")

-- Touche Copilot (Win+Shift+F23) : menu Omarchy
swap("SUPER + SHIFT + ", 201, "F23", "Omarchy menu", { menu = "root" })
