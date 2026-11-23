--!strict
-- Génère le décor interactif : stand du Marchand, stand de la Forge, salon VIP, Repaire des Voleurs
-- et un coffre par parcelle.
-- Chaque interaction passe par un ProximityPrompt (la bonne interaction sur mobile).

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlotConfig = require(Shared.Config.PlotConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local DayNightConfig = require(Shared.Config.DayNightConfig)
local StealConfig = require(Shared.Config.StealConfig)
local Locale = require(Shared.Locale)
local PlotService = require(script.Parent.PlotService)
local DayNightService = require(script.Parent.DayNightService)
local PlayerDataService = require(script.Parent.PlayerDataService)

type StandStyle = {
	name: string,
	title: string, -- clé Locale
	action: string, -- clé Locale
	interaction: string,
	color: Color3,
	roofColor: Color3,
}

local FOLDER_NAME = "Stands"

local WorldService = {}

-- Fumée noire de chaque coffre (par parcelle), visible par tous la nuit si le coffre contient un Maudit.
local cursedSmoke: { [Model]: ParticleEmitter } = {}

-- Prompts "Crocheter" de chaque coffre, avec la parcelle qui les porte (écoutés par StealService).
local pickPrompts: { { plot: Model, prompt: ProximityPrompt } } = {}

-- Lanternes des coffres : la partie lumineuse et sa lumière, allumées la nuit.
local lanterns: { { glass: BasePart, light: PointLight } } = {}

local merchantPosition: Vector3
local forgePosition: Vector3
local vipMerchantPosition: Vector3
local thiefShopPosition: Vector3
local vipLoungeBox: CFrame -- centre de l'intérieur du salon VIP (taille : getVipLoungeBox)
local vipLoungeExit: Vector3 -- devant la porte, dehors
local vipDoor: BasePart

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

-- objectKey et actionKey : clés Locale (chaque client traduit le prompt dans sa langue).
local function createPrompt(
	parent: Instance,
	objectKey: string,
	actionKey: string,
	interaction: string
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	Locale.bind(prompt, "ObjectText", Locale.text(objectKey))
	Locale.bind(prompt, "ActionText", Locale.text(actionKey))
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = WorldConfig.PROMPT_MAX_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = WorldConfig.PROMPT_KEY
	prompt:SetAttribute(WorldConfig.INTERACTION_ATTRIBUTE, interaction)
	prompt.Parent = parent
	return prompt
end

local function createSign(anchor: Attachment, textKey: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromScale(WorldConfig.STAND_SIGN_WIDTH, WorldConfig.STAND_SIGN_TEXT_HEIGHT) -- en studs
	billboard.MaxDistance = WorldConfig.STAND_SIGN_MAX_DISTANCE
	billboard.Active = false
	billboard.Adornee = anchor
	CollectionService:AddTag(billboard, WorldConfig.SIGN_TAG) -- gardé sous le HUD par WorldSignController
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	Locale.bind(label, "Text", Locale.text(textKey))
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

	createPrompt(body, "world.chest", "world.openChest", WorldConfig.INTERACTIONS.Chest)

	-- Second prompt, distinct : "Crocheter" (un toucher ouvre le mini-jeu). Le client ne l'affiche que sur
	-- les coffres des autres, la nuit ; le serveur revalide tout (StealService).
	local pick = createPrompt(body, "world.chest", "world.pick", WorldConfig.INTERACTIONS.Pick)
	pick.MaxActivationDistance = StealConfig.PICK_MAX_DISTANCE
	pick.UIOffset = WorldConfig.PICK_PROMPT_OFFSET
	table.insert(pickPrompts, { plot = plotModel, prompt = pick })

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "CursedSmoke"
	smoke.Color = ColorSequence.new(WorldConfig.CURSED_SMOKE_COLOR)
	smoke.Size = NumberSequence.new(WorldConfig.CURSED_SMOKE_SIZE_START, WorldConfig.CURSED_SMOKE_SIZE_END)
	smoke.Texture = WorldConfig.CURSED_SMOKE_TEXTURE
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, WorldConfig.CURSED_SMOKE_TRANSPARENCY),
		NumberSequenceKeypoint.new(0.7, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.LightInfluence = 0 -- pas assombrie par la nuit
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-30, 30)
	smoke.Lifetime = NumberRange.new(WorldConfig.CURSED_SMOKE_LIFETIME)
	smoke.Rate = WorldConfig.CURSED_SMOKE_RATE
	smoke.Speed = NumberRange.new(WorldConfig.CURSED_SMOKE_SPEED)
	smoke.SpreadAngle = Vector2.new(15, 15)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Enabled = false
	smoke.Parent = body
	cursedSmoke[plotModel] = smoke

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

-- Salon VIP : sol à tapis rouge, trois murs pleins, un mur avec une porte dorée (franchissable par
-- les seuls VIP, voir VipLoungeService), piliers dorés éclairés et Marchand VIP à l'intérieur.
local function createVipLounge(center: Vector3, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "VipLounge"
	local inner = WorldConfig.VIP_LOUNGE_SIZE
	local wall = WorldConfig.VIP_WALL_THICKNESS
	local floorHeight = WorldConfig.VIP_FLOOR_HEIGHT
	local halfX, halfZ = inner.X / 2, inner.Z / 2

	local floor = createPart(
		"Carpet",
		Vector3.new(inner.X + 2 * wall, floorHeight, inner.Z + 2 * wall),
		CFrame.new(center + Vector3.new(0, floorHeight / 2, 0)),
		WorldConfig.VIP_CARPET_COLOR,
		Enum.Material.Fabric
	)
	floor.Parent = model
	model.PrimaryPart = floor

	local wallY = floorHeight + inner.Y / 2
	local function addWall(name: string, size: Vector3, offset: Vector3)
		local part =
			createPart(name, size, CFrame.new(center + offset), WorldConfig.VIP_WALL_COLOR, Enum.Material.SmoothPlastic)
		part.Parent = model
	end
	-- Murs du fond (-X) et des côtés (±Z), pleins.
	addWall("WallBack", Vector3.new(wall, inner.Y, inner.Z + 2 * wall), Vector3.new(-halfX - wall / 2, wallY, 0))
	for _, side in { -1, 1 } do
		addWall("WallSide", Vector3.new(inner.X, inner.Y, wall), Vector3.new(0, wallY, side * (halfZ + wall / 2)))
	end
	-- Mur de façade (+X) : deux pans de chaque côté de la porte.
	local doorWidth = WorldConfig.VIP_DOOR_WIDTH
	local panelWidth = (inner.Z + 2 * wall - doorWidth) / 2
	for _, side in { -1, 1 } do
		addWall(
			"WallFront",
			Vector3.new(wall, inner.Y, panelWidth),
			Vector3.new(halfX + wall / 2, wallY, side * (doorWidth / 2 + panelWidth / 2))
		)
	end
	local door = createPart(
		"VipDoor",
		Vector3.new(wall, inner.Y, doorWidth),
		CFrame.new(center + Vector3.new(halfX + wall / 2, wallY, 0)),
		WorldConfig.VIP_TRIM_COLOR,
		Enum.Material.ForceField
	)
	door.Transparency = WorldConfig.VIP_DOOR_TRANSPARENCY
	-- Groupes de collision : la porte ne bloque pas les personnages VIP (VipLoungeService les y range).
	for _, group in { WorldConfig.VIP_DOOR_COLLISION_GROUP, WorldConfig.VIP_MEMBER_COLLISION_GROUP } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(
		WorldConfig.VIP_DOOR_COLLISION_GROUP,
		WorldConfig.VIP_MEMBER_COLLISION_GROUP,
		false
	)
	door.CollisionGroup = WorldConfig.VIP_DOOR_COLLISION_GROUP
	door.Parent = model
	vipDoor = door

	-- Piliers dorés aux coins de la façade, avec une lumière chaude.
	local pillarSize = WorldConfig.VIP_PILLAR_SIZE
	for _, side in { -1, 1 } do
		local pillar = createPart(
			"Pillar",
			pillarSize,
			CFrame.new(
				center + Vector3.new(halfX + wall / 2, floorHeight + pillarSize.Y / 2, side * (halfZ + wall / 2))
			),
			WorldConfig.VIP_TRIM_COLOR,
			Enum.Material.Metal
		)
		local light = Instance.new("PointLight")
		light.Range = WorldConfig.VIP_LIGHT_RANGE
		light.Brightness = WorldConfig.VIP_LIGHT_BRIGHTNESS
		light.Color = WorldConfig.VIP_TRIM_COLOR
		light.Parent = pillar
		pillar.Parent = model
	end

	-- Panneau au-dessus de la porte, lisible depuis le Marchand.
	local signAnchor = Instance.new("Attachment")
	signAnchor.Name = "SignAnchor"
	signAnchor.Parent = floor
	signAnchor.WorldPosition = center + Vector3.new(halfX + wall, WorldConfig.VIP_SIGN_HEIGHT, 0)
	createSign(signAnchor, "world.vipLounge")

	-- Marchand VIP, au fond, tourné vers la porte. Son prompt est réservé aux VIP.
	local stand = createStand(
		{
			name = "VipMerchant",
			title = "world.vipMerchant",
			action = "world.sell",
			interaction = WorldConfig.INTERACTIONS.Merchant,
			color = WorldConfig.VIP_MERCHANT_COLOR,
			roofColor = WorldConfig.VIP_MERCHANT_ROOF_COLOR,
		},
		center + WorldConfig.VIP_MERCHANT_OFFSET + Vector3.new(0, floorHeight, 0),
		center + Vector3.new(inner.X, 0, 0),
		model
	)
	local prompt = stand:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt ~= nil then
		prompt.MaxActivationDistance = WorldConfig.VIP_PROMPT_MAX_DISTANCE
		CollectionService:AddTag(prompt, WorldConfig.VIP_ONLY_TAG)
	end
	vipMerchantPosition = (stand:FindFirstChild("Counter") :: BasePart).Position

	vipLoungeBox = CFrame.new(center + Vector3.new(0, floorHeight + inner.Y / 2, 0))
	vipLoungeExit = center + Vector3.new(halfX + wall + WorldConfig.VIP_EVICT_DISTANCE, PlotConfig.SPAWN_HEIGHT, 0)
	model.Parent = parent
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

-- Comptoir du Marchand VIP (vente réservée aux VIP, même règle de distance).
function WorldService.getVipMerchantPosition(): Vector3
	return vipMerchantPosition
end

-- Comptoir du Repaire des Voleurs (achat de cosmétiques).
function WorldService.getThiefShopPosition(): Vector3
	return thiefShopPosition
end

-- Intérieur du salon VIP (centre et taille), point de sortie devant la porte, et la porte.
function WorldService.getVipLoungeBox(): (CFrame, Vector3)
	return vipLoungeBox, WorldConfig.VIP_LOUNGE_SIZE
end

function WorldService.getVipLoungeExit(): Vector3
	return vipLoungeExit
end

function WorldService.getVipDoor(): BasePart
	return vipDoor
end

-- Position du comptoir de la Forge, pour la validation de distance côté serveur.
function WorldService.getForgePosition(): Vector3
	return forgePosition
end

local function hasCursedItem(player: Player): boolean
	local data = PlayerDataService.getData(player)
	if data == nil then
		return false
	end
	for _, item in data.inventory do
		if item.mutation == "Cursed" then
			return true
		end
	end
	return false
end

-- Fumée : la nuit, sur les coffres dont le propriétaire garde un objet Maudit.
local function refreshCursedSmoke()
	local night = DayNightService.isNight()
	for plot, smoke in cursedSmoke do
		local ownerId = plot:GetAttribute("OwnerUserId")
		local owner = if typeof(ownerId) == "number" and ownerId ~= 0 then Players:GetPlayerByUserId(ownerId) else nil
		smoke.Enabled = night and owner ~= nil and hasCursedItem(owner)
	end
end

-- Prompts "Crocheter" de tous les coffres, avec leur parcelle.
function WorldService.getPickPrompts(): { { plot: Model, prompt: ProximityPrompt } }
	return pickPrompts
end

-- Garde du corps : un garde PNJ se tient près du coffre de ce joueur (visible par tous), retiré à son départ.
local bodyguards: { [Player]: Model } = {}
function WorldService.setBodyguard(player: Player, enabled: boolean)
	local existing = bodyguards[player]
	if existing ~= nil then
		existing:Destroy()
		bodyguards[player] = nil
	end
	local chest = WorldService.getChest(player)
	local body = if chest ~= nil then chest.PrimaryPart else nil
	if not enabled or body == nil then
		return
	end
	local ok, guard = pcall(function()
		local description = Instance.new("HumanoidDescription")
		for _, part in { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
			(description :: any)[part .. "Color"] = WorldConfig.BODYGUARD_COLOR
		end
		description.HeadColor = WorldConfig.BODYGUARD_SKIN_COLOR
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or guard == nil then
		warn("[WorldService] Garde du corps impossible à créer : " .. tostring(guard))
		return
	end
	local model = guard :: Model
	model.Name = "Bodyguard"
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		Locale.bind(humanoid, "DisplayName", Locale.text("world.bodyguard"))
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	-- À côté du coffre, de l'autre côté de la lanterne (décalages dans le repère du monde), tourné vers
	-- l'extérieur comme le coffre.
	local position = body.Position + WorldConfig.BODYGUARD_OFFSET
	model:PivotTo(CFrame.lookAt(position, position + body.CFrame.LookVector))
	model.Parent = chest
	bodyguards[player] = model
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
		title = "world.merchant",
		action = "world.sell",
		interaction = WorldConfig.INTERACTIONS.Merchant,
		color = WorldConfig.MERCHANT_COLOR,
		roofColor = WorldConfig.MERCHANT_ROOF_COLOR,
	}, origin + WorldConfig.MERCHANT_OFFSET, origin, folder)

	local forge = createStand({
		name = "Forge",
		title = "world.forge",
		action = "world.buyShovel",
		interaction = WorldConfig.INTERACTIONS.Forge,
		color = WorldConfig.FORGE_COLOR,
		roofColor = WorldConfig.FORGE_ROOF_COLOR,
	}, origin + WorldConfig.FORGE_OFFSET, origin, folder)

	local thiefShop = createStand({
		name = "ThiefShop",
		title = "world.thiefShop",
		action = "world.openThiefShop",
		interaction = WorldConfig.INTERACTIONS.ThiefShop,
		color = WorldConfig.THIEF_SHOP_COLOR,
		roofColor = WorldConfig.THIEF_SHOP_ROOF_COLOR,
	}, origin + WorldConfig.THIEF_SHOP_OFFSET, origin, folder)

	createVipLounge(origin + WorldConfig.VIP_LOUNGE_OFFSET, folder)

	merchantPosition = (merchant:FindFirstChild("Counter") :: BasePart).Position
	forgePosition = (forge:FindFirstChild("Counter") :: BasePart).Position
	thiefShopPosition = (thiefShop:FindFirstChild("Counter") :: BasePart).Position
	folder.Parent = Workspace

	-- PlotService.init() a déjà généré les parcelles.
	for _, layout in PlotService.getPlotLayouts() do
		createChest(layout.model, layout.center, layout.outward)
	end
	print("[WorldService] Marchand, Forge, salon VIP, Repaire des Voleurs et coffres générés")
end

function WorldService.start()
	Players.PlayerRemoving:Connect(function(player)
		WorldService.setBodyguard(player, false)
	end)
	setLanterns(DayNightService.isNight())
	DayNightService.onPhaseChanged(function(phase)
		setLanterns(phase == "Night")
		refreshCursedSmoke()
	end)
	task.spawn(function()
		while true do
			refreshCursedSmoke()
			task.wait(WorldConfig.CURSED_SMOKE_REFRESH_INTERVAL)
		end
	end)
end

return WorldService
