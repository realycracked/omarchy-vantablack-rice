-- Ordre des calques du bureau (même calque « bottom ») : plus `order` est grand,
-- plus le calque passe au fond. Le fond animé reste derrière les widgets, quel
-- que soit l'ordre de démarrage.
hl.layer_rule({ match = { namespace = "^zenitsu-wall$" }, order = 10 })
hl.layer_rule({ match = { namespace = "^omarchy-minuteur-desk$" }, order = -10 })
