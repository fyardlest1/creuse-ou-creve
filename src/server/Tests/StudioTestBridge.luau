--!strict
-- Pont de test, chargé uniquement dans Studio : expose les services vivants aux scripts de test
-- (barre de commande, MCP) via une BindableFunction dans ServerStorage, hors de portée des clients.
-- Usage : ServerStorage.StudioTestBridge:Invoke("EconomyService", "addCoins", player, 100, "Sell")
-- Aides : Invoke("Test", "getData", player), Invoke("Test", "setField", player, "coins", 0),
--         Invoke("Test", "setStat", player, "itemsSold", 0), Invoke("Test", "setFavorite", player, uid, true),
--         Invoke("Test", "teleport", player, position)
--         Invoke("Test", "giveFoundItem", player, "celestial_dragon_egg") -- vraie trouvaille, sans tirage
--         Invoke("Test", "removeItem", player, uid) -- la retire après le test
--         Invoke("Test", "startMeteorShower") -- pluie de météorites dans 10 s (annonce comprise)
--         Invoke("Test", "forceBloodNight") -- Nuit de sang dans 10 s (annonce comprise)

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local BRIDGE_NAME = "StudioTestBridge"

local StudioTestBridge = {}

function StudioTestBridge.install(services: { [string]: any })
	if not RunService:IsStudio() then
		return
	end
	local PlayerDataService = services.PlayerDataService
	local DigService = services.DigService
	local LootService = services.LootService
	local RetentionService = services.RetentionService
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Items = require(Shared.Config.Items)
	local Mutations = require(Shared.Config.Mutations)

	-- Objets donnés par giveFoundItem pendant cette session, avec ce qu'il faut pour les retirer proprement.
	type QuestSnapshot = { id: string, progress: number, claimed: boolean }
	local givenItems: {
		[string]: {
			itemId: string,
			rarity: string,
			indexBefore: { [string]: boolean }?,
			questsBefore: { QuestSnapshot },
		},
	} =
		{}

	local testHelpers = {
		startMeteorShower = function()
			services.MeteorService.startSoon()
		end,
		forceBloodNight = function()
			-- Le jour se termine dans WARNING_SECONDS, puis Nuit de sang annoncée : comme en jeu.
			local EventConfig = require(Shared.Config.EventConfig)
			services.DayNightService.forcePhase("Day", EventConfig.WARNING_SECONDS)
			services.DayNightService.setNextNightBlood(true)
		end,
		getData = function(player: Player): any
			return PlayerDataService.getData(player)
		end,
		setField = function(player: Player, field: string, value: any)
			local data = PlayerDataService.getData(player) :: any
			data[field] = value
			PlayerDataService.refreshAttributes(player)
		end,
		setStat = function(player: Player, field: string, value: any)
			local data = PlayerDataService.getData(player) :: any
			data.stats[field] = value
		end,
		setFavorite = function(player: Player, uid: string, favorite: boolean): boolean
			local data = PlayerDataService.getData(player) :: any
			for _, item in data.inventory do
				if item.uid == uid then
					item.favorite = favorite
					PlayerDataService.pushInventory(player)
					return true
				end
			end
			return false
		end,
		-- Rejoue la révélation (et l'annonce pour Légendaire et Secret) d'un objet, sans rien donner :
		-- vérification visuelle des moments forts.
		previewReveal = function(player: Player, itemId: string, rarity: string, mutation: string?)
			local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Remotes)
			Remotes.get(Remotes.Names.ItemRevealed):FireClient(player, {
				itemId = itemId,
				rarity = rarity,
				mutation = mutation,
				value = 0,
				inventoryCount = 0,
			})
			if rarity == "Legendary" or rarity == "Secret" then
				Remotes.get(Remotes.Names.ItemAnnounced)
					:FireAllClients(player.UserId, player.DisplayName, itemId, rarity)
			end
		end,
		-- Fait trouver un objet précis par le vrai chemin d'une trouvaille (coffre, révélation, annonce,
		-- Index, quêtes, badges, statistiques, aura de collectionneur), sans tirage : les probabilités ne
		-- sont pas touchées. Retourne l'uid de l'objet, à passer à removeItem après le test.
		giveFoundItem = function(player: Player, itemId: string, mutation: string?): string
			local data = PlayerDataService.getData(player) :: any
			assert(data ~= nil, "[StudioTestBridge] Profil pas encore chargé")
			local itemDef = Items.byId[itemId]
			assert(itemDef ~= nil, "[StudioTestBridge] Objet inconnu : " .. tostring(itemId))
			assert(
				mutation == nil or Mutations.byId[mutation :: any] ~= nil,
				"[StudioTestBridge] Mutation inconnue : " .. tostring(mutation)
			)
			local previous = data.index[itemId]
			local questsBefore: { QuestSnapshot } = {}
			for _, quest in data.quests.list do
				table.insert(questsBefore, { id = quest.id, progress = quest.progress, claimed = quest.claimed })
			end
			local item = LootService.makeItem(itemDef, mutation, itemDef.layer)
			assert(PlayerDataService.addItem(player, item), "[StudioTestBridge] Coffre plein")
			givenItems[item.uid] = {
				itemId = itemId,
				rarity = item.rarity,
				indexBefore = if previous ~= nil then table.clone(previous) else nil,
				questsBefore = questsBefore,
			}
			DigService.recordFind(player, data, item)
			return item.uid
		end,
		-- Retire un objet du coffre. S'il vient de giveFoundItem, annule aussi ce que la trouvaille a écrit
		-- dans le profil : statistiques, case de l'Index, progression des quêtes. Une quête que la trouvaille
		-- a terminée reste terminée (sa récompense est versée), et les badges Roblox ne sont pas repris.
		removeItem = function(player: Player, uid: string): boolean
			local data = PlayerDataService.getData(player) :: any
			assert(data ~= nil, "[StudioTestBridge] Profil pas encore chargé")
			local removed = false
			for index, item in data.inventory do
				if item.uid == uid then
					table.remove(data.inventory, index)
					removed = true
					break
				end
			end
			local given = givenItems[uid]
			if removed and given ~= nil then
				givenItems[uid] = nil
				data.stats.totalDigs = math.max(0, data.stats.totalDigs - 1)
				local count = data.stats.foundByRarity[given.rarity] or 0
				data.stats.foundByRarity[given.rarity] = math.max(0, count - 1)
				data.index[given.itemId] = given.indexBefore
				for index, before in given.questsBefore do
					local quest = data.quests.list[index]
					if quest ~= nil and quest.id == before.id and quest.claimed == before.claimed then
						quest.progress = before.progress
					end
				end
			end
			if removed then
				PlayerDataService.refreshAttributes(player)
				PlayerDataService.pushInventory(player)
				RetentionService.pushState(player) -- Index et quêtes à jour chez le client
			end
			return removed
		end,
		teleport = function(player: Player, position: Vector3)
			local character = player.Character
			if character ~= nil then
				character:PivotTo(CFrame.new(position))
			end
		end,
	}

	local bridge = Instance.new("BindableFunction")
	bridge.Name = BRIDGE_NAME
	bridge.OnInvoke = function(serviceName: string, methodName: string, ...: any): ...any
		local service = if serviceName == "Test" then testHelpers else services[serviceName]
		assert(service ~= nil, "[StudioTestBridge] Service inconnu : " .. tostring(serviceName))
		local method = service[methodName]
		assert(typeof(method) == "function", "[StudioTestBridge] Méthode inconnue : " .. tostring(methodName))
		return method(...)
	end
	bridge.Parent = ServerStorage
	print("[StudioTestBridge] Installé (Studio seulement)")
end

return StudioTestBridge
