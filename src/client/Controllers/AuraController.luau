--!strict
-- Auras (plan semaine 5, section 3), créées localement par chaque client :
--   * aura du Secret : monte autour du joueur qui vient de trouver un Secret, pendant 3 s, visible par les
--     joueurs proches ;
--   * aura de collectionneur : discrète et permanente tant que le joueur a un Secret dans son coffre
--     (attribut HasSecret posé par le serveur). Visible de loin, et donc une cible évidente la nuit.
-- Nombre d'auras limité (les plus proches), mise à jour une fois par seconde : pas de boucle à chaque image.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiConfig = require(Shared.Config.UiConfig)
local Remotes = require(Shared.Remotes)

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 50)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 70)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 230, 110)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(70, 150, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
})
local COLLECTOR_NAME = "CollectorAura"
local BURST_NAME = "SecretAura"

local AuraController = {}

local function getRoot(target: Player): BasePart?
	local character = target.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function distanceFromCamera(position: Vector3): number
	local camera = Workspace.CurrentCamera
	return if camera ~= nil then (camera.CFrame.Position - position).Magnitude else math.huge
end

local function createEmitter(
	root: BasePart,
	name: string,
	rate: number,
	lifetime: number,
	speed: number,
	size: number
): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = UiConfig.AURA_TEXTURE
	emitter.Color = RAINBOW
	emitter.LightEmission = 1
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(lifetime * 0.8, lifetime)
	emitter.Speed = NumberRange.new(speed * 0.6, speed)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	-- Les particules partent d'un anneau autour du personnage, pas de son centre.
	emitter.Shape = Enum.ParticleEmitterShape.Cylinder
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.Parent = attachment
	return attachment
end

-- Aura du Secret : 3 s autour du joueur qui l'a trouvé, si la caméra est assez proche.
local function burst(finderUserId: number)
	local finder = Players:GetPlayerByUserId(finderUserId)
	local root = if finder ~= nil then getRoot(finder) else nil
	if root == nil or distanceFromCamera(root.Position) > UiConfig.SECRET_AURA_MAX_DISTANCE then
		return
	end
	local attachment = createEmitter(
		root,
		BURST_NAME,
		UiConfig.SECRET_AURA_RATE,
		UiConfig.SECRET_AURA_LIFETIME,
		UiConfig.SECRET_AURA_SPEED,
		UiConfig.SECRET_AURA_SIZE
	)
	task.delay(UiConfig.SECRET_AURA_TIME, function()
		local emitter = attachment:FindFirstChildOfClass("ParticleEmitter")
		if emitter ~= nil then
			emitter.Enabled = false
		end
	end)
	Debris:AddItem(attachment, UiConfig.SECRET_AURA_TIME + UiConfig.SECRET_AURA_LIFETIME)
end

-- Aura de collectionneur : les COLLECTOR_AURA_MAX_COUNT joueurs les plus proches qui ont un Secret.
local function refreshCollectors()
	local candidates: { { root: BasePart, distance: number } } = {}
	local wanted: { [BasePart]: boolean } = {}
	for _, other in Players:GetPlayers() do
		local root = getRoot(other)
		if root ~= nil and other:GetAttribute("HasSecret") == true then
			local distance = distanceFromCamera(root.Position)
			if distance <= UiConfig.COLLECTOR_AURA_MAX_DISTANCE then
				table.insert(candidates, { root = root, distance = distance })
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)
	for index = 1, math.min(#candidates, UiConfig.COLLECTOR_AURA_MAX_COUNT) do
		wanted[candidates[index].root] = true
	end
	for _, other in Players:GetPlayers() do
		local root = getRoot(other)
		if root ~= nil then
			local existing = root:FindFirstChild(COLLECTOR_NAME)
			if wanted[root] and existing == nil then
				createEmitter(
					root,
					COLLECTOR_NAME,
					UiConfig.COLLECTOR_AURA_RATE,
					UiConfig.COLLECTOR_AURA_LIFETIME,
					UiConfig.COLLECTOR_AURA_SPEED,
					UiConfig.COLLECTOR_AURA_SIZE
				)
			elseif not wanted[root] and existing ~= nil then
				existing:Destroy()
			end
		end
	end
end

function AuraController.init() end

function AuraController.start()
	Remotes.get(Remotes.Names.ItemAnnounced).OnClientEvent
		:Connect(function(finderUserId: unknown, _: unknown, _: unknown, rarity: unknown)
			if rarity == "Secret" and typeof(finderUserId) == "number" then
				burst(finderUserId)
			end
		end)
	task.spawn(function()
		while true do
			refreshCollectors()
			task.wait(UiConfig.COLLECTOR_AURA_REFRESH)
		end
	end)
end

return AuraController
