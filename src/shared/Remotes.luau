--!strict
-- Noms centralisés des RemoteEvents, rangés dans ReplicatedStorage.Remotes.
-- Le serveur les crée ; le client les attend.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Names = table.freeze({
	PlotAssigned = "PlotAssigned", -- serveur -> client : plotIndex, origin
	DigRequest = "DigRequest", -- client -> serveur : cellIndex
	CellHit = "CellHit", -- serveur -> client : cellIndex, hitsLeft
	ItemRevealed = "ItemRevealed", -- serveur -> client : RevealPayload
	InventoryFull = "InventoryFull", -- serveur -> client : aucun
	LayerCleared = "LayerCleared", -- serveur -> client : layer, depth
	InventoryUpdated = "InventoryUpdated", -- serveur -> client : { ItemInstance } (tout le coffre)
	SellRequest = "SellRequest", -- client -> serveur : SellRequestPayload
	SellResult = "SellResult", -- serveur -> client : SellResultPayload
	ToggleFavorite = "ToggleFavorite", -- client -> serveur : uid
	BuyShovel = "BuyShovel", -- client -> serveur : shovelId
	ShovelChanged = "ShovelChanged", -- serveur -> client : shovelId
	StratumBlocked = "StratumBlocked", -- serveur -> client : requiredShovel (shovelId)
	DigSwing = "DigSwing", -- serveur -> tous les clients : player (coup de pelle validé, à animer)
	PhaseChanged = "PhaseChanged", -- serveur -> tous : phase ("Day" | "Night"), endsAt (GetServerTimeNow)
	StealStarted = "StealStarted", -- serveur -> victime : thiefName, thiefUserId
	StealCancelled = "StealCancelled", -- serveur -> victime et voleur : reason, otherName
	StealSucceeded = "StealSucceeded", -- serveur -> victime et voleur : itemName, rarity, thiefName, victimName
	EjectRequest = "EjectRequest", -- client -> serveur : thiefUserId
	Ejected = "Ejected", -- serveur -> voleur : ownerName, stunSeconds
})

local function getFolderOnServer(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

-- Côté serveur : crée le RemoteEvent s'il n'existe pas. Côté client : l'attend.
local function get(name: string): RemoteEvent
	if RunService:IsServer() then
		local folder = getFolderOnServer()
		local existing = folder:FindFirstChild(name)
		if existing ~= nil and existing:IsA("RemoteEvent") then
			return existing
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME):WaitForChild(name) :: RemoteEvent
end

return table.freeze({
	FOLDER_NAME = FOLDER_NAME,
	Names = Names,
	get = get,
})
