--!strict
-- Chargement, sauvegarde et accès aux données des joueurs (ProfileStore).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Shovels = require(Shared.Config.Shovels)
local Strata = require(Shared.Config.Strata)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local StealConfig = require(Shared.Config.StealConfig)
local Remotes = require(Shared.Remotes)
local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore)

type LoadedCallback = (player: Player, data: Types.PlayerData) -> ()

local PROFILE_KEY_PREFIX = "Player_"
local KICK_LOAD_FAILED = "Impossible de charger tes données. Reviens dans un instant !"
local KICK_SESSION_ENDED = "Ta partie a été ouverte sur un autre serveur. Reconnecte-toi !"

local TEMPLATE: Types.PlayerData = {
	version = PlayerConfig.DATA_VERSION,
	coins = EconomyConfig.STARTING_COINS,
	inventory = {},
	depth = 0,
	ownedShovels = { Shovels.DEFAULT_ID },
	equippedShovel = Shovels.DEFAULT_ID,
	stats = {
		totalDigs = 0,
		foundByRarity = {},
		totalCoinsEarned = 0,
		itemsSold = 0,
		stealsSucceeded = 0,
		stealsAttempted = 0,
		timesRobbed = 0,
		ejections = 0,
	},
	digHintDone = false,
	playTime = 0,
	thiefPoints = 0,
}

local PlayerDataService = {}

local store: any = nil
local profiles: { [Player]: any } = {}
local loadedCallbacks: { LoadedCallback } = {}
local inventoryUpdatedRemote: RemoteEvent

local function log(message: string)
	print("[PlayerData] " .. message)
end

-- Version 1 -> 2 : `layer` disparaît (déduite de `depth`), Pièces et pelles apparaissent,
-- chaque objet reçoit `favorite = false` et une valeur recalculée avec le multiplicateur de la couche 1.
-- Aucun objet n'est jamais retiré : un objet inconnu garde sa valeur d'origine.
local function migrateV1ToV2(data: any)
	local multiplier = Strata.byLayer[1].valueMultiplier
	for _, item in data.inventory do
		item.favorite = false
		local rarity = Rarities.byId[item.rarity]
		if rarity ~= nil then
			local mutation = if item.mutation ~= nil then Mutations.byId[item.mutation] else nil
			local mutationMultiplier = if mutation ~= nil then mutation.multiplier else 1
			item.value = rarity.value * mutationMultiplier * multiplier
		else
			warn(
				"[PlayerData] Rareté inconnue pendant la migration, objet conservé tel quel : "
					.. tostring(item.itemId)
			)
		end
	end
	data.layer = nil
	data.coins = data.coins or EconomyConfig.STARTING_COINS
	data.ownedShovels = data.ownedShovels or { Shovels.DEFAULT_ID }
	data.equippedShovel = data.equippedShovel or Shovels.DEFAULT_ID
	data.stats = data.stats or {}
	data.stats.totalCoinsEarned = data.stats.totalCoinsEarned or 0
	data.stats.itemsSold = data.stats.itemsSold or 0
	data.version = 2
end

-- Version 2 -> 3 : temps de jeu (protection débutant), Points de Voleur et statistiques de vol.
-- Les joueurs existants partent avec playTime = 0, donc protégés 20 minutes : c'est voulu.
-- Aucun objet n'est touché (stolenFrom est optionnel).
local function migrateV2ToV3(data: any)
	data.playTime = data.playTime or 0
	data.thiefPoints = data.thiefPoints or 0
	data.stats = data.stats or {}
	data.stats.stealsSucceeded = data.stats.stealsSucceeded or 0
	data.stats.stealsAttempted = data.stats.stealsAttempted or 0
	data.stats.timesRobbed = data.stats.timesRobbed or 0
	data.stats.ejections = data.stats.ejections or 0
	data.version = 3
end

-- Amène des données de n'importe quelle version à la version courante. Retourne la version d'origine.
-- Exposée pour pouvoir la tester sur des profils fabriqués.
function PlayerDataService.migrate(data: any): number
	local fromVersion = if typeof(data.version) == "number" then data.version else 1
	data.inventory = data.inventory or {}
	if fromVersion < 2 then
		migrateV1ToV2(data)
	end
	if fromVersion < 3 then
		migrateV2ToV3(data)
	end
	return fromVersion
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
	local fromVersion = PlayerDataService.migrate(profile.Data)
	profile:Reconcile()
	-- Profils existants : qui a déjà trouvé assez d'objets n'a plus besoin de l'indice.
	if profile.Data.stats.totalDigs >= PlayerConfig.DIG_HINT_ITEM_COUNT then
		profile.Data.digHintDone = true
	end
	if fromVersion < PlayerConfig.DATA_VERSION then
		log(string.format("Migration v%d -> v%d pour %s", fromVersion, PlayerConfig.DATA_VERSION, player.Name))
	end

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
			"Profil chargé pour %s (v%d, %d m, %d objets, %d Pièces, pelle %s, mode %s)",
			player.Name,
			data.version,
			data.depth,
			#data.inventory,
			data.coins,
			data.equippedShovel,
			ProfileStore.DataStoreState
		)
	)

	PlayerDataService.refreshAttributes(player)
	PlayerDataService.pushInventory(player)

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
	PlayerDataService.pushInventory(player)
	return true
end

-- Envoie tout le coffre au client. À appeler après chaque changement du coffre.
function PlayerDataService.pushInventory(player: Player)
	local data = PlayerDataService.getData(player)
	if data == nil then
		return
	end
	inventoryUpdatedRemote:FireClient(player, data.inventory)
end

-- Recopie l'état affiché par le HUD dans des attributs du Player (lecture seule côté client).
function PlayerDataService.refreshAttributes(player: Player)
	local data = PlayerDataService.getData(player)
	if data == nil then
		return
	end
	local stratum = Strata.fromDepth(data.depth)
	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("Depth", data.depth)
	player:SetAttribute("Layer", stratum.layer)
	player:SetAttribute("Stratum", stratum.id)
	player:SetAttribute("EquippedShovel", data.equippedShovel)
	player:SetAttribute("OwnedShovels", table.concat(data.ownedShovels, ","))
	player:SetAttribute("InventoryCount", #data.inventory)
	-- Pour l'affichage "Rien à voler" chez les autres joueurs (le serveur revalide au crochetage).
	local hasStealable = false
	for _, item in data.inventory do
		if StealConfig.NON_STEALABLE_RARITIES[item.rarity] ~= true then
			hasStealable = true
			break
		end
	end
	player:SetAttribute("HasStealableItem", hasStealable)
	player:SetAttribute("ShowDigHint", not data.digHintDone)
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
	inventoryUpdatedRemote = Remotes.get(Remotes.Names.InventoryUpdated)
end

function PlayerDataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerDataService
