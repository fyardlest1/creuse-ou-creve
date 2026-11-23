--!strict
-- Révélation de l'objet trouvé, selon la rareté (plan semaine 5, section 3) :
--   Commun, Peu commun, Rare : carte simple, colorée selon la rareté.
--   Épique : carte plus grande, halo violet, son plus fort.
--   Légendaire : l'écran se fige 0,3 s, puis lignes de vitesse, flash doré, gros son d'impact, secousse.
--   Secret : tout cela en arc-en-ciel, plus la musique de victoire (l'aura est gérée par AuraController).
-- Tout est local au joueur ; rien n'est envoyé au serveur. Les effets doivent rester lisibles en 1 seconde
-- sur un écran de téléphone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local UiConfig = require(Shared.Config.UiConfig)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local ItemIcon = require(script.Parent.Parent.ItemIcon)
local RevealGate = require(script.Parent.Parent.RevealGate)

local RAINBOW_COLORS = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(255, 170, 50),
	Color3.fromRGB(255, 240, 70),
	Color3.fromRGB(80, 230, 110),
	Color3.fromRGB(70, 150, 255),
	Color3.fromRGB(200, 90, 255),
}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, RAINBOW_COLORS[1]),
	ColorSequenceKeypoint.new(0.2, RAINBOW_COLORS[2]),
	ColorSequenceKeypoint.new(0.4, RAINBOW_COLORS[3]),
	ColorSequenceKeypoint.new(0.6, RAINBOW_COLORS[4]),
	ColorSequenceKeypoint.new(0.8, RAINBOW_COLORS[5]),
	ColorSequenceKeypoint.new(1, RAINBOW_COLORS[6]),
})
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local CARD_BACKGROUND = Color3.fromRGB(28, 26, 34)
local STROKE_THICKNESS = 4
local STROKE_THICKNESS_SPECTACULAR = 8
local CARD_ASPECT = 2.2
local CARD_MIN_SIZE = Vector2.new(260, 118)
local CARD_MAX_SIZE = Vector2.new(480, 218)
local SHAKE_BIND_NAME = "RevealCameraShake"

local player = Players.LocalPlayer

local RevealController = {}

type Tier = "simple" | "epic" | "legendary" | "secret"

type CardUi = {
	gui: ScreenGui,
	veil: Frame,
	flash: Frame,
	lines: Frame,
	lineBars: { Frame },
	halo: Frame,
	haloScale: UIScale,
	haloGradient: UIGradient,
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
local epicSound: Sound
local impactSound: Sound
local victorySound: Sound
local generation = 0
local spectacularUntil = 0
local linesUntil = 0
local linesRainbow = false
local haloPulsing = false

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

local function createSound(name: string, soundId: string, volume: number, pitch: number?): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	return sound
end

-- Même mise en page que la carte (centrée, proportions et tailles limites), pour le halo.
local function cardShape(frame: Frame)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.42)
	frame.Size = UDim2.fromScale(0.45, 0.25)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = CARD_ASPECT
	aspect.Parent = frame
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = CARD_MIN_SIZE
	sizeLimit.MaxSize = CARD_MAX_SIZE
	sizeLimit.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
	corner.Parent = frame
end

-- Lignes de vitesse : barres fines qui traversent l'écran par son centre, vides au milieu (autour de la
-- carte) grâce à un dégradé de transparence. Créées une fois, réutilisées.
local function buildSpeedLines(parent: Instance): (Frame, { Frame })
	local holder = Instance.new("Frame")
	holder.Name = "SpeedLines"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = parent
	local gap = UiConfig.SPEED_LINE_GAP
	local fade = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5 - gap / 2 - 0.05, 0.2),
		NumberSequenceKeypoint.new(0.5 - gap / 2, 1),
		NumberSequenceKeypoint.new(0.5 + gap / 2, 1),
		NumberSequenceKeypoint.new(0.5 + gap / 2 + 0.05, 0.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	local bars = {}
	for index = 1, UiConfig.SPEED_LINE_COUNT do
		local bar = Instance.new("Frame")
		bar.Name = "Line" .. index
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.42)
		bar.Size = UDim2.new(0, UiConfig.SPEED_LINE_THICKNESS, UiConfig.SPEED_LINE_LENGTH, 0)
		bar.Rotation = (index - 1) * 180 / UiConfig.SPEED_LINE_COUNT
		bar.BackgroundColor3 = WHITE
		bar.BorderSizePixel = 0
		bar.Parent = holder
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90 -- le long de la barre
		gradient.Transparency = fade
		gradient.Parent = bar
		table.insert(bars, bar)
	end
	return holder, bars
end

local function buildUi(): CardUi
	local gui = Instance.new("ScreenGui")
	gui.Name = "RevealGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 14 -- devant les fenêtres (10) et les annonces (12) : c'est le moment filmé
	gui.IgnoreGuiInset = true

	-- De l'arrière vers l'avant : voile sombre, lignes de vitesse, flash, halo, carte.
	local veil = Instance.new("Frame")
	veil.Name = "Veil"
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = BLACK
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel = 0
	veil.Parent = gui

	local lines, lineBars = buildSpeedLines(gui)

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = WHITE
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui

	local halo = Instance.new("Frame")
	halo.Name = "Halo"
	halo.BackgroundColor3 = WHITE
	halo.BackgroundTransparency = UiConfig.REVEAL_HALO_TRANSPARENCY
	halo.Visible = false
	cardShape(halo)
	halo.Parent = gui
	local haloScale = Instance.new("UIScale")
	haloScale.Scale = 0
	haloScale.Parent = halo
	local haloGradient = Instance.new("UIGradient")
	haloGradient.Color = RAINBOW
	haloGradient.Enabled = false
	haloGradient.Parent = halo

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.BackgroundColor3 = CARD_BACKGROUND
	card.BackgroundTransparency = 0.08
	card.Visible = false
	cardShape(card)
	card.Parent = gui

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

	-- Icône à gauche (posée à chaque révélation), textes à droite.
	local textLeft = UiConfig.REVEAL_TEXT_LEFT
	local textWidth = 0.95 - textLeft
	local rarityLabel = createLabel("Rarity", UDim2.fromScale(textLeft, 0.07), UDim2.fromScale(textWidth, 0.22), card)
	local rarityGradient = Instance.new("UIGradient")
	rarityGradient.Color = RAINBOW
	rarityGradient.Enabled = false
	rarityGradient.Parent = rarityLabel

	local nameLabel = createLabel("ItemName", UDim2.fromScale(textLeft, 0.31), UDim2.fromScale(textWidth, 0.32), card)
	nameLabel.TextWrapped = true -- noms longs sur deux lignes plutôt qu'en tout petit
	local mutationLabel =
		createLabel("Mutation", UDim2.fromScale(textLeft, 0.64), UDim2.fromScale(textWidth, 0.16), card)
	local valueLabel = createLabel("Value", UDim2.fromScale(textLeft, 0.81), UDim2.fromScale(textWidth, 0.13), card)
	valueLabel.TextColor3 = Color3.fromRGB(220, 220, 220)

	gui.Parent = player:WaitForChild("PlayerGui")

	return {
		gui = gui,
		veil = veil,
		flash = flash,
		lines = lines,
		lineBars = lineBars,
		halo = halo,
		haloScale = haloScale,
		haloGradient = haloGradient,
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
	return typeof(payload.itemId) == "string"
		and typeof(payload.rarity) == "string"
		and Rarities.byId[payload.rarity :: string] ~= nil
		and typeof(payload.value) == "number"
end

local function tierOf(rarityId: string): Tier
	if rarityId == "Secret" then
		return "secret"
	elseif rarityId == "Legendary" then
		return "legendary"
	elseif rarityId == "Epic" then
		return "epic"
	end
	return "simple"
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

-- Secousse de caméra courte, appliquée après la mise à jour de la caméra, puis retirée.
local function shakeCamera()
	local startedAt = os.clock()
	RunService:UnbindFromRenderStep(SHAKE_BIND_NAME)
	RunService:BindToRenderStep(SHAKE_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		local elapsed = os.clock() - startedAt
		local camera = Workspace.CurrentCamera
		if elapsed >= UiConfig.CAMERA_SHAKE_TIME or camera == nil then
			RunService:UnbindFromRenderStep(SHAKE_BIND_NAME)
			return
		end
		local strength = UiConfig.CAMERA_SHAKE_STRENGTH * (1 - elapsed / UiConfig.CAMERA_SHAKE_TIME)
		local offset = Vector3.new((math.random() - 0.5) * 2 * strength, (math.random() - 0.5) * 2 * strength, 0)
		camera.CFrame = camera.CFrame * CFrame.new(offset)
	end)
end

local function showSpeedLines(rainbow: boolean)
	linesRainbow = rainbow
	linesUntil = os.clock() + UiConfig.SPEED_LINES_TIME
	for index, bar in ui.lineBars do
		bar.BackgroundColor3 = if rainbow then RAINBOW_COLORS[(index - 1) % #RAINBOW_COLORS + 1] else WHITE
		bar.BackgroundTransparency = 0
	end
	ui.lines.Visible = true
end

-- Prépare la carte (textes, couleurs) sans l'afficher.
local function fillCard(payload: Types.RevealPayload, tier: Tier)
	local rarity = Rarities.byId[payload.rarity]
	local mutation = if payload.mutation ~= nil then Mutations.byId[payload.mutation] else nil
	local rainbow = tier == "secret"
	local spectacular = tier == "legendary" or tier == "secret"

	ui.rarityLabel.Text = string.upper(Locale.rarity(rarity.id))
	ui.rarityLabel.TextColor3 = if rainbow then WHITE else rarity.color
	ui.rarityGradient.Enabled = rainbow
	ui.nameLabel.Text = Locale.item(payload.itemId)
	local oldIcon = ui.card:FindFirstChild("Icon")
	if oldIcon ~= nil then
		oldIcon:Destroy()
	end
	local icon = ItemIcon.create(payload.itemId, rarity.color, ui.card)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromScale(UiConfig.REVEAL_ICON_LEFT, 0.5)
	icon.Size = UDim2.fromScale(UiConfig.REVEAL_ICON_HEIGHT, UiConfig.REVEAL_ICON_HEIGHT)
	ui.stroke.Color = if mutation ~= nil then mutation.color else rarity.color
	ui.stroke.Thickness = if spectacular then STROKE_THICKNESS_SPECTACULAR else STROKE_THICKNESS
	ui.strokeGradient.Enabled = rainbow or payload.mutation == "Rainbow"
	if mutation ~= nil then
		ui.mutationLabel.Visible = true
		ui.mutationLabel.Text = string.format("%s  x%d", Locale.mutation(mutation.id), mutation.multiplier)
		ui.mutationLabel.TextColor3 = mutation.color
	else
		ui.mutationLabel.Visible = false
	end
	ui.valueLabel.Text = Locale.t("reveal.value", Locale.number(payload.value))

	-- Halo : Épique et mieux, à la couleur de la rareté (arc-en-ciel pour le Secret).
	ui.halo.BackgroundColor3 = if rainbow then WHITE else rarity.color
	ui.haloGradient.Enabled = rainbow
end

local function popCard(tier: Tier)
	local targetScale = if tier == "legendary" or tier == "secret"
		then UiConfig.REVEAL_SPECTACULAR_SCALE
		elseif tier == "epic" then UiConfig.REVEAL_EPIC_SCALE
		else 1
	local appear = TweenInfo.new(UiConfig.REVEAL_APPEAR_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	ui.card.Visible = true
	ui.scale.Scale = 0
	TweenService:Create(ui.scale, appear, { Scale = targetScale }):Play()
	haloPulsing = tier ~= "simple"
	ui.halo.Visible = haloPulsing
	if haloPulsing then
		ui.haloScale.Scale = 0
		TweenService:Create(ui.haloScale, appear, { Scale = targetScale * UiConfig.REVEAL_HALO_SCALE }):Play()
	end
end

local function hideCard(myGeneration: number)
	local disappear = TweenInfo.new(UiConfig.REVEAL_FADE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	local tween = TweenService:Create(ui.scale, disappear, { Scale = 0 })
	TweenService:Create(ui.haloScale, disappear, { Scale = 0 }):Play()
	tween.Completed:Connect(function()
		if generation == myGeneration then
			ui.card.Visible = false
			ui.halo.Visible = false
			haloPulsing = false
		end
	end)
	tween:Play()
end

local function showReveal(payload: Types.RevealPayload)
	local tier = tierOf(payload.rarity)
	local spectacular = tier == "legendary" or tier == "secret"
	local now = os.clock()

	-- Une révélation spectaculaire n'est pas écrasée par une révélation ordinaire.
	if not spectacular and now < spectacularUntil then
		return
	end

	generation += 1
	local myGeneration = generation
	local freeze = if spectacular then UiConfig.REVEAL_FREEZE_TIME else 0
	local holdTime = if spectacular then UiConfig.REVEAL_SPECTACULAR_HOLD_TIME else UiConfig.REVEAL_HOLD_TIME
	if spectacular then
		spectacularUntil = now + freeze + UiConfig.REVEAL_APPEAR_TIME + holdTime + UiConfig.REVEAL_FADE_TIME
		RevealGate.holdUntil(spectacularUntil) -- les annonces serveur attendent la fin de la carte
	end

	fillCard(payload, tier)

	if not spectacular then
		popCard(tier)
		if tier == "epic" then
			epicSound:Play()
		else
			revealSound:Play()
		end
	else
		-- Arrêt sur image : la carte disparaît, l'écran s'assombrit, les lignes se figent.
		ui.card.Visible = false
		ui.halo.Visible = false
		ui.veil.BackgroundTransparency = UiConfig.REVEAL_FREEZE_DARKNESS
		showSpeedLines(tier == "secret")
		linesUntil = math.huge -- figées pendant l'arrêt sur image
		task.delay(freeze, function()
			if generation ~= myGeneration then
				return
			end
			-- Impact : flash, lignes animées, carte, son, secousse.
			linesUntil = os.clock() + UiConfig.SPEED_LINES_TIME
			playFlash(if tier == "secret" then WHITE else UiConfig.LEGENDARY_FLASH_COLOR)
			TweenService:Create(ui.veil, TweenInfo.new(UiConfig.SPEED_LINES_TIME), { BackgroundTransparency = 1 })
				:Play()
			popCard(tier)
			impactSound:Play()
			if tier == "secret" then
				victorySound:Play()
			end
			shakeCamera()
		end)
	end

	task.delay(freeze + UiConfig.REVEAL_APPEAR_TIME + holdTime, function()
		if generation == myGeneration then
			hideCard(myGeneration)
		end
	end)
end

-- Animation à chaque image, seulement pendant qu'une carte ou des lignes sont affichées.
local function onRenderStep(deltaTime: number)
	local now = os.clock()
	if ui.lines.Visible then
		if now >= linesUntil then
			ui.lines.Visible = false
		elseif linesUntil ~= math.huge then
			-- Scintillement façon anime : épaisseur et transparence au hasard, fondu sur la fin.
			local remaining = (linesUntil - now) / UiConfig.SPEED_LINES_TIME
			for index, bar in ui.lineBars do
				local jitter = 1 + (math.random() - 0.5) * 2 * UiConfig.SPEED_LINE_JITTER
				bar.Size = UDim2.new(0, UiConfig.SPEED_LINE_THICKNESS * jitter, UiConfig.SPEED_LINE_LENGTH, 0)
				bar.BackgroundTransparency = 1 - remaining
				if linesRainbow then
					local step = math.floor(now * 12) + index
					bar.BackgroundColor3 = RAINBOW_COLORS[step % #RAINBOW_COLORS + 1]
				end
			end
		end
	end
	if not ui.card.Visible then
		return
	end
	local step = deltaTime * UiConfig.RAINBOW_SPIN_SPEED
	if ui.strokeGradient.Enabled then
		ui.strokeGradient.Rotation = (ui.strokeGradient.Rotation + step) % 360
	end
	if ui.rarityGradient.Enabled then
		ui.rarityGradient.Offset = Vector2.new(math.sin(now * 2) * 0.3, 0)
	end
	if haloPulsing then
		local pulse = (math.sin(now * UiConfig.REVEAL_HALO_PULSE_SPEED) + 1) / 2
		ui.halo.BackgroundTransparency = UiConfig.REVEAL_HALO_TRANSPARENCY + pulse * 0.25
		if ui.haloGradient.Enabled then
			ui.haloGradient.Rotation = (ui.haloGradient.Rotation + step) % 360
		end
	end
end

function RevealController.init()
	ui = buildUi()
	revealSound = createSound("Reveal", UiConfig.SOUND_REVEAL, UiConfig.VOLUME_REVEAL)
	epicSound =
		createSound("RevealEpic", UiConfig.SOUND_REVEAL, UiConfig.VOLUME_REVEAL_EPIC, UiConfig.PITCH_REVEAL_EPIC)
	impactSound = createSound(
		"RevealImpact",
		UiConfig.SOUND_REVEAL_IMPACT,
		UiConfig.VOLUME_REVEAL_IMPACT,
		UiConfig.PITCH_REVEAL_IMPACT
	)
	victorySound = createSound("RevealVictory", UiConfig.SOUND_REVEAL_SPECTACULAR, UiConfig.VOLUME_REVEAL_SPECTACULAR)
end

function RevealController.start()
	Remotes.get(Remotes.Names.ItemRevealed).OnClientEvent:Connect(function(payload: unknown)
		if isRevealPayload(payload) then
			showReveal(payload :: Types.RevealPayload)
		end
	end)
	RunService.RenderStepped:Connect(onRenderStep)
end

return RevealController
