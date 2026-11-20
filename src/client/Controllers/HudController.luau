--!strict
-- HUD : barre du haut (profondeur, couche, coffre), Pièces en haut à droite, bouton Coffre,
-- bandeaux d'information et flèche vers le Marchand quand le coffre est plein.
-- L'état de départ vient des attributs du joueur, écrits par le serveur.

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
local WorldConfig = require(Shared.Config.WorldConfig)
local Remotes = require(Shared.Remotes)
local ChestController = require(script.Parent.ChestController)

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
local TEXT_PROTECTED = "Protégé : %d min"

local TEXT_DEPTH = "Profondeur : %d m"
local TEXT_CHEST = "Coffre : %d/%d"
local TEXT_COINS = "%s"
local COIN_COLOR = Color3.fromRGB(255, 200, 40)
local COIN_STROKE_COLOR = Color3.fromRGB(180, 120, 20)
local ARROW_BACKGROUND = Color3.fromRGB(28, 26, 34)
local TEXT_CHEST_FULL = "Coffre plein : vends tes objets au Marchand"
local TEXT_NEW_STRATUM = "Nouvelle couche : %s ! (%d m)"
local TEXT_DEEPER = "Tu descends à %d m"
local TEXT_STRATUM_BLOCKED = "Il te faut la %s pour creuser %s"
local TEXT_SHOVEL_EQUIPPED = "%s équipée !"
local TEXT_CHEST_BUTTON = "🧰\nCoffre"
-- Géométrie de la flèche, en fraction du disque
local ARROW_BAR_THICKNESS = 0.13
local ARROW_TIP_Y = 0.18
local ARROW_SHAFT_LENGTH = 0.62
local ARROW_HEAD_LENGTH = 0.36
local ARROW_HEAD_ANGLE = 40 -- degrés
local TEXT_ARROW_LABEL = "Marchand"

local player = Players.LocalPlayer

local HudController = {}

local depthLabel: TextLabel
local stratumLabel: TextLabel
local chestLabel: TextLabel
local chestPill: Frame
local coinsLabel: TextLabel
local banner: TextLabel
local arrowFrame: Frame
local arrowDial: Frame
local bannerGeneration = 0
local fullSound: Sound
local merchantPosition: Vector3? = nil
local protectionPill: Frame
local protectionLabel: TextLabel

-- 12345 -> "12 345"
local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (formatted:gsub("^ ", ""))
end

local function addCorner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius, 0)
	corner.Parent = parent
end

local function createPill(name: string, order: number, widthScale: number, parent: Instance): (Frame, TextLabel)
	local pill = Instance.new("Frame")
	pill.Name = name
	pill.LayoutOrder = order
	pill.Size = UDim2.fromScale(widthScale, 1)
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

local function buildTopBar(gui: ScreenGui)
	local bar = Instance.new("Frame")
	bar.Name = "TopBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, UiConfig.HUD_TOP_MARGIN)
	-- Centrée, et assez étroite pour laisser la place du compteur de Pièces de chaque côté.
	local reserved = 2 * (UiConfig.HUD_COINS_SIZE.X + 2 * UiConfig.HUD_MARGIN)
	bar.Size = UDim2.new(1, -reserved, 0.065, 0)
	bar.BackgroundTransparency = 1
	bar.Parent = gui

	local barLimit = Instance.new("UISizeConstraint")
	barLimit.MinSize = Vector2.new(300, 30)
	barLimit.MaxSize = Vector2.new(560, 46)
	barLimit.Parent = bar

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.02, 0)
	layout.Parent = bar

	local _depthPill, depth = createPill("Depth", 1, 0.38, bar)
	local _stratumPill, stratum = createPill("Stratum", 2, 0.24, bar)
	local pill, chest = createPill("Chest", 3, 0.34, bar)
	depthLabel, stratumLabel, chestLabel, chestPill = depth, stratum, chest, pill
end

local function buildCoins(gui: ScreenGui)
	local size = UiConfig.HUD_COINS_SIZE
	local pill = Instance.new("Frame")
	pill.Name = "Coins"
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.new(1, -UiConfig.HUD_MARGIN, 0, UiConfig.HUD_TOP_MARGIN)
	pill.Size = UDim2.fromOffset(size.X, size.Y)
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
	banner.Position = UDim2.new(0.5, 0, 0.1, 6)
	banner.Size = UDim2.fromScale(0.6, 0.06)
	banner.BackgroundColor3 = BANNER_ALERT
	banner.Font = Enum.Font.FredokaOne
	banner.TextScaled = true
	banner.TextColor3 = WHITE
	banner.Visible = false
	banner.Parent = gui
	addCorner(banner, 0.3)

	local bannerLimit = Instance.new("UISizeConstraint")
	bannerLimit.MinSize = Vector2.new(280, 28)
	bannerLimit.MaxSize = Vector2.new(620, 44)
	bannerLimit.Parent = banner

	local bannerPadding = Instance.new("UIPadding")
	bannerPadding.PaddingTop = UDim.new(0.15, 0)
	bannerPadding.PaddingBottom = UDim.new(0.15, 0)
	bannerPadding.PaddingLeft = UDim.new(0.03, 0)
	bannerPadding.PaddingRight = UDim.new(0.03, 0)
	bannerPadding.Parent = banner
end

-- Flèche qui tourne pour indiquer la direction du Marchand (affichée quand le coffre est plein).
local function buildMerchantArrow(gui: ScreenGui)
	local size = UiConfig.MERCHANT_ARROW_SIZE
	arrowFrame = Instance.new("Frame")
	arrowFrame.Name = "MerchantArrow"
	-- En haut à droite, sous le compteur de Pièces : au centre, elle cacherait l'avatar sur téléphone.
	arrowFrame.AnchorPoint = Vector2.new(1, 0)
	arrowFrame.Position = UDim2.new(
		1,
		-UiConfig.HUD_MARGIN,
		0,
		UiConfig.HUD_TOP_MARGIN + UiConfig.HUD_COINS_SIZE.Y + UiConfig.HUD_SPACING
	)
	arrowFrame.Size = UDim2.fromOffset(UiConfig.HUD_COINS_SIZE.X, size + 20)
	arrowFrame.BackgroundTransparency = 1
	arrowFrame.Visible = false
	arrowFrame.Parent = gui

	-- Disque qui tourne d'un bloc, avec une flèche dessinée (tige + deux branches), sans police.
	arrowDial = Instance.new("Frame")
	arrowDial.Name = "Arrow"
	arrowDial.AnchorPoint = Vector2.new(0.5, 0)
	arrowDial.Position = UDim2.fromScale(0.5, 0)
	arrowDial.Size = UDim2.fromOffset(size, size)
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
	caption.Size = UDim2.new(1, 0, 0, 20)
	caption.BackgroundColor3 = ARROW_BACKGROUND
	caption.BackgroundTransparency = 0.25
	addCorner(caption, 0.5)
	caption.Font = Enum.Font.FredokaOne
	caption.TextScaled = true
	caption.TextColor3 = WHITE
	caption.TextStrokeTransparency = 0.3
	caption.Text = TEXT_ARROW_LABEL
	caption.Parent = arrowFrame
end

-- Rappel de la protection débutant, sous le minuteur jour/nuit (en haut à gauche).
local function buildProtection(gui: ScreenGui)
	local size = UiConfig.DAY_NIGHT_TIMER_SIZE
	protectionPill = Instance.new("Frame")
	protectionPill.Name = "Protection"
	protectionPill.Position =
		UDim2.fromOffset(UiConfig.HUD_MARGIN, UiConfig.HUD_TOP_MARGIN + size.Y + UiConfig.HUD_SPACING)
	protectionPill.Size = UDim2.fromOffset(size.X, size.Y)
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
		protectionLabel.Text = string.format(TEXT_PROTECTED, math.ceil(remaining / 60))
	end
end

local function buildChestButton(gui: ScreenGui)
	-- Bord gauche, à mi-hauteur : hors du joystick et du bouton de saut sur mobile.
	local chestButton = Instance.new("TextButton")
	chestButton.Name = "ChestButton"
	chestButton.AnchorPoint = Vector2.new(0, 0.5)
	chestButton.Position = UDim2.new(0, UiConfig.HUD_MARGIN, 0.45, 0)
	chestButton.Size = UDim2.fromOffset(UiConfig.HUD_CHEST_BUTTON_SIZE, UiConfig.HUD_CHEST_BUTTON_SIZE)
	chestButton.BackgroundColor3 = CHEST_BUTTON_COLOR
	chestButton.Font = Enum.Font.FredokaOne
	chestButton.TextScaled = true
	chestButton.TextColor3 = WHITE
	chestButton.Text = TEXT_CHEST_BUTTON
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

local function buildUi()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HudGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	buildTopBar(gui)
	buildCoins(gui)
	buildBanner(gui)
	buildMerchantArrow(gui)
	buildProtection(gui)
	buildChestButton(gui)
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function readNumberAttribute(name: string, default: number): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function isChestFull(): boolean
	return readNumberAttribute("InventoryCount", 0) >= PlayerConfig.INVENTORY_LIMIT
end

local function refresh()
	local depth = readNumberAttribute("Depth", 0)
	local count = readNumberAttribute("InventoryCount", 0)
	depthLabel.Text = string.format(TEXT_DEPTH, depth)
	stratumLabel.Text = Strata.fromDepth(depth).name
	chestLabel.Text = string.format(TEXT_CHEST, count, PlayerConfig.INVENTORY_LIMIT)
	chestPill.BackgroundColor3 = if count >= PlayerConfig.INVENTORY_LIMIT then PILL_FULL_BACKGROUND else PILL_BACKGROUND
	coinsLabel.Text = string.format(TEXT_COINS, formatNumber(readNumberAttribute("Coins", 0)))
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
	if not isChestFull() or rootPart == nil or not rootPart:IsA("BasePart") or camera == nil then
		arrowFrame.Visible = false
		return
	end
	if merchantPosition == nil then
		merchantPosition = findMerchantPosition()
	end
	local target = merchantPosition
	if target == nil then
		arrowFrame.Visible = false
		return
	end

	local toMerchant = (target - rootPart.Position) * Vector3.new(1, 0, 1)
	if toMerchant.Magnitude <= EconomyConfig.MERCHANT_MAX_DISTANCE then
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

-- Bandeau d'information, utilisable par les autres contrôleurs (nuit, vol...).
function HudController.showBanner(text: string, kind: BannerKind, long: boolean?)
	local color = if kind == "alert" then BANNER_ALERT elseif kind == "success" then BANNER_SUCCESS else BANNER_INFO
	showBanner(text, color, if long then UiConfig.BANNER_LONG_TIME else nil)
end

function HudController.init()
	buildUi()
	fullSound = Instance.new("Sound")
	fullSound.Name = "InventoryFull"
	fullSound.SoundId = UiConfig.SOUND_INVENTORY_FULL
	fullSound.Volume = UiConfig.VOLUME_INVENTORY_FULL
	fullSound.Parent = SoundService
	refresh()
end

function HudController.start()
	for _, name in { "Depth", "InventoryCount", "Coins" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	Remotes.get(Remotes.Names.InventoryFull).OnClientEvent:Connect(function()
		showBanner(TEXT_CHEST_FULL, BANNER_ALERT, UiConfig.BANNER_LONG_TIME)
		fullSound:Play()
	end)

	Remotes.get(Remotes.Names.LayerCleared).OnClientEvent:Connect(function(layer: unknown, depth: unknown)
		if typeof(layer) ~= "number" or typeof(depth) ~= "number" then
			return
		end
		local stratum = Strata.byLayer[layer]
		local previous = Strata.fromDepth(depth - PlotConfig.DEPTH_PER_LAYER)
		if stratum ~= nil and stratum.id ~= previous.id then
			showBanner(string.format(TEXT_NEW_STRATUM, stratum.nameWithArticle, depth), BANNER_SUCCESS)
		else
			showBanner(string.format(TEXT_DEEPER, depth), BANNER_SUCCESS)
		end
	end)

	Remotes.get(Remotes.Names.StratumBlocked).OnClientEvent:Connect(function(requiredShovel: unknown)
		local shovel = if typeof(requiredShovel) == "string" then Shovels.byId[requiredShovel] else nil
		if shovel == nil then
			return
		end
		local stratum = Strata.byId[shovel.maxStratum]
		showBanner(
			string.format(TEXT_STRATUM_BLOCKED, shovel.name, stratum.nameWithArticle),
			BANNER_ALERT,
			UiConfig.BANNER_LONG_TIME
		)
		fullSound:Play()
	end)

	Remotes.get(Remotes.Names.ShovelChanged).OnClientEvent:Connect(function(shovelId: unknown)
		local shovel = if typeof(shovelId) == "string" then Shovels.byId[shovelId] else nil
		if shovel ~= nil then
			showBanner(string.format(TEXT_SHOVEL_EQUIPPED, shovel.name), BANNER_INFO)
		end
	end)

	RunService.RenderStepped:Connect(updateMerchantArrow)
	RunService.RenderStepped:Connect(updateProtection)
end

return HudController
