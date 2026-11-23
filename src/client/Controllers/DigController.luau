--!strict
-- Clic ou toucher sur une case de sa parcelle : envoie l'intention au serveur
-- et joue tout de suite un petit retour local (secousse, terre, son).
-- Maintenir l'appui enchaîne les coups à la cadence du serveur, en suivant le curseur.
-- La case visée (intacte, sur sa parcelle, à portée) est mise en surbrillance.

local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlotConfig = require(Shared.Config.PlotConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local UiConfig = require(Shared.Config.UiConfig)
local AudioConfig = require(Shared.Config.AudioConfig)
local AudioKit = require(script.Parent.Parent.AudioKit)
local Remotes = require(Shared.Remotes)
local ShovelController = require(script.Parent.ShovelController)

local RAY_LENGTH = 1000

local player = Players.LocalPlayer

-- Places du coffre (30, ou 60 avec Coffre agrandi), publiées par le serveur.
local function getInventoryLimit(): number
	local limit = player:GetAttribute("InventoryLimit")
	return if typeof(limit) == "number" then limit else PlayerConfig.INVENTORY_LIMIT
end

local DigController = {}

local digRequest: RemoteEvent
local cellHit: RemoteEvent
local plotAssigned: RemoteEvent
local myPlot: Model? = nil
local plotOrigin: CFrame? = nil
local lastRequestTime = -math.huge
local restCFrames: { [BasePart]: CFrame } = {}
local hitSounds: { Sound } = {} -- variantes du coup de pelle, jouées au hasard
local soundRng = Random.new()
local highlight: SelectionBox
-- Appui en cours (souris ou doigt) et position du curseur, en coordonnées d'écran (hors barre Roblox).
local holdInput: InputObject? = nil
local holdPosition = Vector2.zero

local function findOwnedPlot(): Model?
	local folder = Workspace:FindFirstChild("Plots")
	if folder == nil then
		return nil
	end
	for _, plot in folder:GetChildren() do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function getMyCellsFolder(): Instance?
	if myPlot == nil or myPlot.Parent == nil then
		myPlot = findOwnedPlot()
	end
	if myPlot == nil then
		return nil
	end
	return myPlot:FindFirstChild("Cells")
end

local function getCharacterPosition(): Vector3?
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

-- Raycast depuis la caméra ; retourne la case visée si elle appartient à ma parcelle.
local function getTargetCell(screenPosition: Vector2): BasePart?
	local cellsFolder = getMyCellsFolder()
	local camera = Workspace.CurrentCamera
	if cellsFolder == nil or camera == nil then
		return nil
	end

	local ignored: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character ~= nil then
			table.insert(ignored, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignored

	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
	if result == nil then
		return nil
	end
	local hit = result.Instance
	if hit.Parent ~= cellsFolder or not hit:IsA("BasePart") then
		return nil
	end
	return hit
end

local function emitDirt(cell: BasePart, count: number)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, cell.Size.Y / 2, 0)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(UiConfig.DIRT_COLOR)
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.Speed = NumberRange.new(8, 14)
	emitter.SpreadAngle = Vector2.new(50, 50)
	emitter.Acceleration = Vector3.new(0, -Workspace.Gravity / 4, 0)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = attachment

	attachment.Parent = cell
	emitter:Emit(count)
	Debris:AddItem(attachment, UiConfig.EFFECT_LIFETIME)
end

local function shakeCell(cell: BasePart)
	local rest = restCFrames[cell]
	if rest == nil then
		rest = cell.CFrame
		restCFrames[cell] = rest
	end
	cell.CFrame = rest - Vector3.new(0, UiConfig.CELL_SHAKE_DEPTH, 0)
	TweenService:Create(
		cell,
		TweenInfo.new(UiConfig.CELL_SHAKE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = rest }
	):Play()
end

-- Case creusable sous ce point de l'écran : sur ma parcelle, intacte et à portée. Retourne aussi son index.
local function getDiggableCell(screenPosition: Vector2): (BasePart?, number)
	local cell = getTargetCell(screenPosition)
	if cell == nil then
		return nil, 0
	end
	local hitsLeft = cell:GetAttribute("HitsLeft")
	local cellIndex = cell:GetAttribute("CellIndex")
	if typeof(hitsLeft) ~= "number" or hitsLeft <= 0 or typeof(cellIndex) ~= "number" then
		return nil, 0
	end
	local position = getCharacterPosition()
	if position == nil or (position - cell.Position).Magnitude > PlotConfig.MAX_DIG_DISTANCE then
		return nil, 0
	end
	return cell, cellIndex
end

local function isChestFull(): boolean
	local inventoryCount = player:GetAttribute("InventoryCount")
	return typeof(inventoryCount) == "number" and inventoryCount >= getInventoryLimit()
end

-- Un coup sur la case visée. Les coups enchaînés par l'appui gardent une petite marge sur la cadence
-- du serveur, pour qu'un décalage réseau ne fasse pas refuser un coup sur deux.
local function tryDig(screenPosition: Vector2, isRepeat: boolean)
	local now = os.clock()
	local interval = if isRepeat then PlotConfig.DIG_COOLDOWN + UiConfig.DIG_HOLD_MARGIN else PlotConfig.DIG_COOLDOWN
	if now - lastRequestTime < interval then
		return
	end

	local cell, cellIndex = getDiggableCell(screenPosition)
	if cell == nil then
		return
	end

	lastRequestTime = now
	digRequest:FireServer(cellIndex)

	-- Coffre plein : le serveur refusera le coup et affichera le bandeau. Un seul essai par appui.
	if isChestFull() then
		holdInput = nil
		return
	end
	local target: BasePart = cell

	-- Le geste part tout de suite ; terre, secousse et son arrivent quand la lame touche la case.
	ShovelController.swingLocal(function()
		if target.Parent ~= nil then
			shakeCell(target)
			emitDirt(target, UiConfig.DIRT_PARTICLES_PER_HIT)
		end
		hitSounds[soundRng:NextInteger(1, #hitSounds)]:Play()
	end)
end

-- Position de la souris en coordonnées d'écran (GetMouseLocation inclut la barre Roblox).
local function getMouseScreenPosition(): Vector2
	local inset = GuiService:GetGuiInset()
	return UserInputService:GetMouseLocation() - inset
end

local function isPointerInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- Chaque image : surbrillance de la case visée, et coups enchaînés tant que l'appui dure.
local function onRenderStep()
	local aimPosition: Vector2? = nil
	if holdInput ~= nil then
		aimPosition = holdPosition
	elseif UserInputService.MouseEnabled then
		aimPosition = getMouseScreenPosition()
	end
	local cell = if aimPosition ~= nil then getDiggableCell(aimPosition) else nil
	highlight.Adornee = cell

	if holdInput ~= nil then
		tryDig(holdPosition, true)
	end
end

-- Place la caméra derrière le personnage, tournée vers sa parcelle, une fois la téléportation arrivée.
local function faceCameraToPlot(origin: CFrame)
	local character = player.Character or player.CharacterAdded:Wait()
	local rootPart = character:WaitForChild("HumanoidRootPart", UiConfig.CAMERA_WAIT_TIMEOUT)
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return
	end

	local deadline = os.clock() + UiConfig.CAMERA_WAIT_TIMEOUT
	while (rootPart.Position - origin.Position).Magnitude > UiConfig.CAMERA_ARRIVAL_RADIUS do
		if os.clock() > deadline or rootPart.Parent == nil then
			return
		end
		task.wait()
	end

	local camera = Workspace.CurrentCamera
	local flat = (origin.Position - rootPart.Position) * Vector3.new(1, 0, 1)
	if camera == nil or flat.Magnitude < 0.01 then
		return
	end
	local direction = flat.Unit
	local eye = rootPart.Position - direction * UiConfig.CAMERA_DISTANCE + Vector3.new(0, UiConfig.CAMERA_HEIGHT, 0)
	camera.CFrame = CFrame.lookAt(eye, rootPart.Position + direction * UiConfig.CAMERA_DISTANCE)
end

local function onCellHit(cellIndex: unknown, hitsLeft: unknown)
	if typeof(cellIndex) ~= "number" or hitsLeft ~= 0 then
		return
	end
	local cellsFolder = getMyCellsFolder()
	local cell = if cellsFolder ~= nil then cellsFolder:FindFirstChild(tostring(cellIndex)) else nil
	if cell ~= nil and cell:IsA("BasePart") then
		emitDirt(cell, UiConfig.DIRT_PARTICLES_ON_BREAK)
	end
end

function DigController.init()
	digRequest = Remotes.get(Remotes.Names.DigRequest)
	cellHit = Remotes.get(Remotes.Names.CellHit)
	plotAssigned = Remotes.get(Remotes.Names.PlotAssigned)

	for index, def in AudioConfig.DIG_HITS do
		table.insert(hitSounds, AudioKit.create("DigHit" .. index, def))
	end

	-- Sous la caméra : visible uniquement par ce joueur.
	highlight = Instance.new("SelectionBox")
	highlight.Name = "DigHighlight"
	highlight.Color3 = UiConfig.DIG_HIGHLIGHT_COLOR
	highlight.LineThickness = UiConfig.DIG_HIGHLIGHT_THICKNESS
	highlight.SurfaceColor3 = UiConfig.DIG_HIGHLIGHT_COLOR
	highlight.SurfaceTransparency = UiConfig.DIG_HIGHLIGHT_SURFACE_TRANSPARENCY
	highlight.Parent = Workspace.CurrentCamera
end

function DigController.start()
	plotAssigned.OnClientEvent:Connect(function(plotIndex: unknown, origin: unknown)
		local folder = Workspace:WaitForChild("Plots")
		local plot = folder:FindFirstChild("Plot" .. tostring(plotIndex))
		if plot ~= nil and plot:IsA("Model") then
			myPlot = plot
			restCFrames = {}
		end
		if typeof(origin) == "CFrame" then
			plotOrigin = origin
			task.spawn(faceCameraToPlot, origin)
		end
	end)
	player.CharacterAdded:Connect(function()
		local origin = plotOrigin
		if origin ~= nil then
			task.spawn(faceCameraToPlot, origin)
		end
	end)
	cellHit.OnClientEvent:Connect(onCellHit)

	-- Appui (souris ou doigt) hors de l'interface : premier coup tout de suite, puis enchaînement.
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or not isPointerInput(input) or holdInput ~= nil then
			return
		end
		holdInput = input
		holdPosition = Vector2.new(input.Position.X, input.Position.Y)
		tryDig(holdPosition, false)
	end)

	-- Le curseur bouge pendant l'appui : on continue sur la nouvelle case.
	UserInputService.InputChanged:Connect(function(input: InputObject)
		local held = holdInput
		if held == nil then
			return
		end
		local mouseMove = input.UserInputType == Enum.UserInputType.MouseMovement
			and held.UserInputType == Enum.UserInputType.MouseButton1
		if input == held or mouseMove then
			holdPosition = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input == holdInput then
			holdInput = nil
		end
	end)

	-- La fenêtre perd le focus : le relâchement ne nous parviendra pas, on arrête l'appui.
	UserInputService.WindowFocusReleased:Connect(function()
		holdInput = nil
	end)

	RunService.RenderStepped:Connect(onRenderStep)
end

return DigController
