--!strict
-- HUD : pastilles du haut (profondeur, couche, coffre, Pièces), bouton Coffre, bandeaux d'information
-- et flèche vers le Marchand quand le coffre est plein. Le haut de l'écran est placé par HudLayout, qui
-- laisse libre la zone de la liste des joueurs de Roblox (en haut à droite).
-- L'état de départ vient des attributs du joueur, écrits par le serveur.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerConfig = require(Shared.Config.PlayerConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Shovels = require(Shared.Config.Shovels)
local Strata = require(Shared.Config.Strata)
local UiConfig = require(Shared.Config.UiConfig)
local AudioConfig = require(Shared.Config.AudioConfig)
local AudioKit = require(script.Parent.Parent.AudioKit)
local WorldConfig = require(Shared.Config.WorldConfig)
local EventConfig = require(Shared.Config.EventConfig)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local ChestController = require(script.Parent.ChestController)
local ShopController = require(script.Parent.ShopController)
local RetentionController = require(script.Parent.RetentionController)
local SoundSettingsController = require(script.Parent.SoundSettingsController)
local UiKit = require(script.Parent.Parent.UiKit)
local HudLayout = require(script.Parent.Parent.HudLayout)

local PILL_BACKGROUND = Color3.fromRGB(28, 26, 34)
local PILL_FULL_BACKGROUND = Color3.fromRGB(170, 40, 40)
local COINS_TEXT_COLOR = Color3.fromRGB(255, 205, 60)
local BANNER_ALERT = Color3.fromRGB(200, 45, 45)
local BANNER_SUCCESS = Color3.fromRGB(50, 150, 70)
local BANNER_INFO = Color3.fromRGB(60, 110, 200)
local ARROW_COLOR = Color3.fromRGB(255, 205, 60)
local WHITE = Color3.new(1, 1, 1)
local PILL_MAX_TEXT_SIZE = 22
local CHEST_BUTTON_COLOR = Color3.fromRGB(130, 85, 45)
local PROTECTED_COLOR = Color3.fromRGB(60, 140, 90)
local AUTO_DIG_OFF_COLOR = Color3.fromRGB(80, 80, 90)
local SHOP_BUTTON_COLOR = Color3.fromRGB(200, 70, 150)
local AUTO_DIG_ON_COLOR = Color3.fromRGB(60, 160, 80)
local AUTO_DIG_PAUSED_COLOR = Color3.fromRGB(200, 120, 40)
local QUESTS_BUTTON_COLOR = Color3.fromRGB(60, 120, 200)
local INDEX_BUTTON_COLOR = Color3.fromRGB(120, 80, 190)
local RESERVE_BUTTON_COLOR = Color3.fromRGB(50, 150, 130)
local SOUND_BUTTON_COLOR = Color3.fromRGB(90, 95, 120)
local NOTIFY_DOT_COLOR = Color3.fromRGB(230, 50, 50)
local POTION_CHIP_COLOR = Color3.fromRGB(60, 150, 70)
local EVENT_CHIP_COLOR = Color3.fromRGB(220, 140, 30)
local SHIELD_CHIP_COLOR = Color3.fromRGB(60, 110, 200)
local TEXT_POTION_CHIP = "🍀 %s" -- symbole + minuteur, identique dans toutes les langues
local TEXT_EVENT_CHIP = "⚡ %s"
local METEOR_CHIP_COLOR = Color3.fromRGB(215, 90, 30)
local BLOOD_CHIP_COLOR = Color3.fromRGB(150, 25, 35)
local TEXT_METEOR_CHIP = "☄ %s"

local COIN_COLOR = Color3.fromRGB(255, 200, 40)
local COIN_STROKE_COLOR = Color3.fromRGB(180, 120, 20)
local ARROW_BACKGROUND = Color3.fromRGB(28, 26, 34)
-- Géométrie de la flèche, en fraction du disque
local ARROW_BAR_THICKNESS = 0.13
local ARROW_TIP_Y = 0.18
local ARROW_SHAFT_LENGTH = 0.62
local ARROW_HEAD_LENGTH = 0.36
local ARROW_HEAD_ANGLE = 40 -- degrés

local player = Players.LocalPlayer

local HudController = {}

local depthLabel: TextLabel
local stratumLabel: TextLabel
local chestLabel: TextLabel
local depthPill: Frame
local stratumPill: Frame
local chestPill: Frame
local coinsPill: Frame
local coinsLabel: TextLabel
local banner: TextLabel
local arrowFrame: Frame
local arrowDial: Frame
local bannerGeneration = 0
local fullSound: Sound
local merchantPosition: Vector3? = nil
-- Cible prioritaire de la flèche (ex. son coffre attaqué), avec sa légende. Sinon : le Marchand.
local arrowOverride: { position: Vector3, caption: string, reachDistance: number }? = nil
local arrowCaption: TextLabel
local currentLayout: HudLayout.Layout
-- Boutons latéraux, avec leur décalage vertical propre (le bouton Creusage auto est sous le Coffre).
local sideButtons: { [GuiObject]: number } = {}
local protectionPill: Frame
local autoDigButton: TextButton
local autoDigToggle: RemoteEvent
local protectionLabel: TextLabel
local questsDot: Frame
local reserveCount: TextLabel
local boostChips: Frame
local potionChip: TextLabel
local eventChip: TextLabel
local shieldChip: TextLabel
local meteorChip: TextLabel -- pluie de météorites : compte à rebours, puis temps restant
local bloodChip: TextLabel -- Nuit de sang : compte à rebours, puis pendant la nuit

local function addCorner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius, 0)
	corner.Parent = parent
end

local function createPill(name: string, parent: Instance): (Frame, TextLabel)
	local pill = Instance.new("Frame")
	pill.Name = name
	pill.BackgroundColor3 = PILL_BACKGROUND
	pill.BackgroundTransparency = 0.15
	pill.Parent = parent
	addCorner(pill, 0.5)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.08, 0)
	padding.PaddingRight = UDim.new(0.08, 0)
	padding.PaddingTop = UDim.new(0.15, 0)
	padding.PaddingBottom = UDim.new(0.15, 0)
	padding.Parent = pill

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.Parent = pill

	-- Même taille de texte maximale partout, pour que les pastilles restent homogènes.
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = PILL_MAX_TEXT_SIZE
	textLimit.Parent = label

	return pill, label
end

-- Pastilles du haut, placées par applyLayout.
local function buildTopPills(gui: ScreenGui)
	depthPill, depthLabel = createPill("Depth", gui)
	stratumPill, stratumLabel = createPill("Stratum", gui)
	chestPill, chestLabel = createPill("Chest", gui)
end

local function buildCoins(gui: ScreenGui)
	local pill = Instance.new("Frame")
	pill.Name = "Coins"
	coinsPill = pill
	pill.BackgroundColor3 = PILL_BACKGROUND
	pill.BackgroundTransparency = 0.15
	pill.Parent = gui
	addCorner(pill, 0.5)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.08, 0)
	padding.PaddingRight = UDim.new(0.08, 0)
	padding.PaddingTop = UDim.new(0.15, 0)
	padding.PaddingBottom = UDim.new(0.15, 0)
	padding.Parent = pill

	-- Pastille dorée dessinée (les emojis ne s'affichent pas partout).
	local icon = Instance.new("Frame")
	icon.Name = "CoinIcon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromScale(0, 0.5)
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundColor3 = COIN_COLOR
	icon.Parent = pill
	addCorner(icon, 0.5)
	local iconRatio = Instance.new("UIAspectRatioConstraint")
	iconRatio.AspectRatio = 1
	iconRatio.DominantAxis = Enum.DominantAxis.Height
	iconRatio.Parent = icon
	local iconStroke = Instance.new("UIStroke")
	iconStroke.Color = COIN_STROKE_COLOR
	iconStroke.Thickness = 2
	iconStroke.Parent = icon

	coinsLabel = Instance.new("TextLabel")
	coinsLabel.Name = "Amount"
	coinsLabel.AnchorPoint = Vector2.new(1, 0)
	coinsLabel.Position = UDim2.fromScale(1, 0)
	coinsLabel.Size = UDim2.fromScale(0.75, 1)
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.Font = Enum.Font.FredokaOne
	coinsLabel.TextScaled = true
	coinsLabel.TextColor3 = COINS_TEXT_COLOR
	coinsLabel.Parent = pill
end

local function buildBanner(gui: ScreenGui)
	banner = Instance.new("TextLabel")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.BackgroundColor3 = BANNER_ALERT
	banner.Font = Enum.Font.FredokaOne
	banner.TextScaled = true
	banner.TextColor3 = WHITE
	banner.Visible = false
	banner.Parent = gui
	addCorner(banner, 0.3)

	local bannerPadding = Instance.new("UIPadding")
	bannerPadding.PaddingTop = UDim.new(0.15, 0)
	bannerPadding.PaddingBottom = UDim.new(0.15, 0)
	bannerPadding.PaddingLeft = UDim.new(0.03, 0)
	bannerPadding.PaddingRight = UDim.new(0.03, 0)
	bannerPadding.Parent = banner
end

-- Flèche qui tourne pour indiquer la direction du Marchand (affichée quand le coffre est plein).
local function buildMerchantArrow(gui: ScreenGui)
	arrowFrame = Instance.new("Frame")
	arrowFrame.Name = "MerchantArrow"
	-- En haut, au bord droit de la zone libre (applyLayout) : au centre, elle cacherait l'avatar sur
	-- téléphone, et plus à droite la liste des joueurs la couvrirait.
	arrowFrame.BackgroundTransparency = 1
	arrowFrame.Visible = false
	arrowFrame.Parent = gui

	-- Disque qui tourne d'un bloc, avec une flèche dessinée (tige + deux branches), sans police.
	arrowDial = Instance.new("Frame")
	arrowDial.Name = "Arrow"
	arrowDial.AnchorPoint = Vector2.new(0.5, 0)
	arrowDial.Position = UDim2.fromScale(0.5, 0)
	arrowDial.BackgroundColor3 = ARROW_BACKGROUND
	arrowDial.BackgroundTransparency = 0.25
	arrowDial.Parent = arrowFrame
	addCorner(arrowDial, 0.5)

	local function addBar(name: string, center: Vector2, length: number, rotation: number)
		local bar = Instance.new("Frame")
		bar.Name = name
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(center.X, center.Y)
		bar.Size = UDim2.fromScale(ARROW_BAR_THICKNESS, length)
		bar.Rotation = rotation
		bar.BackgroundColor3 = ARROW_COLOR
		bar.BorderSizePixel = 0
		bar.Parent = arrowDial
		addCorner(bar, 0.5)
	end
	-- Pointe en (0.5, ARROW_TIP_Y) ; chaque branche part de la pointe avec un angle de ARROW_HEAD_ANGLE.
	local headHalf = ARROW_HEAD_LENGTH / 2
	local radians = math.rad(ARROW_HEAD_ANGLE)
	local dx, dy = math.sin(radians) * headHalf, math.cos(radians) * headHalf
	addBar("Shaft", Vector2.new(0.5, ARROW_TIP_Y + ARROW_SHAFT_LENGTH / 2), ARROW_SHAFT_LENGTH, 0)
	addBar("HeadLeft", Vector2.new(0.5 - dx, ARROW_TIP_Y + dy), ARROW_HEAD_LENGTH, ARROW_HEAD_ANGLE)
	addBar("HeadRight", Vector2.new(0.5 + dx, ARROW_TIP_Y + dy), ARROW_HEAD_LENGTH, -ARROW_HEAD_ANGLE)

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.fromScale(0.5, 1)
	caption.Size = UDim2.new(1, 0, 0, UiConfig.MERCHANT_ARROW_CAPTION_HEIGHT)
	caption.BackgroundColor3 = ARROW_BACKGROUND
	caption.BackgroundTransparency = 0.25
	addCorner(caption, 0.5)
	caption.Font = Enum.Font.FredokaOne
	caption.TextScaled = true
	caption.TextColor3 = WHITE
	caption.TextStrokeTransparency = 0.3
	caption.Text = Locale.t("hud.merchantArrow")
	arrowCaption = caption
	caption.Parent = arrowFrame
end

-- Rappel de la protection débutant, sur la ligne d'état sous les pastilles du haut, à gauche.
local function buildProtection(gui: ScreenGui)
	protectionPill = Instance.new("Frame")
	protectionPill.Name = "Protection"
	protectionPill.BackgroundColor3 = PROTECTED_COLOR
	protectionPill.BackgroundTransparency = 0.15
	protectionPill.Visible = false
	protectionPill.Parent = gui
	addCorner(protectionPill, 0.5)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.15, 0)
	padding.PaddingBottom = UDim.new(0.15, 0)
	padding.PaddingLeft = UDim.new(0.08, 0)
	padding.PaddingRight = UDim.new(0.08, 0)
	padding.Parent = protectionPill

	protectionLabel = Instance.new("TextLabel")
	protectionLabel.Size = UDim2.fromScale(1, 1)
	protectionLabel.BackgroundTransparency = 1
	protectionLabel.Font = Enum.Font.FredokaOne
	protectionLabel.TextScaled = true
	protectionLabel.TextColor3 = WHITE
	protectionLabel.Parent = protectionPill
end

local function updateProtection()
	local protectedUntil = player:GetAttribute("ProtectedUntil")
	local remaining = if typeof(protectedUntil) == "number" then protectedUntil - Workspace:GetServerTimeNow() else 0
	protectionPill.Visible = remaining > 0
	if remaining > 0 then
		protectionLabel.Text = Locale.t("hud.protected", math.ceil(remaining / 60))
	end
end

-- Bouton Boutique : bord droit, à mi-hauteur (au-dessus du bouton de saut sur mobile).
local function buildShopButton(gui: ScreenGui)
	local size = UiConfig.HUD_SHOP_BUTTON_SIZE
	local button = Instance.new("TextButton")
	button.Name = "ShopButton"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -UiConfig.HUD_MARGIN, UiConfig.HUD_SIDE_BUTTONS_Y, 0)
	button.Size = UDim2.fromOffset(size, size)
	button.BackgroundColor3 = SHOP_BUTTON_COLOR
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = WHITE
	button.Text = Locale.t("hud.shop")
	button.Parent = gui
	addCorner(button, 0.25)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.Parent = button
	button.Activated:Connect(ShopController.toggle)
end

-- Bouton du pass Creusage auto, sous le bouton Coffre (visible seulement avec le pass).
local function buildAutoDigButton(gui: ScreenGui)
	local size = UiConfig.HUD_CHEST_BUTTON_SIZE
	autoDigButton = Instance.new("TextButton")
	autoDigButton.Name = "AutoDigButton"
	autoDigButton.AnchorPoint = Vector2.new(0, 0)
	autoDigButton.Position =
		UDim2.new(0, UiConfig.HUD_MARGIN, UiConfig.HUD_SIDE_BUTTONS_Y, size / 2 + UiConfig.HUD_SPACING)
	autoDigButton.Size = UDim2.fromOffset(size, size)
	autoDigButton.BackgroundColor3 = AUTO_DIG_OFF_COLOR
	autoDigButton.Font = Enum.Font.FredokaOne
	autoDigButton.TextScaled = true
	autoDigButton.TextColor3 = WHITE
	autoDigButton.Text = Locale.t("hud.autoOff")
	autoDigButton.Visible = false
	autoDigButton.Parent = gui
	addCorner(autoDigButton, 0.25)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.PaddingLeft = UDim.new(0.08, 0)
	padding.PaddingRight = UDim.new(0.08, 0)
	padding.Parent = autoDigButton
	autoDigButton.Activated:Connect(function()
		autoDigToggle:FireServer(player:GetAttribute("AutoDig") ~= true)
	end)
end

local function ownsPass(key: string): boolean
	local owned = player:GetAttribute("OwnedPasses")
	return typeof(owned) == "string" and table.find(string.split(owned, ","), key) ~= nil
end

local function refreshAutoDig()
	autoDigButton.Visible = ownsPass("AutoDig")
	local on = player:GetAttribute("AutoDig") == true
	local paused = on and player:GetAttribute("AutoDigPaused") == true
	autoDigButton.Text = Locale.t(if paused then "hud.autoPaused" elseif on then "hud.autoOn" else "hud.autoOff")
	autoDigButton.BackgroundColor3 = if paused
		then AUTO_DIG_PAUSED_COLOR
		elseif on then AUTO_DIG_ON_COLOR
		else AUTO_DIG_OFF_COLOR
end

local function buildChestButton(gui: ScreenGui)
	-- Bord gauche, à mi-hauteur : hors du joystick et du bouton de saut sur mobile.
	local chestButton = Instance.new("TextButton")
	chestButton.Name = "ChestButton"
	chestButton.AnchorPoint = Vector2.new(0, 0.5)
	chestButton.Position = UDim2.new(0, UiConfig.HUD_MARGIN, UiConfig.HUD_SIDE_BUTTONS_Y, 0)
	chestButton.Size = UDim2.fromOffset(UiConfig.HUD_CHEST_BUTTON_SIZE, UiConfig.HUD_CHEST_BUTTON_SIZE)
	chestButton.BackgroundColor3 = CHEST_BUTTON_COLOR
	chestButton.Font = Enum.Font.FredokaOne
	chestButton.TextScaled = true
	chestButton.TextColor3 = WHITE
	chestButton.Text = Locale.t("hud.chest")
	chestButton.Parent = gui
	chestButton.Activated:Connect(ChestController.toggle)
	addCorner(chestButton, 0.25)

	local chestPadding = Instance.new("UIPadding")
	chestPadding.PaddingTop = UDim.new(0.1, 0)
	chestPadding.PaddingBottom = UDim.new(0.1, 0)
	chestPadding.PaddingLeft = UDim.new(0.08, 0)
	chestPadding.PaddingRight = UDim.new(0.08, 0)
	chestPadding.Parent = chestButton
end

-- Bouton carré du HUD (même style que Coffre et Boutique).
local function sideButton(gui: ScreenGui, name: string, text: string, color: Color3, anchor: Vector2, position: UDim2)
	local size = UiConfig.HUD_CHEST_BUTTON_SIZE
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = anchor
	button.Position = position
	button.Size = UDim2.fromOffset(size, size)
	button.BackgroundColor3 = color
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = WHITE
	button.Text = text
	button.Parent = gui
	addCorner(button, 0.25)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.Parent = button
	return button
end

-- Quêtes et Index à droite du Coffre (hors du joystick tactile), Réserve à gauche de la Boutique.
local function buildRetentionButtons(gui: ScreenGui)
	local size = UiConfig.HUD_CHEST_BUTTON_SIZE
	local step = size + UiConfig.HUD_SPACING
	local quests = sideButton(
		gui,
		"QuestsButton",
		Locale.t("hud.quests"),
		QUESTS_BUTTON_COLOR,
		Vector2.new(0, 0.5),
		UDim2.new(0, UiConfig.HUD_MARGIN + step, UiConfig.HUD_SIDE_BUTTONS_Y, 0)
	)
	quests.Activated:Connect(RetentionController.toggleQuests)
	-- Pastille rouge : récompense du jour à récupérer
	questsDot = Instance.new("Frame")
	questsDot.Name = "Dot"
	questsDot.AnchorPoint = Vector2.new(0.5, 0.5)
	questsDot.Position = UDim2.new(1, 0, 0, 0)
	questsDot.Size = UDim2.fromOffset(UiConfig.HUD_NOTIFY_DOT_SIZE, UiConfig.HUD_NOTIFY_DOT_SIZE)
	questsDot.BackgroundColor3 = NOTIFY_DOT_COLOR
	questsDot.Visible = false
	questsDot.Parent = quests
	addCorner(questsDot, 0.5)

	local index = sideButton(
		gui,
		"IndexButton",
		Locale.t("hud.index"),
		INDEX_BUTTON_COLOR,
		Vector2.new(0, 0.5),
		UDim2.new(0, UiConfig.HUD_MARGIN + 2 * step, UiConfig.HUD_SIDE_BUTTONS_Y, 0)
	)
	index.Activated:Connect(RetentionController.toggleIndex)

	local reserve = sideButton(
		gui,
		"ReserveButton",
		Locale.t("hud.reserve"),
		RESERVE_BUTTON_COLOR,
		Vector2.new(1, 0.5),
		UDim2.new(
			1,
			-(UiConfig.HUD_MARGIN + UiConfig.HUD_SHOP_BUTTON_SIZE + UiConfig.HUD_SPACING),
			UiConfig.HUD_SIDE_BUTTONS_Y,
			0
		)
	)
	reserve.Activated:Connect(RetentionController.toggleReserve)

	-- Menu Son (musique, effets sonores), à gauche de la Réserve : loin du bouton de saut sur mobile.
	local soundButton = sideButton(
		gui,
		"SoundButton",
		Locale.t("hud.sound"),
		SOUND_BUTTON_COLOR,
		Vector2.new(1, 0.5),
		UDim2.new(
			1,
			-(UiConfig.HUD_MARGIN + UiConfig.HUD_SHOP_BUTTON_SIZE + UiConfig.HUD_SPACING + step),
			UiConfig.HUD_SIDE_BUTTONS_Y,
			0
		)
	)
	soundButton.Activated:Connect(SoundSettingsController.toggle)
	-- Nombre de bonus en réserve
	reserveCount = Instance.new("TextLabel")
	reserveCount.Name = "Count"
	reserveCount.AnchorPoint = Vector2.new(0.5, 0.5)
	reserveCount.Position = UDim2.new(1, 0, 0, 0)
	reserveCount.Size = UDim2.fromOffset(UiConfig.HUD_COUNT_BADGE_SIZE, UiConfig.HUD_COUNT_BADGE_SIZE)
	reserveCount.BackgroundColor3 = NOTIFY_DOT_COLOR
	reserveCount.Font = Enum.Font.FredokaOne
	reserveCount.TextScaled = true
	reserveCount.TextColor3 = WHITE
	reserveCount.Visible = false
	reserveCount.Parent = reserve
	addCorner(reserveCount, 0.5)
end

-- Indicateurs des bonus actifs (potion, événement, bouclier), sur la ligne d'état, après la protection.
local function chip(name: string, color: Color3, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.BackgroundColor3 = color
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.Visible = false
	label.Parent = boostChips
	addCorner(label, 0.5)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.15, 0)
	padding.PaddingBottom = UDim.new(0.15, 0)
	padding.PaddingLeft = UDim.new(0.08, 0)
	padding.PaddingRight = UDim.new(0.08, 0)
	padding.Parent = label
	return label
end

local function buildBoostChips(gui: ScreenGui)
	boostChips = Instance.new("Frame")
	boostChips.Name = "BoostChips"
	boostChips.BackgroundTransparency = 1
	boostChips.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Name = "Layout"
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = boostChips
	meteorChip = chip("Meteor", METEOR_CHIP_COLOR, -2)
	bloodChip = chip("BloodNight", BLOOD_CHIP_COLOR, -1)
	potionChip = chip("Potion", POTION_CHIP_COLOR, 1)
	eventChip = chip("Event", EVENT_CHIP_COLOR, 2)
	shieldChip = chip("Shield", SHIELD_CHIP_COLOR, 3)
end

local function updateBoostChips()
	local now = Workspace:GetServerTimeNow()
	local luckUntil = player:GetAttribute("LuckUntil")
	local potionLeft = if typeof(luckUntil) == "number" then luckUntil - now else 0
	potionChip.Visible = potionLeft > 0
	if potionLeft > 0 then
		potionChip.Text = string.format(TEXT_POTION_CHIP, UiKit.formatDuration(potionLeft))
	end
	local eventEndsAt = ReplicatedStorage:GetAttribute("LuckEventEndsAt")
	local eventLeft = if typeof(eventEndsAt) == "number" then eventEndsAt - now else 0
	eventChip.Visible = eventLeft > 0
	if eventLeft > 0 then
		eventChip.Text = string.format(TEXT_EVENT_CHIP, UiKit.formatDuration(eventLeft))
	end
	-- Événements de serveur : compte à rebours de WARNING_SECONDS, puis l'événement lui-même.
	local meteorStartsAt = ReplicatedStorage:GetAttribute(EventConfig.ATTRIBUTE_METEOR_STARTS_AT)
	local meteorEndsAt = ReplicatedStorage:GetAttribute(EventConfig.ATTRIBUTE_METEOR_ENDS_AT)
	local meteorSoon = typeof(meteorStartsAt) == "number" and meteorStartsAt > now
	local meteorLeft = if typeof(meteorEndsAt) == "number" and not meteorSoon then meteorEndsAt - now else 0
	meteorChip.Visible = meteorSoon or meteorLeft > 0
	if meteorSoon then
		meteorChip.Text = Locale.t("hud.meteorSoon", math.ceil((meteorStartsAt :: number) - now))
	elseif meteorLeft > 0 then
		meteorChip.Text = string.format(TEXT_METEOR_CHIP, UiKit.formatDuration(meteorLeft))
	end
	local bloodStartsAt = ReplicatedStorage:GetAttribute(EventConfig.ATTRIBUTE_BLOOD_NIGHT_STARTS_AT)
	local bloodSoon = typeof(bloodStartsAt) == "number" and bloodStartsAt > now
	local bloodNow = ReplicatedStorage:GetAttribute(EventConfig.ATTRIBUTE_BLOOD_NIGHT) == true
	bloodChip.Visible = bloodSoon or bloodNow
	if bloodSoon then
		bloodChip.Text = Locale.t("hud.bloodSoon", math.ceil((bloodStartsAt :: number) - now))
	elseif bloodNow then
		bloodChip.Text = Locale.t("hud.bloodActive")
	end

	local shieldActive = player:GetAttribute("ShieldTonight") == true
	shieldChip.Visible = shieldActive or player:GetAttribute("ShieldPlanned") == true
	shieldChip.Text = Locale.t(if shieldActive then "hud.shieldActive" else "hud.shieldReady")
	-- Sur la ligne d'état, après la protection débutant quand elle est affichée.
	local layout = currentLayout
	local left = layout.margin
	if protectionPill.Visible then
		left += layout.pills.timer.size.X + layout.spacing
	end
	boostChips.Position = UDim2.fromOffset(left, layout.statusTop)
	HudLayout.setStatusRowVisible(
		protectionPill.Visible
			or potionChip.Visible
			or eventChip.Visible
			or shieldChip.Visible
			or meteorChip.Visible
			or bloodChip.Visible
	)
end

-- Place le haut de l'écran selon la disposition (au démarrage et à chaque changement de taille d'écran).
local function applyLayout(layout: HudLayout.Layout)
	currentLayout = layout
	HudLayout.place(depthPill, layout.pills.depth)
	HudLayout.place(stratumPill, layout.pills.stratum)
	HudLayout.place(chestPill, layout.pills.chest)
	HudLayout.place(coinsPill, layout.pills.coins)

	local status = { position = Vector2.new(layout.margin, layout.statusTop), size = layout.pills.timer.size }
	HudLayout.place(protectionPill, status)
	local chipSize = UDim2.fromOffset(layout.chipWidth, layout.pillHeight)
	for _, label in { potionChip, eventChip, shieldChip } do
		label.Size = chipSize
	end
	local eventWidth = if layout.compact
		then UiConfig.WORLD_EVENT_CHIP_WIDTH_COMPACT
		else UiConfig.WORLD_EVENT_CHIP_WIDTH
	for _, label in { meteorChip, bloodChip } do
		label.Size = UDim2.fromOffset(eventWidth, layout.pillHeight)
	end
	local chipsLayout = boostChips:FindFirstChild("Layout") :: UIListLayout
	chipsLayout.Padding = UDim.new(0, layout.spacing)
	boostChips.Size =
		UDim2.fromOffset(3 * (layout.chipWidth + layout.spacing) + 2 * (eventWidth + layout.spacing), layout.pillHeight)
	updateBoostChips()

	for button, offsetY in sideButtons do
		button.Position = UDim2.new(button.Position.X, UDim.new(0, layout.sideButtonsCenterY + offsetY))
	end

	HudLayout.place(arrowFrame, layout.arrow)
	arrowDial.Size = UDim2.fromOffset(layout.arrowDialSize, layout.arrowDialSize)

	-- Bandeaux centrés sur la zone libre (ni sous la liste des joueurs, ni sur la flèche).
	local bannerWidth = layout.bannerRight - layout.bannerLeft
	banner.Position = UDim2.fromOffset((layout.bannerLeft + layout.bannerRight) / 2, layout.bannerTop)
	banner.Size = UDim2.fromOffset(math.min(UiConfig.BANNER_MAX_WIDTH, bannerWidth), layout.bannerHeight)
end

local function readNumberAttributeEarly(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function refreshRetention()
	questsDot.Visible = player:GetAttribute("DailyAvailable") == true
	local total = readNumberAttributeEarly("ReserveLuckPotion") + readNumberAttributeEarly("ReserveShield")
	reserveCount.Visible = total > 0
	reserveCount.Text = tostring(total)
end

local function buildUi()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HudGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	buildTopPills(gui)
	buildCoins(gui)
	buildBanner(gui)
	buildMerchantArrow(gui)
	buildProtection(gui)
	buildChestButton(gui)
	buildAutoDigButton(gui)
	buildShopButton(gui)
	buildRetentionButtons(gui)
	buildBoostChips(gui)
	for _, name in
		{ "ChestButton", "AutoDigButton", "QuestsButton", "IndexButton", "ShopButton", "ReserveButton", "SoundButton" }
	do
		local button = gui:FindFirstChild(name) :: GuiObject
		sideButtons[button] = button.Position.Y.Offset
	end
	HudLayout.observe(applyLayout)
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function readNumberAttribute(name: string, default: number): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function isChestFull(): boolean
	return readNumberAttribute("InventoryCount", 0)
		>= readNumberAttribute("InventoryLimit", PlayerConfig.INVENTORY_LIMIT)
end

local function refresh()
	local depth = readNumberAttribute("Depth", 0)
	local count = readNumberAttribute("InventoryCount", 0)
	depthLabel.Text = Locale.t("hud.depth", depth)
	stratumLabel.Text = Locale.stratum(Strata.fromDepth(depth).id)
	local limit = readNumberAttribute("InventoryLimit", PlayerConfig.INVENTORY_LIMIT)
	chestLabel.Text = Locale.t("hud.chestCount", count, limit)
	chestPill.BackgroundColor3 = if count >= limit then PILL_FULL_BACKGROUND else PILL_BACKGROUND
	coinsLabel.Text = Locale.number(readNumberAttribute("Coins", 0))
end

local function showBanner(text: string, color: Color3, duration: number?)
	bannerGeneration += 1
	local myGeneration = bannerGeneration
	banner.Text = text
	banner.BackgroundColor3 = color
	banner.BackgroundTransparency = 0.1
	banner.TextTransparency = 0
	banner.Visible = true

	task.delay(duration or UiConfig.BANNER_TIME, function()
		if bannerGeneration ~= myGeneration then
			return
		end
		local tween = TweenService:Create(
			banner,
			TweenInfo.new(UiConfig.BANNER_FADE_TIME),
			{ BackgroundTransparency = 1, TextTransparency = 1 }
		)
		tween.Completed:Connect(function()
			if bannerGeneration == myGeneration then
				banner.Visible = false
			end
		end)
		tween:Play()
	end)
end

-- Le stand du Marchand est repéré par l'attribut de son ProximityPrompt (pas par un nom d'instance).
local function findMerchantPosition(): Vector3?
	for _, descendant in Workspace:GetDescendants() do
		if
			descendant:IsA("ProximityPrompt")
			and descendant:GetAttribute(WorldConfig.INTERACTION_ATTRIBUTE) == WorldConfig.INTERACTIONS.Merchant
			and not CollectionService:HasTag(descendant, WorldConfig.VIP_ONLY_TAG) -- pas le Marchand VIP
		then
			local anchor = descendant.Parent
			if anchor ~= nil and anchor:IsA("Attachment") then
				return anchor.WorldPosition
			end
		end
	end
	return nil
end

-- Oriente la flèche vers le Marchand, par rapport à la direction de la caméra (vue de dessus).
local function updateMerchantArrow()
	local character = player.Character
	local rootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local camera = Workspace.CurrentCamera
	local override = arrowOverride
	if (override == nil and not isChestFull()) or rootPart == nil or not rootPart:IsA("BasePart") or camera == nil then
		arrowFrame.Visible = false
		return
	end
	if merchantPosition == nil then
		merchantPosition = findMerchantPosition()
	end
	local target = if override ~= nil then override.position else merchantPosition
	local reach = if override ~= nil then override.reachDistance else EconomyConfig.MERCHANT_MAX_DISTANCE
	arrowCaption.Text = if override ~= nil then override.caption else Locale.t("hud.merchantArrow")
	if target == nil then
		arrowFrame.Visible = false
		return
	end

	local toMerchant = (target - rootPart.Position) * Vector3.new(1, 0, 1)
	if toMerchant.Magnitude <= reach then
		arrowFrame.Visible = false
		return
	end
	local forward = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	if forward.Magnitude < 1e-3 then
		forward = camera.CFrame.UpVector * Vector3.new(1, 0, 1)
	end
	local f = forward.Unit
	local d = toMerchant.Unit
	-- Angle signé, positif vers la droite de l'écran.
	local right = Vector3.new(-f.Z, 0, f.X)
	local angle = math.atan2(d:Dot(right), d:Dot(f))
	arrowDial.Rotation = math.deg(angle)
	arrowFrame.Visible = true
end

export type BannerKind = "alert" | "success" | "info"

-- Force la flèche vers une position (prioritaire sur le Marchand), cachée à moins de reachDistance.
-- nil rend la flèche au Marchand.
function HudController.setArrowTarget(position: Vector3?, caption: string?, reachDistance: number?)
	if position == nil then
		arrowOverride = nil
		return
	end
	arrowOverride = { position = position, caption = caption or "", reachDistance = reachDistance or 0 }
end

-- Bandeau d'information, utilisable par les autres contrôleurs (nuit, vol...).
function HudController.showBanner(text: string, kind: BannerKind, long: boolean?)
	local color = if kind == "alert" then BANNER_ALERT elseif kind == "success" then BANNER_SUCCESS else BANNER_INFO
	showBanner(text, color, if long then UiConfig.BANNER_LONG_TIME else nil)
end

function HudController.init()
	autoDigToggle = Remotes.get(Remotes.Names.AutoDigToggle)
	buildUi()
	fullSound = AudioKit.create("InventoryFull", AudioConfig.INVENTORY_FULL)
	refresh()
end

function HudController.start()
	for _, name in { "Depth", "InventoryCount", "InventoryLimit", "Coins" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	Remotes.get(Remotes.Names.RevengeCompensated).OnClientEvent:Connect(function()
		showBanner(Locale.t("hud.revengeCompensated"), BANNER_INFO, UiConfig.BANNER_LONG_TIME)
	end)

	Remotes.get(Remotes.Names.InventoryFull).OnClientEvent:Connect(function()
		showBanner(Locale.t("hud.chestFull"), BANNER_ALERT, UiConfig.BANNER_LONG_TIME)
		fullSound:Play()
	end)

	Remotes.get(Remotes.Names.LayerCleared).OnClientEvent:Connect(function(layer: unknown, depth: unknown)
		if typeof(layer) ~= "number" or typeof(depth) ~= "number" then
			return
		end
		local stratum = Strata.byLayer[layer]
		local previous = Strata.fromDepth(depth - PlotConfig.DEPTH_PER_LAYER)
		if stratum ~= nil and stratum.id ~= previous.id then
			showBanner(Locale.t("hud.newStratum", Locale.t("stratum." .. stratum.id .. ".the"), depth), BANNER_SUCCESS)
		else
			showBanner(Locale.t("hud.deeper", depth), BANNER_SUCCESS)
		end
	end)

	Remotes.get(Remotes.Names.StratumBlocked).OnClientEvent:Connect(function(requiredShovel: unknown)
		local shovel = if typeof(requiredShovel) == "string" then Shovels.byId[requiredShovel] else nil
		if shovel == nil then
			return
		end
		local stratum = Strata.byId[shovel.maxStratum]
		showBanner(
			Locale.t("hud.stratumBlocked", Locale.shovel(shovel.id), Locale.t("stratum." .. stratum.id .. ".the")),
			BANNER_ALERT,
			UiConfig.BANNER_LONG_TIME
		)
		fullSound:Play()
	end)

	Remotes.get(Remotes.Names.ShovelChanged).OnClientEvent:Connect(function(shovelId: unknown)
		local shovel = if typeof(shovelId) == "string" then Shovels.byId[shovelId] else nil
		if shovel ~= nil then
			showBanner(Locale.t("hud.shovelEquipped", Locale.shovel(shovel.id)), BANNER_INFO)
		end
	end)

	RunService.RenderStepped:Connect(updateMerchantArrow)
	RunService.RenderStepped:Connect(updateProtection)
	RetentionController.setBannerHandler(function(text: string)
		showBanner(text, BANNER_SUCCESS, UiConfig.BANNER_LONG_TIME)
	end)
	for _, name in { "DailyAvailable", "ReserveLuckPotion", "ReserveShield" } do
		player:GetAttributeChangedSignal(name):Connect(refreshRetention)
	end
	refreshRetention()
	task.spawn(function()
		while true do
			updateBoostChips()
			task.wait(UiConfig.BOOST_REFRESH_INTERVAL)
		end
	end)
	for _, name in { "OwnedPasses", "AutoDig", "AutoDigPaused" } do
		player:GetAttributeChangedSignal(name):Connect(refreshAutoDig)
	end
	refreshAutoDig()
end

return HudController
