-- LocalSend en Vantablack : il prend sa place dans le tiling au lieu de
-- flotter, et reste opaque pour que son noir pur soit vraiment noir.
local localsend = "(org\\.localsend\\.)?localsend(_app)?"
o.window(localsend, { tile = true, opacity = "1 1" })
