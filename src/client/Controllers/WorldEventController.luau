--!strict
-- Événements de serveur, côté client (plan semaine 5, section 7) : annonce 10 s avant (pluie de
-- météorites, Nuit de sang) et météorites qui tombent sur les parcelles pendant la pluie.
-- Les météorites sont un effet visuel local, sans collision : le bonus de chance est décidé par le
-- serveur (MeteorService). Le compte à rebours est dans le HUD, le ciel rouge dans DayNightController.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventConfig = require(Shared.Config.EventConfig)
local UiConfig = require(Shared.Config.UiConfig)
local AudioConfig = require(Shared.Config.AudioConfig)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local AnnouncementController = require(script.Parent.AnnouncementController)
local AudioKit = require(script.Parent.Parent.AudioKit)
local QualityController = require(script.Parent.QualityController)

local IMPACT_COLOR = Color3.fromRGB(255, 200, 120)

local WorldEventController = {}

local rng = Random.new()
local effectsFolder: Folder
local active = 0

local function meteorRunning(now: number): boolean
	local startsAt = ReplicatedStorage:GetAttribute(EventConfig.ATTRIBUTE_METEOR_STARTS_AT)
	local endsAt = ReplicatedStorage:GetAttribute(EventConfig.ATTRIBUTE_METEOR_ENDS_AT)
	return typeof(startsAt) == "number"
		and typeof(endsAt) == "number"
		and startsAt ~= 0
		and now >= startsAt
		and now < endsAt
end

-- Point d'impact au hasard sur une parcelle (dessus de sa boîte englobante).
local function randomImpactPoint(): Vector3?
	local plots = Workspace:FindFirstChild("Plots")
	if plots == nil then
		return nil
	end
	local models = {}
	for _, plot in plots:GetChildren() do
		if plot:IsA("Model") then
			table.insert(models, plot)
		end
	end
	if #models == 0 then
		return nil
	end
	local plot = models[rng:NextInteger(1, #models)]
	local frame, size = plot:GetBoundingBox()
	local offset = Vector3.new(rng:NextNumber(-0.5, 0.5) * size.X, size.Y / 2, rng:NextNumber(-0.5, 0.5) * size.Z)
	return (frame * CFrame.new(offset)).Position
end

local function impactFlash(position: Vector3)
	local flash = Instance.new("Part")
	flash.Name = "MeteorImpact"
	flash.Shape = Enum.PartType.Ball
	flash.Material = Enum.Material.Neon
	flash.Color = IMPACT_COLOR
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CastShadow = false
	flash.Size = Vector3.one
	flash.Position = position
	flash.Parent = effectsFolder
	local info = TweenInfo.new(EventConfig.METEOR_IMPACT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(flash, info, { Size = Vector3.one * EventConfig.METEOR_IMPACT_SIZE, Transparency = 1 }):Play()
	Debris:AddItem(flash, EventConfig.METEOR_IMPACT_TIME)

	-- Son 3D au point d'impact (sur un point d'attache, pour durer plus longtemps que le flash).
	local anchor = Instance.new("Attachment")
	anchor.Name = "MeteorImpactSound"
	anchor.WorldPosition = position
	anchor.Parent = Workspace.Terrain
	local sound = AudioKit.create("MeteorImpact", AudioConfig.METEOR_IMPACT, "effects", anchor)
	sound.RollOffMaxDistance = AudioConfig.METEOR_ROLLOFF_MAX
	sound:Play()
	Debris:AddItem(anchor, sound.TimeLength + 1)
end

local function spawnMeteor()
	-- Moins de météorites à la fois si le téléphone peine ; la lumière et le feu sont les plus coûteux.
	local full = QualityController.scale() >= 1
	if active >= QualityController.count(EventConfig.METEOR_MAX_ACTIVE) then
		return
	end
	local target = randomImpactPoint()
	if target == nil then
		return
	end
	local angle = rng:NextNumber(0, 2 * math.pi)
	local side = Vector3.new(math.cos(angle), 0, math.sin(angle)) * EventConfig.METEOR_SIDE_OFFSET
	local start = target + side + Vector3.new(0, EventConfig.METEOR_HEIGHT, 0)

	local meteor = Instance.new("Part")
	meteor.Name = "Meteor"
	meteor.Shape = Enum.PartType.Ball
	meteor.Material = Enum.Material.Neon
	meteor.Color = EventConfig.METEOR_COLOR
	meteor.Size = Vector3.one * EventConfig.METEOR_SIZE
	meteor.Anchored = true
	meteor.CanCollide = false
	meteor.CanQuery = false
	meteor.CanTouch = false
	meteor.CastShadow = false
	meteor.Position = start
	if full then
		local light = Instance.new("PointLight")
		light.Color = EventConfig.METEOR_COLOR
		light.Range = EventConfig.METEOR_LIGHT_RANGE
		light.Parent = meteor
	end
	if QualityController.scale() >= UiConfig.EFFECTS_LEVELS[2] then
		local fire = Instance.new("Fire")
		fire.Size = EventConfig.METEOR_SIZE * 2
		fire.Heat = 0 -- la traînée suit la chute, sans monter
		fire.Parent = meteor
	end
	meteor.Parent = effectsFolder
	active += 1

	local fall = TweenService:Create(
		meteor,
		TweenInfo.new(EventConfig.METEOR_FALL_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = target }
	)
	fall.Completed:Connect(function()
		active -= 1
		meteor:Destroy()
		impactFlash(target)
	end)
	fall:Play()
end

function WorldEventController.init()
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "WorldEventEffects"
	effectsFolder.Parent = Workspace
end

function WorldEventController.start()
	Remotes.get(Remotes.Names.WorldEventWarning).OnClientEvent:Connect(function(kind: unknown, startsAt: unknown)
		if typeof(startsAt) ~= "number" then
			return
		end
		local seconds = math.max(0, math.ceil(startsAt - Workspace:GetServerTimeNow()))
		if kind == "meteor" then
			AnnouncementController.announce(
				Locale.t("announce.meteor", seconds, EventConfig.METEOR_LUCK_MULTIPLIER),
				"meteor"
			)
		elseif kind == "bloodNight" then
			AnnouncementController.announce(
				Locale.t("announce.bloodNight", seconds, EventConfig.BLOOD_NIGHT_CURSED_MULTIPLIER),
				"bloodNight"
			)
		end
	end)

	-- Pluie de météorites : une météorite toutes les METEOR_SPAWN_INTERVAL secondes, tant qu'elle dure.
	task.spawn(function()
		while true do
			if meteorRunning(Workspace:GetServerTimeNow()) then
				spawnMeteor()
			end
			task.wait(EventConfig.METEOR_SPAWN_INTERVAL)
		end
	end)
end

return WorldEventController
