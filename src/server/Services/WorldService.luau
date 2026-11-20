--!strict
-- Génère le décor interactif : stand du Marchand, stand de la Forge et un coffre par parcelle.
-- Chaque interaction passe par un ProximityPrompt (la bonne interaction sur mobile).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlotConfig = require(Shared.Config.PlotConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local DayNightConfig = require(Shared.Config.DayNightConfig)
local PlotService = require(script.Parent.PlotService)
local DayNightService = require(script.Parent.DayNightService)

type StandStyle = {
	name: string,
	title: string,
	action: string,
	interaction: string,
	color: Color3,
	roofColor: Color3,
}

local FOLDER_NAME = "Stands"

local WorldService = {}

-- Lanternes des coffres : la partie lumineuse et sa lumière, allumées la nuit.
local lanterns: { { glass: BasePart, light: PointLight } } = {}

local merchantPosition: Vector3
local forgePosition: Vector3

local function createPart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function createPrompt(parent: Instance, objectText: string, actionText: string, interaction: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = WorldConfig.PROMPT_MAX_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = WorldConfig.PROMPT_KEY
	prompt:SetAttribute(WorldConfig.INTERACTION_ATTRIBUTE, interaction)
	prompt.Parent = parent
end

local function createSign(anchor: Attachment, text: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromScale(WorldConfig.STAND_SIGN_WIDTH, WorldConfig.STAND_SIGN_TEXT_HEIGHT) -- en studs
	billboard.MaxDistance = WorldConfig.STAND_SIGN_MAX_DISTANCE
	billboard.Active = false
	billboard.Adornee = anchor
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = billboard
end

-- Stand simple : plancher, comptoir à l'avant, deux poteaux, toit et panneau. L'avant regarde `facing`.
local function createStand(style: StandStyle, position: Vector3, facing: Vector3, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = style.name
	local frame = CFrame.lookAt(position, Vector3.new(facing.X, position.Y, facing.Z))

	local floorSize = WorldConfig.STAND_FLOOR_SIZE
	local floor = createPart(
		"Floor",
		floorSize,
		frame * CFrame.new(0, floorSize.Y / 2, 0),
		WorldConfig.STAND_WOOD_COLOR,
		Enum.Material.WoodPlanks
	)
	floor.Parent = model
	model.PrimaryPart = floor

	local counterSize = WorldConfig.STAND_COUNTER_SIZE
	local counter = createPart(
		"Counter",
		counterSize,
		frame * CFrame.new(0, floorSize.Y + counterSize.Y / 2, -(floorSize.Z / 2 - counterSize.Z / 2)),
		style.color,
		Enum.Material.SmoothPlastic
	)
	counter.Parent = model

	local postSize = WorldConfig.STAND_POST_SIZE
	for _, side in { -1, 1 } do
		local post = createPart(
			"Post",
			postSize,
			frame
				* CFrame.new(
					side * (floorSize.X / 2 - postSize.X / 2),
					floorSize.Y + postSize.Y / 2,
					floorSize.Z / 2 - postSize.Z / 2
				),
			WorldConfig.STAND_WOOD_COLOR,
			Enum.Material.Wood
		)
		post.Parent = model
	end

	local roofSize = WorldConfig.STAND_ROOF_SIZE
	local roof = createPart(
		"Roof",
		roofSize,
		frame * CFrame.new(0, floorSize.Y + postSize.Y + roofSize.Y / 2, 0),
		style.roofColor,
		Enum.Material.Fabric
	)
	roof.Parent = model

	local signAnchor = Instance.new("Attachment")
	signAnchor.Name = "SignAnchor"
	signAnchor.Position = Vector3.new(0, WorldConfig.STAND_SIGN_HEIGHT - floorSize.Y / 2, 0)
	signAnchor.Parent = floor
	createSign(signAnchor, style.title)

	local promptAnchor = Instance.new("Attachment")
	promptAnchor.Name = "PromptAnchor"
	promptAnchor.Position = Vector3.new(0, counterSize.Y / 2, 0)
	promptAnchor.Parent = counter
	createPrompt(promptAnchor, style.title, style.action, style.interaction)

	model.Parent = parent
	return model
end

-- Coffre au bord extérieur de la parcelle, rangé dans le modèle de la parcelle (son propriétaire est
-- l'attribut OwnerUserId de la parcelle).
local function createChest(plotModel: Model, center: Vector3, outward: number)
	local plotHalfWidth = PlotConfig.GRID_SIZE * PlotConfig.CELL_SIZE / 2
	local size = WorldConfig.CHEST_SIZE
	local position = center
		+ Vector3.new(
			WorldConfig.CHEST_SIDE_OFFSET,
			size.Y / 2,
			outward * (plotHalfWidth + WorldConfig.CHEST_EDGE_OFFSET)
		)
	-- Le devant du coffre regarde vers l'extérieur, là où le joueur apparaît.
	local frame = CFrame.lookAt(position, position + Vector3.new(0, 0, outward))

	local model = Instance.new("Model")
	model.Name = "Chest"

	local body = createPart("Body", size, frame, WorldConfig.CHEST_COLOR, Enum.Material.WoodPlanks)
	body.Parent = model
	model.PrimaryPart = body

	local lid = createPart(
		"Lid",
		Vector3.new(size.X + 0.2, WorldConfig.CHEST_LID_HEIGHT, size.Z + 0.2),
		frame * CFrame.new(0, size.Y / 2 + WorldConfig.CHEST_LID_HEIGHT / 2, 0),
		WorldConfig.CHEST_TRIM_COLOR,
		Enum.Material.Metal
	)
	lid.Parent = model

	createPrompt(body, WorldConfig.CHEST_TITLE, WorldConfig.CHEST_ACTION, WorldConfig.INTERACTIONS.Chest)

	-- Lanterne à côté du coffre, allumée la nuit (le serveur l'allume : tout le monde la voit).
	local postSize = DayNightConfig.LANTERN_POST_SIZE
	local base = position - Vector3.new(0, size.Y / 2, 0) + DayNightConfig.LANTERN_OFFSET
	local post = createPart(
		"LanternPost",
		postSize,
		CFrame.new(base + Vector3.new(0, postSize.Y / 2, 0)),
		WorldConfig.STAND_WOOD_COLOR,
		Enum.Material.Wood
	)
	post.Parent = model
	local glass = createPart(
		"Lantern",
		DayNightConfig.LANTERN_SIZE,
		CFrame.new(base + Vector3.new(0, postSize.Y + DayNightConfig.LANTERN_SIZE.Y / 2, 0)),
		DayNightConfig.LANTERN_COLOR_OFF,
		Enum.Material.SmoothPlastic
	)
	glass.Parent = model
	local light = Instance.new("PointLight")
	light.Range = DayNightConfig.LANTERN_LIGHT_RANGE
	light.Brightness = DayNightConfig.LANTERN_LIGHT_BRIGHTNESS
	light.Color = DayNightConfig.LANTERN_COLOR_ON
	light.Enabled = false
	light.Parent = glass
	table.insert(lanterns, { glass = glass, light = light })

	model.Parent = plotModel
end

local function setLanterns(on: boolean)
	for _, lantern in lanterns do
		lantern.light.Enabled = on
		lantern.glass.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		lantern.glass.Color = if on then DayNightConfig.LANTERN_COLOR_ON else DayNightConfig.LANTERN_COLOR_OFF
	end
end

-- Position du comptoir du Marchand, pour la validation de distance côté serveur.
function WorldService.getMerchantPosition(): Vector3
	return merchantPosition
end

-- Position du comptoir de la Forge, pour la validation de distance côté serveur.
function WorldService.getForgePosition(): Vector3
	return forgePosition
end

-- Coffre de la parcelle d'un joueur, ou nil.
function WorldService.getChest(player: Player): Model?
	local plot = PlotService.getPlot(player)
	if plot == nil then
		return nil
	end
	local chest = plot:FindFirstChild("Chest")
	return if chest ~= nil and chest:IsA("Model") then chest else nil
end

function WorldService.init()
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	local origin = PlotConfig.PLOT_ORIGIN

	local merchant = createStand({
		name = "Merchant",
		title = WorldConfig.MERCHANT_TITLE,
		action = WorldConfig.MERCHANT_ACTION,
		interaction = WorldConfig.INTERACTIONS.Merchant,
		color = WorldConfig.MERCHANT_COLOR,
		roofColor = WorldConfig.MERCHANT_ROOF_COLOR,
	}, origin + WorldConfig.MERCHANT_OFFSET, origin, folder)

	local forge = createStand({
		name = "Forge",
		title = WorldConfig.FORGE_TITLE,
		action = WorldConfig.FORGE_ACTION,
		interaction = WorldConfig.INTERACTIONS.Forge,
		color = WorldConfig.FORGE_COLOR,
		roofColor = WorldConfig.FORGE_ROOF_COLOR,
	}, origin + WorldConfig.FORGE_OFFSET, origin, folder)

	merchantPosition = (merchant:FindFirstChild("Counter") :: BasePart).Position
	forgePosition = (forge:FindFirstChild("Counter") :: BasePart).Position
	folder.Parent = Workspace

	-- PlotService.init() a déjà généré les parcelles.
	for _, layout in PlotService.getPlotLayouts() do
		createChest(layout.model, layout.center, layout.outward)
	end
	print("[WorldService] Marchand, Forge et coffres générés")
end

function WorldService.start()
	setLanterns(DayNightService.isNight())
	DayNightService.onPhaseChanged(function(phase)
		setLanterns(phase == "Night")
	end)
end

return WorldService
