--!strict
-- Noms centralisés des RemoteEvents. Le serveur les crée dans ReplicatedStorage.Remotes.

local Remotes = {
	FOLDER_NAME = "Remotes",
	Names = {
		PlotAssigned = "PlotAssigned", -- serveur -> client : plotIndex, origin
		DigRequest = "DigRequest", -- client -> serveur : cellIndex
		CellHit = "CellHit", -- serveur -> client : cellIndex, hitsLeft
		ItemRevealed = "ItemRevealed", -- serveur -> client : RevealPayload
		InventoryFull = "InventoryFull", -- serveur -> client : aucun
		LayerCleared = "LayerCleared", -- serveur -> client : layer, depth
	},
}

return table.freeze(Remotes)
