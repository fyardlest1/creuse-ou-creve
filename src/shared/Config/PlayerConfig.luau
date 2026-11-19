--!strict
-- Règles liées aux données du joueur.

local PlayerConfig = {
	INVENTORY_LIMIT = 30,
	PROFILE_STORE_NAME = "PlayerData_v1", -- ne pas renommer : les profils existants y sont stockés
	DATA_VERSION = 2,
}

return table.freeze(PlayerConfig)
