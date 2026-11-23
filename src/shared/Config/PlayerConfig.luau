--!strict
-- Règles liées aux données du joueur.

local PlayerConfig = {
	INVENTORY_LIMIT = 30,
	PROFILE_STORE_NAME = "PlayerData_v1", -- ne pas renommer : les profils existants y sont stockés
	DATA_VERSION = 7,
	DIG_HINT_ITEM_COUNT = 3, -- l'indice de creusage disparaît après ce nombre d'objets trouvés
	INDEX_NO_MUTATION = "Normal", -- clé de l'Index pour un objet trouvé sans mutation
}

return table.freeze(PlayerConfig)
