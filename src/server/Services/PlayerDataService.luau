--!strict
-- Chargement, sauvegarde et accès aux données des joueurs (ProfileStore).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore)

type LoadedCallback = (player: Player, data: Types.PlayerData) -> ()

local PROFILE_KEY_PREFIX = "Player_"
local KICK_LOAD_FAILED = "Impossible de charger tes données. Reviens dans un instant !"
local KICK_SESSION_ENDED = "Ta partie a été ouverte sur un autre serveur. Reconnecte-toi !"

local TEMPLATE: Types.PlayerData = {
	version = PlayerConfig.DATA_VERSION,
	inventory = {},
	layer = 1,
	depth = 0,
	stats = {
		totalDigs = 0,
		foundByRarity = {},
	},
}

local PlayerDataService = {}

local store: any = nil
local profiles: { [Player]: any } = {}
local loadedCallbacks: { LoadedCallback } = {}

local function log(message: string)
	print("[PlayerData] " .. message)
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(PROFILE_KEY_PREFIX .. player.UserId, {
		Cancel = function(): boolean
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		if player.Parent == Players then
			warn("[PlayerData] Échec du chargement du profil de " .. player.Name)
			player:Kick(KICK_LOAD_FAILED)
		end
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		log("Profil libéré pour " .. player.Name)
		if player.Parent == Players then
			player:Kick(KICK_SESSION_ENDED)
		end
	end)

	-- Le joueur a pu partir pendant le chargement.
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	local data: Types.PlayerData = profile.Data
	log(
		string.format(
			"Profil chargé pour %s (couche %d, %d objets, mode %s)",
			player.Name,
			data.layer,
			#data.inventory,
			ProfileStore.DataStoreState
		)
	)

	PlayerDataService.refreshAttributes(player)

	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile ~= nil then
		profile:EndSession()
	end
end

-- Retourne les données d'un joueur chargé, ou nil.
function PlayerDataService.getData(player: Player): Types.PlayerData?
	local profile = profiles[player]
	if profile == nil then
		return nil
	end
	return profile.Data
end

-- Ajoute un objet à l'inventaire. Refuse si l'inventaire est plein.
function PlayerDataService.addItem(player: Player, item: Types.ItemInstance): boolean
	local data = PlayerDataService.getData(player)
	if data == nil or #data.inventory >= PlayerConfig.INVENTORY_LIMIT then
		return false
	end
	table.insert(data.inventory, item)
	PlayerDataService.refreshAttributes(player)
	return true
end

-- Recopie l'état affiché par le HUD dans des attributs du Player (lecture seule côté client).
function PlayerDataService.refreshAttributes(player: Player)
	local data = PlayerDataService.getData(player)
	if data == nil then
		return
	end
	player:SetAttribute("Layer", data.layer)
	player:SetAttribute("Depth", data.depth)
	player:SetAttribute("InventoryCount", #data.inventory)
end

-- Appelle le callback pour chaque joueur dont le profil est chargé (y compris ceux déjà chargés).
function PlayerDataService.onLoaded(callback: LoadedCallback)
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
end

function PlayerDataService.init()
	store = ProfileStore.New(PlayerConfig.PROFILE_STORE_NAME, TEMPLATE)
end

function PlayerDataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerDataService
