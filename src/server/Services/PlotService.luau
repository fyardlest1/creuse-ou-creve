--!strict
-- Génère les parcelles, les attribue aux joueurs et les remet à neuf.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlotConfig = require(Shared.Config.PlotConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local Strata = require(Shared.Config.Strata)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Locale = require(Shared.Locale)
local PlayerDataService = require(script.Parent.PlayerDataService)

type PlotState = {
	index: number,
	model: Model,
	origin: CFrame,
	spawnCFrame: CFrame,
	cells: { BasePart },
	signLabel: TextLabel,
	owner: Player?,
	characterConnection: RBXScriptConnection?,
}

local CELL_COUNT = PlotConfig.GRID_SIZE * PlotConfig.GRID_SIZE
local PLOT_WIDTH = PlotConfig.GRID_SIZE * PlotConfig.CELL_SIZE
local PLOT_PITCH = PLOT_WIDTH + PlotConfig.PLOT_SPACING
local ROW_PITCH = PLOT_WIDTH + PlotConfig.ROW_SPACING
local ROW_COUNT = math.ceil(PlotConfig.PLOT_COUNT / PlotConfig.PLOTS_PER_ROW)
local HITS_ATTRIBUTE = "HitsLeft"
local CHARACTER_WAIT_TIMEOUT = 5

local PlotService = {}

local rng = Random.new()
local plots: { PlotState } = {}
local plotByPlayer: { [Player]: PlotState } = {}
local plotAssignedRemote: RemoteEvent

local function log(message: string)
	print("[PlotService] " .. message)
end

local function getPlotCenter(index: number): Vector3
	local zeroBased = index - 1
	local column = zeroBased % PlotConfig.PLOTS_PER_ROW
	local row = zeroBased // PlotConfig.PLOTS_PER_ROW
	local x = (column - (PlotConfig.PLOTS_PER_ROW - 1) / 2) * PLOT_PITCH
	local z = (row - (ROW_COUNT - 1) / 2) * ROW_PITCH
	return PlotConfig.PLOT_ORIGIN + Vector3.new(x, 0, z)
end

-- Position du centre d'une case par rapport au centre de la parcelle (au niveau du sol).
local function getCellOffset(cellIndex: number): Vector3
	local zeroBased = cellIndex - 1
	local column = zeroBased % PlotConfig.GRID_SIZE
	local row = zeroBased // PlotConfig.GRID_SIZE
	local half = (PlotConfig.GRID_SIZE - 1) / 2
	return Vector3.new(
		(column - half) * PlotConfig.CELL_SIZE,
		PlotConfig.BASE_HEIGHT + PlotConfig.CELL_HEIGHT / 2,
		(row - half) * PlotConfig.CELL_SIZE
	)
end

-- Couleur d'une case : damier clair/foncé (les cases se touchent, c'est lui qui dessine la grille)
-- et petite variation aléatoire.
local function cellColor(baseColor: Color3, cellIndex: number): Color3
	local h, s, v = baseColor:ToHSV()
	local zeroBased = cellIndex - 1
	local isLight = (zeroBased % PlotConfig.GRID_SIZE + zeroBased // PlotConfig.GRID_SIZE) % 2 == 0
	local shade = if isLight then PlotConfig.CELL_CHECKER_SHADE else -PlotConfig.CELL_CHECKER_SHADE
	local variation = rng:NextNumber(-PlotConfig.CELL_COLOR_VARIATION, PlotConfig.CELL_COLOR_VARIATION)
	return Color3.fromHSV(h, s, math.clamp(v * (1 + shade + variation), 0, 1))
end

-- Remet une case à neuf, colorée selon la couche.
local function restoreCell(cell: BasePart, baseColor: Color3)
	cell:SetAttribute(HITS_ATTRIBUTE, PlotConfig.HITS_PER_CELL)
	cell.Transparency = 0
	cell.CanCollide = true
	cell.CanQuery = true
	cell.CanTouch = false
	local cellIndex = cell:GetAttribute("CellIndex")
	cell.Color = cellColor(baseColor, if typeof(cellIndex) == "number" then cellIndex else 1)
end

-- Couleur des cases pour la profondeur actuelle du joueur (Terre par défaut).
local function getCellColor(player: Player?): Color3
	local data = if player ~= nil then PlayerDataService.getData(player) else nil
	return Strata.fromDepth(if data ~= nil then data.depth else 0).cellColor
end

local function createPart(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function createGround(): Part
	local width = PlotConfig.PLOTS_PER_ROW * PLOT_PITCH + PlotConfig.GROUND_MARGIN * 2
	local depth = ROW_COUNT * ROW_PITCH + PlotConfig.GROUND_MARGIN * 2
	local ground = createPart(
		"Ground",
		Vector3.new(width, PlotConfig.GROUND_THICKNESS, depth),
		PlotConfig.PLOT_ORIGIN - Vector3.new(0, PlotConfig.GROUND_THICKNESS / 2, 0),
		PlotConfig.GROUND_COLOR,
		PlotConfig.GROUND_MATERIAL
	)
	ground.CanQuery = false
	return ground
end

local function createPlot(index: number, parent: Instance): PlotState
	local center = getPlotCenter(index)
	-- La rangée du fond s'ouvre vers l'arrière, celle de devant vers l'avant.
	local outward = if center.Z - PlotConfig.PLOT_ORIGIN.Z > 0 then 1 else -1

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)

	local base = createPart(
		"Base",
		Vector3.new(PLOT_WIDTH + 2, PlotConfig.BASE_HEIGHT, PLOT_WIDTH + 2),
		center + Vector3.new(0, PlotConfig.BASE_HEIGHT / 2, 0),
		PlotConfig.BASE_COLOR,
		PlotConfig.BASE_MATERIAL
	)
	base.Parent = model
	model.PrimaryPart = base

	local cellsFolder = Instance.new("Folder")
	cellsFolder.Name = "Cells"
	cellsFolder.Parent = model

	local cellSize = PlotConfig.CELL_SIZE
	local cells: { BasePart } = {}
	for cellIndex = 1, CELL_COUNT do
		local cell = createPart(
			tostring(cellIndex),
			Vector3.new(cellSize, PlotConfig.CELL_HEIGHT, cellSize),
			center + getCellOffset(cellIndex),
			getCellColor(nil),
			PlotConfig.CELL_MATERIAL
		)
		cell:SetAttribute("CellIndex", cellIndex)
		restoreCell(cell, getCellColor(nil))
		cell.Parent = cellsFolder
		cells[cellIndex] = cell
	end

	local signAnchor = Instance.new("Attachment")
	signAnchor.Name = "SignAnchor"
	signAnchor.Position = Vector3.new(0, PlotConfig.SIGN_HEIGHT, outward * (PLOT_WIDTH / 2 + 1))
	signAnchor.Parent = base

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromScale(PlotConfig.SIGN_WIDTH, PlotConfig.SIGN_TEXT_HEIGHT) -- en studs
	billboard.MaxDistance = PlotConfig.SIGN_MAX_DISTANCE
	billboard.Active = false
	billboard.Adornee = signAnchor
	CollectionService:AddTag(billboard, WorldConfig.SIGN_TAG) -- gardé sous le HUD par WorldSignController
	billboard.Parent = signAnchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	Locale.bind(label, "Text", Locale.text("plot.free"))
	label.Parent = billboard

	local spawnPosition = center
		+ Vector3.new(0, PlotConfig.SPAWN_HEIGHT, outward * (PLOT_WIDTH / 2 + 1 + PlotConfig.SPAWN_OFFSET))
	local spawnCFrame = CFrame.lookAt(spawnPosition, Vector3.new(center.X, spawnPosition.Y, center.Z))

	model.Parent = parent

	return {
		index = index,
		model = model,
		origin = CFrame.new(center + Vector3.new(0, PlotConfig.BASE_HEIGHT, 0)),
		spawnCFrame = spawnCFrame,
		cells = cells,
		signLabel = label,
		owner = nil,
		characterConnection = nil,
	}
end

local function teleportToPlot(plot: PlotState, character: Model)
	local rootPart = character:WaitForChild("HumanoidRootPart", CHARACTER_WAIT_TIMEOUT)
	if rootPart == nil then
		return
	end
	-- À la réapparition, le moteur place le personnage sur le point d'apparition par défaut
	-- après CharacterAdded : on attend qu'il soit dans le Workspace, puis une frame, avant de téléporter.
	if not character:IsDescendantOf(Workspace) then
		character.AncestryChanged:Wait()
	end
	RunService.Heartbeat:Wait()
	if plot.owner == nil or character.Parent == nil then
		return
	end
	character:PivotTo(plot.spawnCFrame)
end

local function assignPlot(player: Player, _data: Types.PlayerData)
	if plotByPlayer[player] ~= nil or player.Parent ~= Players then
		return
	end

	local freePlot: PlotState? = nil
	for _, candidate in plots do
		if candidate.owner == nil then
			freePlot = candidate
			break
		end
	end
	if freePlot == nil then
		warn("[PlotService] Aucune parcelle libre pour " .. player.Name)
		return
	end
	local plot: PlotState = freePlot

	plot.owner = player
	plotByPlayer[player] = plot
	plot.model:SetAttribute("OwnerUserId", player.UserId)
	Locale.bind(plot.signLabel, "Text", Locale.text("plot.owned", player.DisplayName))
	local color = getCellColor(player)
	for _, cell in plot.cells do
		restoreCell(cell, color)
	end

	plot.characterConnection = player.CharacterAdded:Connect(function(character)
		teleportToPlot(plot, character)
	end)
	if player.Character ~= nil then
		task.spawn(teleportToPlot, plot, player.Character)
	end

	plotAssignedRemote:FireClient(player, plot.index, plot.origin)
	log(string.format("Parcelle %d attribuée à %s", plot.index, player.Name))
end

local function releasePlot(player: Player)
	local plot = plotByPlayer[player]
	if plot == nil then
		return
	end
	plotByPlayer[player] = nil
	if plot.characterConnection ~= nil then
		plot.characterConnection:Disconnect()
		plot.characterConnection = nil
	end
	plot.owner = nil
	plot.model:SetAttribute("OwnerUserId", 0)
	Locale.bind(plot.signLabel, "Text", Locale.text("plot.free"))
	local color = getCellColor(nil)
	for _, cell in plot.cells do
		restoreCell(cell, color)
	end
	log(string.format("Parcelle %d libérée", plot.index))
end

-- Disposition de chaque parcelle, pour placer les décors (coffres). outward vaut 1 ou -1 selon le côté
-- vers lequel la parcelle s'ouvre (là où le joueur apparaît).
function PlotService.getPlotLayouts(): { { model: Model, center: Vector3, outward: number } }
	local layouts = {}
	for _, plot in plots do
		local center = getPlotCenter(plot.index)
		local outward = if center.Z - PlotConfig.PLOT_ORIGIN.Z > 0 then 1 else -1
		table.insert(layouts, { model = plot.model, center = center, outward = outward })
	end
	return layouts
end

-- Modèle de la parcelle du joueur, ou nil.
function PlotService.getPlot(player: Player): Model?
	local plot = plotByPlayer[player]
	return if plot ~= nil then plot.model else nil
end

-- Case de la parcelle du joueur, ou nil si l'index est invalide ou si le joueur n'a pas de parcelle.
function PlotService.getCell(player: Player, cellIndex: number): BasePart?
	local plot = plotByPlayer[player]
	if plot == nil then
		return nil
	end
	return plot.cells[cellIndex]
end

-- Remet toutes les cases de la parcelle du joueur à neuf, à la couleur de sa couche actuelle.
function PlotService.resetLayer(player: Player)
	local plot = plotByPlayer[player]
	if plot == nil then
		return
	end
	local color = getCellColor(player)
	for _, cell in plot.cells do
		restoreCell(cell, color)
	end
end

-- Fait disparaître une case creusée (elle reste en mémoire pour la couche suivante).
function PlotService.removeCell(cell: BasePart)
	cell:SetAttribute(HITS_ATTRIBUTE, 0)
	cell.Transparency = 1
	cell.CanCollide = false
	cell.CanQuery = false
end

-- Nombre de cases encore intactes sur la parcelle du joueur.
function PlotService.countRemainingCells(player: Player): number
	local plot = plotByPlayer[player]
	if plot == nil then
		return 0
	end
	local remaining = 0
	for _, cell in plot.cells do
		local hitsLeft = cell:GetAttribute(HITS_ATTRIBUTE)
		if typeof(hitsLeft) == "number" and hitsLeft > 0 then
			remaining += 1
		end
	end
	return remaining
end

function PlotService.init()
	plotAssignedRemote = Remotes.get(Remotes.Names.PlotAssigned)

	for _, name in { "Plots", "Ground" } do
		local existing = Workspace:FindFirstChild(name)
		if existing ~= nil then
			existing:Destroy()
		end
	end

	createGround().Parent = Workspace

	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	for index = 1, PlotConfig.PLOT_COUNT do
		plots[index] = createPlot(index, folder)
	end
	folder.Parent = Workspace
	log(string.format("%d parcelles générées", #plots))
end

function PlotService.start()
	PlayerDataService.onLoaded(assignPlot)
	Players.PlayerRemoving:Connect(releasePlot)
end

return PlotService
