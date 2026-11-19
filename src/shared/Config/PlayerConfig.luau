--!strict
-- Règles liées aux données du joueur.

local PlayerConfig = {
	INVENTORY_LIMIT = 30,
	PROFILE_STORE_NAME = "PlayerData_v1",
	DATA_VERSION = 1,
}

return table.freeze(PlayerConfig)
