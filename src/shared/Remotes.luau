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
	StealSucceeded = "StealSucceeded", -- serveur -> victime et voleur : itemId, rarity, thiefName, victimName
	EjectRequest = "EjectRequest", -- client -> serveur : thiefUserId
	Ejected = "Ejected", -- serveur -> voleur : ownerName, stunSeconds
	PurchaseRequest = "PurchaseRequest", -- client -> serveur : clé du pass ou du produit
	UseBoost = "UseBoost", -- client -> serveur : "luckPotion" | "shield" (depuis la réserve)
	AutoDigToggle = "AutoDigToggle", -- client -> serveur : enabled (pass Creusage auto)
	RevengeCompensated = "RevengeCompensated", -- serveur -> joueur : Revanche impossible, potion en réserve
	ShopStateRequest = "ShopStateRequest", -- client -> serveur : aucun (état de la boutique)
	ShopState = "ShopState", -- serveur -> client : { [clé] = "" si achetable, "owned", ou clé Locale de la raison }
	DailyClaim = "DailyClaim", -- client -> serveur : aucun (réclamer la récompense du jour)
	RetentionStateRequest = "RetentionStateRequest", -- client -> serveur : aucun
	RetentionState = "RetentionState", -- serveur -> client : quotidien, quêtes, Index, titre
	RetentionNotice = "RetentionNotice", -- serveur -> client : LocText (quête réussie, palier d'Index...)
	LuckEventStarted = "LuckEventStarted", -- serveur -> tous : buyerName, endsAt (os.time)
	LockpickStarted = "LockpickStarted", -- serveur -> voleur : Lockpick.Settings, victimName (ouvre le mini-jeu)
	LockpickResult = "LockpickResult", -- client -> serveur : "success" | "abort" (intention seulement)
	WorldEventWarning = "WorldEventWarning", -- serveur -> tous : kind ("meteor" | "bloodNight"), startsAt (GetServerTimeNow)
	ItemAnnounced = "ItemAnnounced", -- serveur -> tous : finderUserId, finderName, itemId, rarity (Légendaire, Secret)
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
