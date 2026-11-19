--!strict
-- Carte de révélation de l'objet trouvé, colorée selon sa rareté.
-- Légendaire et Secret : carte plus grande, flash, son plus fort, contour animé.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
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
local WHITE = Color3.new(1, 1, 1)
local CARD_BACKGROUND = Color3.fromRGB(28, 26, 34)
local STROKE_THICKNESS = 4
local STROKE_THICKNESS_SPECTACULAR = 8

local player = Players.LocalPlayer

local RevealController = {}

type CardUi = {
	gui: ScreenGui,
	flash: Frame,
	card: Frame,
	scale: UIScale,
	stroke: UIStroke,
	strokeGradient: UIGradient,
	rarityLabel: TextLabel,
	rarityGradient: UIGradient,
	nameLabel: TextLabel,
	mutationLabel: TextLabel,
	valueLabel: TextLabel,
}

local ui: CardUi
local revealSound: Sound
local spectacularSound: Sound
local generation = 0
local spectacularUntil = 0

local function createLabel(name: string, position: UDim2, size: UDim2, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.TextStrokeTransparency = 0.5
	label.Parent = parent
	return label
end

local function createSound(name: string, soundId: string, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end

local function buildUi(): CardUi
	local gui = Instance.new("ScreenGui")
	gui.Name = "RevealGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.IgnoreGuiInset = true

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = WHITE
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Active = false
	flash.Parent = gui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.42)
	card.Size = UDim2.fromScale(0.45, 0.25)
	card.BackgroundColor3 = CARD_BACKGROUND
	card.BackgroundTransparency = 0.08
	card.Visible = false
	card.Active = false
	card.Parent = gui

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 2.2
	aspect.Parent = card

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(260, 118)
	sizeLimit.MaxSize = Vector2.new(480, 218)
	sizeLimit.Parent = card

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = STROKE_THICKNESS
	stroke.Parent = card

	local strokeGradient = Instance.new("UIGradient")
	strokeGradient.Color = RAINBOW
	strokeGradient.Enabled = false
	strokeGradient.Parent = stroke

	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = card

	local rarityLabel = createLabel("Rarity", UDim2.fromScale(0.05, 0.07), UDim2.fromScale(0.9, 0.22), card)
	local rarityGradient = Instance.new("UIGradient")
	rarityGradient.Color = RAINBOW
	rarityGradient.Enabled = false
	rarityGradient.Parent = rarityLabel

	local nameLabel = createLabel("ItemName", UDim2.fromScale(0.05, 0.31), UDim2.fromScale(0.9, 0.32), card)
	local mutationLabel = createLabel("Mutation", UDim2.fromScale(0.05, 0.64), UDim2.fromScale(0.9, 0.16), card)
	local valueLabel = createLabel("Value", UDim2.fromScale(0.05, 0.81), UDim2.fromScale(0.9, 0.13), card)
	valueLabel.TextColor3 = Color3.fromRGB(220, 220, 220)

	gui.Parent = player:WaitForChild("PlayerGui")

	return {
		gui = gui,
		flash = flash,
		card = card,
		scale = scale,
		stroke = stroke,
		strokeGradient = strokeGradient,
		rarityLabel = rarityLabel,
		rarityGradient = rarityGradient,
		nameLabel = nameLabel,
		mutationLabel = mutationLabel,
		valueLabel = valueLabel,
	}
end

local function isRevealPayload(value: unknown): boolean
	if typeof(value) ~= "table" then
		return false
	end
	local payload = value :: { [string]: unknown }
	return typeof(payload.name) == "string"
		and typeof(payload.rarity) == "string"
		and Rarities.byId[payload.rarity :: string] ~= nil
		and typeof(payload.value) == "number"
end

local function playFlash(color: Color3)
	ui.flash.BackgroundColor3 = color
	ui.flash.BackgroundTransparency = 0.15
	TweenService:Create(
		ui.flash,
		TweenInfo.new(UiConfig.REVEAL_FLASH_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	):Play()
end

local function showReveal(payload: Types.RevealPayload)
	local rarity = Rarities.byId[payload.rarity]
	local mutation = if payload.mutation ~= nil then Mutations.byId[payload.mutation] else nil
	local spectacular = rarity.isSpectacular
	local now = os.clock()

	-- Une révélation spectaculaire n'est pas écrasée par une révélation ordinaire.
	if not spectacular and now < spectacularUntil then
		return
	end

	generation += 1
	local myGeneration = generation
	local holdTime = if spectacular then UiConfig.REVEAL_SPECTACULAR_HOLD_TIME else UiConfig.REVEAL_HOLD_TIME
	if spectacular then
		spectacularUntil = now + UiConfig.REVEAL_APPEAR_TIME + holdTime + UiConfig.REVEAL_FADE_TIME
	end

	local isRainbowRarity = payload.rarity == "Secret"
	local isRainbowMutation = payload.mutation == "Rainbow"

	ui.rarityLabel.Text = string.upper(rarity.displayName)
	ui.rarityLabel.TextColor3 = if isRainbowRarity then WHITE else rarity.color
	ui.rarityGradient.Enabled = isRainbowRarity
	ui.nameLabel.Text = payload.name
	ui.stroke.Color = if mutation ~= nil then mutation.color else rarity.color
	ui.stroke.Thickness = if spectacular then STROKE_THICKNESS_SPECTACULAR else STROKE_THICKNESS
	ui.strokeGradient.Enabled = isRainbowRarity or isRainbowMutation
	if mutation ~= nil then
		ui.mutationLabel.Visible = true
		ui.mutationLabel.Text = string.format("%s  x%d", mutation.displayName, mutation.multiplier)
		ui.mutationLabel.TextColor3 = mutation.color
	else
		ui.mutationLabel.Visible = false
	end
	ui.valueLabel.Text = string.format("Valeur : %d", payload.value)

	local targetScale = if spectacular then UiConfig.REVEAL_SPECTACULAR_SCALE else 1
	ui.card.Visible = true
	ui.scale.Scale = 0
	TweenService:Create(
		ui.scale,
		TweenInfo.new(UiConfig.REVEAL_APPEAR_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = targetScale }
	):Play()

	if spectacular then
		playFlash(if isRainbowRarity then WHITE else rarity.color)
		spectacularSound:Play()
	else
		revealSound:Play()
	end

	task.delay(UiConfig.REVEAL_APPEAR_TIME + holdTime, function()
		if generation ~= myGeneration then
			return
		end
		local tween = TweenService:Create(
			ui.scale,
			TweenInfo.new(UiConfig.REVEAL_FADE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Scale = 0 }
		)
		tween.Completed:Connect(function()
			if generation == myGeneration then
				ui.card.Visible = false
			end
		end)
		tween:Play()
	end)
end

function RevealController.init()
	ui = buildUi()
	revealSound = createSound("Reveal", UiConfig.SOUND_REVEAL, UiConfig.VOLUME_REVEAL)
	spectacularSound =
		createSound("RevealSpectacular", UiConfig.SOUND_REVEAL_SPECTACULAR, UiConfig.VOLUME_REVEAL_SPECTACULAR)
end

function RevealController.start()
	Remotes.get(Remotes.Names.ItemRevealed).OnClientEvent:Connect(function(payload: unknown)
		if isRevealPayload(payload) then
			showReveal(payload :: Types.RevealPayload)
		end
	end)

	-- Contour et titre arc-en-ciel qui tournent.
	RunService.RenderStepped:Connect(function(deltaTime: number)
		if not ui.card.Visible then
			return
		end
		local step = deltaTime * UiConfig.RAINBOW_SPIN_SPEED
		if ui.strokeGradient.Enabled then
			ui.strokeGradient.Rotation = (ui.strokeGradient.Rotation + step) % 360
		end
		if ui.rarityGradient.Enabled then
			ui.rarityGradient.Offset = Vector2.new(math.sin(os.clock() * 2) * 0.3, 0)
		end
	end)
end

return RevealController
