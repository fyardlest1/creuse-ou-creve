--!strict
-- Reçoit les intentions de creusage, les valide et distribue le butin.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local PlotConfig = require(Shared.Config.PlotConfig)
local Items = require(Shared.Config.Items)
local Shovels = require(Shared.Config.Shovels)
local Remotes = require(Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local LootService = require(script.Parent.LootService)

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

local function clearLayer(player: Player, data: Types.PlayerData)
	data.layer += 1
	data.depth += PlotConfig.DEPTH_PER_LAYER
	PlayerDataService.refreshAttributes(player)
	remotes.layerCleared:FireClient(player, data.layer, data.depth)
	print(string.format("[DigService] %s passe à la couche %d (%d m)", player.Name, data.layer, data.depth))

	task.delay(PlotConfig.LAYER_RESET_DELAY, function()
		if player.Parent == Players then
			PlotService.resetLayer(player)
		end
	end)
end

local function digOut(player: Player, data: Types.PlayerData, cell: BasePart)
	PlotService.removeCell(cell)
	data.stats.totalDigs += 1

	local item = LootService.roll(player)
	if PlayerDataService.addItem(player, item) then
		data.stats.foundByRarity[item.rarity] = (data.stats.foundByRarity[item.rarity] or 0) + 1
		local payload: Types.RevealPayload = {
			itemId = item.itemId,
			name = Items.byId[item.itemId].name,
			rarity = item.rarity,
			mutation = item.mutation,
			value = item.value,
			inventoryCount = #data.inventory,
		}
		remotes.itemRevealed:FireClient(player, payload)
	else
		remotes.inventoryFull:FireClient(player)
	end

	if PlotService.countRemainingCells(player) == 0 then
		clearLayer(player, data)
	end
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

	local shovel = Shovels.byId[Shovels.DEFAULT_ID]
	local newHitsLeft = math.max(hitsLeft - shovel.power, 0)
	cell:SetAttribute(HITS_ATTRIBUTE, newHitsLeft)
	remotes.cellHit:FireClient(player, index, newHitsLeft)

	if newHitsLeft == 0 then
		digOut(player, data, cell)
	end
end

function DigService.init()
	remotes = {
		digRequest = Remotes.get(Remotes.Names.DigRequest),
		cellHit = Remotes.get(Remotes.Names.CellHit),
		itemRevealed = Remotes.get(Remotes.Names.ItemRevealed),
		inventoryFull = Remotes.get(Remotes.Names.InventoryFull),
		layerCleared = Remotes.get(Remotes.Names.LayerCleared),
	}
end

function DigService.start()
	remotes.digRequest.OnServerEvent:Connect(onDigRequest)
	Players.PlayerRemoving:Connect(function(player)
		lastHitTime[player] = nil
	end)
end

return DigService
