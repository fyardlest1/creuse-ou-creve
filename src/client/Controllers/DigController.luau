--!strict
-- Clic ou toucher sur une case de sa parcelle : envoie l'intention au serveur
-- et joue tout de suite un petit retour local (secousse, terre, son).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlotConfig = require(Shared.Config.PlotConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local UiConfig = require(Shared.Config.UiConfig)
local Remotes = require(Shared.Remotes)
local ShovelController = require(script.Parent.ShovelController)

local RAY_LENGTH = 1000

local player = Players.LocalPlayer

local DigController = {}

local digRequest: RemoteEvent
local cellHit: RemoteEvent
local plotAssigned: RemoteEvent
local myPlot: Model? = nil
local plotOrigin: CFrame? = nil
local lastRequestTime = -math.huge
local restCFrames: { [BasePart]: CFrame } = {}
local hitSound: Sound

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

local function tryDig(screenPosition: Vector2)
	local now = os.clock()
	if now - lastRequestTime < PlotConfig.DIG_COOLDOWN then
		return
	end

	local cell = getTargetCell(screenPosition)
	if cell == nil then
		return
	end
	local hitsLeft = cell:GetAttribute("HitsLeft")
	local cellIndex = cell:GetAttribute("CellIndex")
	if typeof(hitsLeft) ~= "number" or hitsLeft <= 0 or typeof(cellIndex) ~= "number" then
		return
	end
	local position = getCharacterPosition()
	if position == nil or (position - cell.Position).Magnitude > PlotConfig.MAX_DIG_DISTANCE then
		return
	end

	lastRequestTime = now
	digRequest:FireServer(cellIndex)

	-- Inventaire plein : le serveur refusera le coup et affichera le bandeau, pas d'effet de creusage.
	local inventoryCount = player:GetAttribute("InventoryCount")
	if typeof(inventoryCount) == "number" and inventoryCount >= PlayerConfig.INVENTORY_LIMIT then
		return
	end

	-- Le geste part tout de suite ; terre, secousse et son arrivent quand la lame touche la case.
	ShovelController.swingLocal(function()
		if cell.Parent ~= nil then
			shakeCell(cell)
			emitDirt(cell, UiConfig.DIRT_PARTICLES_PER_HIT)
		end
		hitSound:Play()
	end)
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

	hitSound = Instance.new("Sound")
	hitSound.Name = "DigHit"
	hitSound.SoundId = UiConfig.SOUND_DIG_HIT
	hitSound.Volume = UiConfig.VOLUME_DIG_HIT
	hitSound.Parent = SoundService
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

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		tryDig(Vector2.new(input.Position.X, input.Position.Y))
	end)

	-- Sur mobile : un tapotement dans le monde (pas un glissement de caméra).
	UserInputService.TouchTapInWorld:Connect(function(position: Vector2, processedByUI: boolean)
		if processedByUI then
			return
		end
		tryDig(position)
	end)
end

return DigController
