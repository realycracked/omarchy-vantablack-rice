-- Change the default Omarchy look'n'feel.

-- Opt another application in to Omarchy's standard transparency.
-- Find its class with: hyprctl clients
-- o.transparent_window("my-app")
-- o.transparent_window("my-app", "0.9 0.85") -- Custom active/inactive opacity.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })

-- Ne jamais déplacer le pointeur automatiquement (ex. recentrage sur la
-- fenêtre après un déplacement Super + clic gauche).
hl.config({ cursor = { no_warps = true } })

-- Apparence affinée : fenêtres un peu plus serrées, coins carrés, bordure fine, ombre légère.
hl.config({
  general = {
    gaps_in = 2,      -- entre les fenêtres (Omarchy : 5)
    gaps_out = 4,     -- avec les bords de l'écran (Omarchy : 10)
    border_size = 1,  -- (Omarchy : 2)
  },
  decoration = {
    rounding = 0,  -- coins carrés
    shadow = {
      enabled = true,
      range = 14,
      render_power = 3,
      offset = "0 3",
      color = "rgba(00000070)",
      color_inactive = "rgba(00000040)",
    },
  },
  group = {
    groupbar = { gradient_rounding = 0 },
  },
})
