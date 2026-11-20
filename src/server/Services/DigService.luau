--!strict
-- Reçoit les intentions de creusage, les valide et distribue le butin.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local PlotConfig = require(Shared.Config.PlotConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local Items = require(Shared.Config.Items)
local Strata = require(Shared.Config.Strata)
local Remotes = require(Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local LootService = require(script.Parent.LootService)
local ShopService = require(script.Parent.ShopService)
local BoostService = require(script.Parent.BoostService)
local GameEvents = require(script.Parent.Parent.GameEvents)

local CELL_COUNT = PlotConfig.GRID_SIZE * PlotConfig.GRID_SIZE
local HITS_ATTRIBUTE = "HitsLeft"
local IS_STUDIO = RunService:IsStudio()

local DigService = {}

local lastHitTime: { [Player]: number } = {}
local remotes: {
	digRequest: RemoteEvent,
	cellHit: RemoteEvent,
	itemRevealed: RemoteEvent,
	inventoryFull: RemoteEvent,
	layerCleared: RemoteEvent,
	stratumBlocked: RemoteEvent,
	digSwing: RemoteEvent,
}

-- Les requêtes invalides sont ignorées, et loggées en Studio seulement.
local function reject(player: Player, reason: string)
	if IS_STUDIO then
		print(string.format("[DigService] Requête refusée (%s) : %s", player.Name, reason))
	end
end

local function isValidCellIndex(value: unknown): boolean
	return typeof(value) == "number"
		and value == value -- exclut NaN
		and value % 1 == 0
		and value >= 1
		and value <= CELL_COUNT
end

local function getCharacterPosition(player: Player): Vector3?
	local character = player.Character
	if character == nil then
		return nil
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end
	return rootPart.Position
end

-- Parcelle entièrement creusée : on descend de DEPTH_PER_LAYER, sauf si la couche suivante demande
-- une pelle que le joueur n'a pas. Dans ce cas la profondeur ne bouge pas, la parcelle se régénère
-- dans la couche actuelle et le client est prévenu (StratumBlocked).
local function clearLayer(player: Player, data: Types.PlayerData)
	local nextDepth = data.depth + PlotConfig.DEPTH_PER_LAYER
	local nextStratum = Strata.fromDepth(nextDepth)

	if table.find(data.ownedShovels, nextStratum.requiredShovel) == nil then
		remotes.stratumBlocked:FireClient(player, nextStratum.requiredShovel)
		print(
			string.format(
				"[DigService] %s bloqué à %d m : %s requise pour %s",
				player.Name,
				data.depth,
				nextStratum.requiredShovel,
				nextStratum.name
			)
		)
	else
		data.depth = nextDepth
		GameEvents.depthReached.fire(player, data.depth, nextStratum.id)
		PlayerDataService.refreshAttributes(player)
		remotes.layerCleared:FireClient(player, nextStratum.layer, data.depth)
		print(string.format("[DigService] %s descend à %d m (%s)", player.Name, data.depth, nextStratum.name))
	end

	task.delay(PlotConfig.LAYER_RESET_DELAY, function()
		if player.Parent == Players then
			PlotService.resetLayer(player)
		end
	end)
end

-- Retourne true si la case a été vidée. Un objet n'est jamais perdu : si l'ajout échoue,
-- la case garde un coup restant et le joueur est prévenu.
local function digOut(player: Player, data: Types.PlayerData, cell: BasePart, index: number): boolean
	local item = LootService.roll(player, BoostService.getLuckMultiplier(player))
	if not PlayerDataService.addItem(player, item) then
		cell:SetAttribute(HITS_ATTRIBUTE, 1)
		remotes.cellHit:FireClient(player, index, 1)
		remotes.inventoryFull:FireClient(player)
		return false
	end

	PlotService.removeCell(cell)
	remotes.cellHit:FireClient(player, index, 0)
	data.stats.totalDigs += 1
	data.stats.foundByRarity[item.rarity] = (data.stats.foundByRarity[item.rarity] or 0) + 1
	-- Indice de premier lancement : il disparaît pour toujours après les premiers objets trouvés.
	if not data.digHintDone and data.stats.totalDigs >= PlayerConfig.DIG_HINT_ITEM_COUNT then
		data.digHintDone = true
		PlayerDataService.refreshAttributes(player)
	end
	local payload: Types.RevealPayload = {
		itemId = item.itemId,
		name = Items.byId[item.itemId].name,
		rarity = item.rarity,
		mutation = item.mutation,
		value = item.value,
		inventoryCount = #data.inventory,
	}
	remotes.itemRevealed:FireClient(player, payload)
	GameEvents.itemFound.fire(player, item)

	if PlotService.countRemainingCells(player) == 0 then
		clearLayer(player, data)
	end
	return true
end

-- Un coup validé sur une case : geste chez tous les clients, puis la case perd des unités de travail.
local function applyHit(player: Player, data: Types.PlayerData, cell: BasePart, index: number, hitsLeft: number)
	-- Tous les clients animent le geste (le client du joueur l'a déjà joué s'il a cliqué).
	remotes.digSwing:FireAllClients(player)
	GameEvents.digHit.fire(player)

	local shovel = ShopService.getEquippedShovel(player)
	-- Une case vaut HITS_PER_CELL unités de travail ; la pelle la vide en hitsPerCell coups.
	local power = PlotConfig.HITS_PER_CELL / shovel.hitsPerCell
	local newHitsLeft = math.max(hitsLeft - power, 0)
	if newHitsLeft == 0 then
		digOut(player, data, cell, index)
		return
	end
	cell:SetAttribute(HITS_ATTRIBUTE, newHitsLeft)
	remotes.cellHit:FireClient(player, index, newHitsLeft)
end

local function onDigRequest(player: Player, cellIndex: unknown)
	if not isValidCellIndex(cellIndex) then
		reject(player, "index invalide " .. tostring(cellIndex))
		return
	end
	local index = cellIndex :: number

	local data = PlayerDataService.getData(player)
	if data == nil then
		reject(player, "données non chargées")
		return
	end

	-- getCell ne cherche que dans la parcelle du joueur : impossible de viser celle d'un autre.
	local cell = PlotService.getCell(player, index)
	if cell == nil then
		reject(player, "pas de parcelle")
		return
	end

	local hitsLeft = cell:GetAttribute(HITS_ATTRIBUTE)
	if typeof(hitsLeft) ~= "number" or hitsLeft <= 0 then
		reject(player, "case déjà creusée " .. index)
		return
	end

	local position = getCharacterPosition(player)
	if position == nil or (position - cell.Position).Magnitude > PlotConfig.MAX_DIG_DISTANCE then
		reject(player, "trop loin de la case " .. index)
		return
	end

	local now = os.clock()
	local last = lastHitTime[player]
	if last ~= nil and now - last < PlotConfig.DIG_COOLDOWN then
		reject(player, "cadence trop rapide")
		return
	end
	lastHitTime[player] = now

	-- Inventaire plein : on refuse le coup sans rien consommer, la case reste intacte.
	if #data.inventory >= PlayerDataService.getInventoryLimit(player) then
		reject(player, "inventaire plein")
		remotes.inventoryFull:FireClient(player)
		return
	end

	applyHit(player, data, cell, index, hitsLeft)
end

-- Coup automatique (pass Creusage auto, AutoDigService) : sur la première case intacte de la parcelle du
-- joueur, où qu'il soit. Pas de vérification de distance ni de la cadence manuelle : c'est le serveur qui
-- donne le coup, à son propre rythme. Retourne false si rien n'a été creusé (pas de case, coffre plein).
function DigService.autoHit(player: Player): boolean
	local data = PlayerDataService.getData(player)
	if data == nil or #data.inventory >= PlayerDataService.getInventoryLimit(player) then
		return false
	end
	for index = 1, CELL_COUNT do
		local cell = PlotService.getCell(player, index)
		local hitsLeft = if cell ~= nil then cell:GetAttribute(HITS_ATTRIBUTE) else nil
		if cell ~= nil and typeof(hitsLeft) == "number" and hitsLeft > 0 then
			applyHit(player, data, cell, index, hitsLeft)
			return true
		end
	end
	return false
end

function DigService.init()
	remotes = {
		digRequest = Remotes.get(Remotes.Names.DigRequest),
		cellHit = Remotes.get(Remotes.Names.CellHit),
		itemRevealed = Remotes.get(Remotes.Names.ItemRevealed),
		inventoryFull = Remotes.get(Remotes.Names.InventoryFull),
		layerCleared = Remotes.get(Remotes.Names.LayerCleared),
		stratumBlocked = Remotes.get(Remotes.Names.StratumBlocked),
		digSwing = Remotes.get(Remotes.Names.DigSwing),
	}
end

function DigService.start()
	remotes.digRequest.OnServerEvent:Connect(onDigRequest)
	Players.PlayerRemoving:Connect(function(player)
		lastHitTime[player] = nil
	end)
end

return DigService
