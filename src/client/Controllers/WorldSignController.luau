--!strict
-- Panneaux du monde (« Parcelle de … », stands du Marchand et de la Forge) : posés par le serveur avec le
-- tag WorldConfig.SIGN_TAG. Chez chaque client, leur texte est plafonné en pixels (plus petit sur téléphone)
-- et un panneau qui monterait jusqu'au HUD du haut est décalé à l'écran juste en dessous ; s'il faudrait
-- le déplacer trop loin de sa place (panneau lointain, près de l'horizon), il est masqué.
-- Réglages locaux seulement : rien n'est renvoyé au serveur.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiConfig = require(Shared.Config.UiConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local HudLayout = require(script.Parent.Parent.HudLayout)

local WorldSignController = {}

local signs: { [BillboardGui]: TextLabel } = {}
local maxText = UiConfig.WORLD_SIGN_MAX_TEXT

local function track(instance: Instance)
	if not instance:IsA("BillboardGui") or signs[instance] ~= nil then
		return
	end
	local label = instance:FindFirstChildWhichIsA("TextLabel") or instance:WaitForChild("TextLabel", 5)
	if label == nil or not label:IsA("TextLabel") or instance.Parent == nil then
		return
	end
	-- Le texte occupe une bande centrée du panneau, dont la hauteur est réglée à chaque image.
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	signs[instance] = label
end

local function untrack(instance: Instance)
	if instance:IsA("BillboardGui") then
		signs[instance] = nil
	end
end

local function adorneePosition(billboard: BillboardGui): Vector3?
	local adornee = billboard.Adornee
	if adornee ~= nil and adornee:IsA("Attachment") then
		return adornee.WorldPosition
	elseif adornee ~= nil and adornee:IsA("BasePart") then
		return adornee.Position
	end
	return nil
end

local function update()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local limitY = HudLayout.hudBottomOnScreen() + UiConfig.WORLD_SIGN_HUD_GAP
	for billboard, label in signs do
		local height = billboard.AbsoluteSize.Y
		local position = adorneePosition(billboard)
		if position == nil or height <= 0 then
			continue
		end
		-- Plafond de taille : la bande de texte ne dépasse pas maxText pixels de haut.
		local textHeight = math.min(height, maxText)
		local bandScale = textHeight / height
		if math.abs(label.Size.Y.Scale - bandScale) > 1e-3 then
			label.Size = UDim2.fromScale(1, bandScale)
		end

		local offset = Vector2.zero
		local visible = true
		local point = camera:WorldToViewportPoint(position)
		if point.Z > 0 then
			local shift = limitY - (point.Y - textHeight / 2)
			if shift > 0 then
				if shift > UiConfig.WORLD_SIGN_MAX_SHIFT * textHeight then
					visible = false
				else
					-- SizeOffset est une fraction de la taille du panneau ; Y positif le fait monter.
					offset = Vector2.new(0, -shift / height)
				end
			end
		end
		if billboard.SizeOffset ~= offset then
			billboard.SizeOffset = offset
		end
		if label.Visible ~= visible then
			label.Visible = visible
		end
	end
end

function WorldSignController.init() end

function WorldSignController.start()
	HudLayout.observe(function(layout: HudLayout.Layout)
		maxText = if layout.compact then UiConfig.WORLD_SIGN_MAX_TEXT_COMPACT else UiConfig.WORLD_SIGN_MAX_TEXT
	end)
	CollectionService:GetInstanceAddedSignal(WorldConfig.SIGN_TAG):Connect(function(instance)
		task.spawn(track, instance)
	end)
	CollectionService:GetInstanceRemovedSignal(WorldConfig.SIGN_TAG):Connect(untrack)
	for _, instance in CollectionService:GetTagged(WorldConfig.SIGN_TAG) do
		task.spawn(track, instance)
	end
	RunService.RenderStepped:Connect(update)
end

return WorldSignController
