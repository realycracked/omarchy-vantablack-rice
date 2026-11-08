-- Snapping façon KDE Plasma pour les espaces de travail en mode flottant (Super+L).
-- Lâcher une fenêtre déplacée contre un bord de l'écran :
--   bord gauche / droit -> moitié de l'écran   (coin haut/bas du bord -> quart)
--   bord du haut        -> plein écran          (coin gauche/droit      -> quart)
-- Auto-organisation : en mettant une fenêtre sur une moitié, s'il n'y a qu'une
-- seule autre fenêtre sur l'espace, elle prend l'autre moitié.
-- Décrocher une fenêtre « snappée » lui rend sa taille d'avant.

local EDGE = 6        -- distance au bord (px) qui déclenche le snap
local GAP = 4         -- marge autour des fenêtres snappées (= gaps_out)
local CORNER = 0.25   -- part du bord qui compte comme coin

local snapped = {}    -- adresse -> { w, h } taille avant le snap
local pressed = nil   -- fenêtre et position au moment du clic

local function has_tag(window, wanted)
  for _, tag in ipairs(window.tags or {}) do
    if tag == wanted then return true end
  end
  return false
end

-- Seulement les fenêtres flottantes d'un espace en mode flottant
local function eligible(window)
  return window and window.floating and (window.fullscreen or 0) == 0
    and has_tag(window, "omarchy-floating-workspace")
end

-- Zone utile de l'écran (sans la barre), en coordonnées logiques
local function area(monitor)
  local scale = monitor.scale or 1
  local w, h = math.floor(monitor.width / scale), math.floor(monitor.height / scale)
  if (monitor.transform or 0) % 2 == 1 then w, h = h, w end
  local r = monitor.reserved or {}
  return {
    mx = monitor.x, my = monitor.y, mw = w, mh = h,
    x = monitor.x + (r.left or 0), y = monitor.y + (r.top or 0),
    w = w - (r.left or 0) - (r.right or 0), h = h - (r.top or 0) - (r.bottom or 0),
  }
end

local function zone_for(cursor, a)
  local left = cursor.x <= a.mx + EDGE
  local right = cursor.x >= a.mx + a.mw - 1 - EDGE
  local top = cursor.y <= a.y + EDGE
  local upper = cursor.y < a.y + a.h * CORNER
  local lower = cursor.y > a.y + a.h * (1 - CORNER)
  local lefter = cursor.x < a.x + a.w * CORNER
  local righter = cursor.x > a.x + a.w * (1 - CORNER)

  if left then return upper and "top-left" or lower and "bottom-left" or "left" end
  if right then return upper and "top-right" or lower and "bottom-right" or "right" end
  if top then return lefter and "top-left" or righter and "top-right" or "max" end
  return nil
end

local function rect_for(zone, a)
  local hw, hh = math.floor((a.w - 3 * GAP) / 2), math.floor((a.h - 3 * GAP) / 2)
  local fw, fh = a.w - 2 * GAP, a.h - 2 * GAP
  local lx, rx = a.x + GAP, a.x + 2 * GAP + hw
  local ty, by = a.y + GAP, a.y + 2 * GAP + hh
  local rects = {
    left = { lx, ty, hw, fh }, right = { rx, ty, hw, fh }, max = { lx, ty, fw, fh },
    ["top-left"] = { lx, ty, hw, hh }, ["top-right"] = { rx, ty, hw, hh },
    ["bottom-left"] = { lx, by, hw, hh }, ["bottom-right"] = { rx, by, hw, hh },
  }
  return rects[zone]
end

local function apply(window, rect)
  local sel = "address:" .. window.address
  if not snapped[window.address] then
    snapped[window.address] = { w = window.size.x, h = window.size.y }
  end
  hl.dispatch(hl.dsp.window.resize({ x = rect[3], y = rect[4], relative = false, window = sel }))
  hl.dispatch(hl.dsp.window.move({ x = rect[1], y = rect[2], relative = false, window = sel }))
end

-- L'unique autre fenêtre de l'espace prend la moitié opposée
local function auto_fill(window, zone, a)
  local opposite = ({ left = "right", right = "left" })[zone]
  if not opposite then return end
  local others = {}
  for _, other in ipairs(hl.get_workspace_windows(tostring(window.workspace.id)) or {}) do
    if other.address ~= window.address and eligible(other) and not other.hidden then
      others[#others + 1] = other
    end
  end
  if #others == 1 then apply(others[1], rect_for(opposite, a)) end
end

local function on_release()
  local before = pressed
  pressed = nil
  if not before then return end

  -- Laisser Hyprland terminer le déplacement avant de repositionner
  hl.timer(function()
    local window = hl.get_active_window()
    if not eligible(window) or window.address ~= before.address then return end
    local moved = math.abs(window.at.x - before.x) > 4 or math.abs(window.at.y - before.y) > 4
    if not moved then return end

    local monitor = hl.get_monitor_at_cursor()
    if not monitor then return end
    local a = area(monitor)
    local cursor = hl.get_cursor_pos()
    local zone = zone_for(cursor, a)

    if zone then
      apply(window, rect_for(zone, a))
      auto_fill(window, zone, a)
    elseif snapped[window.address] then
      -- Décrochée : reprendre la taille d'avant, centrée sous le curseur en largeur
      local size = snapped[window.address]
      snapped[window.address] = nil
      local sel = "address:" .. window.address
      hl.dispatch(hl.dsp.window.resize({ x = size.w, y = size.h, relative = false, window = sel }))
      hl.dispatch(hl.dsp.window.move({
        x = math.floor(cursor.x - size.w / 2), y = math.max(a.y, math.floor(cursor.y - 15)),
        relative = false, window = sel,
      }))
    end
  end, { timeout = 60, type = "oneshot" })
end

local function on_press()
  hl.timer(function()
    local window = hl.get_active_window()
    if eligible(window) then
      pressed = { address = window.address, x = window.at.x, y = window.at.y }
    else
      pressed = nil
    end
  end, { timeout = 1, type = "oneshot" })
end

-- Clic gauche (avec ou sans Super, barre de titre comprise) : écoute sans rien bloquer
local listen = { transparent = true, ignore_mods = true, non_consuming = true }
hl.bind("mouse:272", on_press, listen)
hl.bind("mouse:272", on_release, { transparent = true, ignore_mods = true, non_consuming = true, release = true })

hl.on("window.destroy", function(window)
  local ok, address = pcall(function() return window and window.address end)
  if ok and address then snapped[address] = nil end
end)

-- Aimantation douce aux bords et aux autres fenêtres pendant le déplacement
hl.config({ general = { snap = { enabled = true, window_gap = GAP, monitor_gap = GAP, respect_gaps = true } } })
