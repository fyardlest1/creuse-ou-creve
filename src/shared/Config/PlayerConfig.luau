--!strict
-- Règles liées aux données du joueur.

local PlayerConfig = {
	INVENTORY_LIMIT = 30,
	PROFILE_STORE_NAME = "PlayerData_v1", -- ne pas renommer : les profils existants y sont stockés
	DATA_VERSION = 2,
	DIG_HINT_ITEM_COUNT = 3, -- l'indice de creusage disparaît après ce nombre d'objets trouvés
}

return table.freeze(PlayerConfig)
