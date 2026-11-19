--!strict
-- Barre du haut : profondeur, couche, inventaire. Bandeaux d'information (inventaire plein, nouvelle couche).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerConfig = require(Shared.Config.PlayerConfig)
local UiConfig = require(Shared.Config.UiConfig)
local Remotes = require(Shared.Remotes)

local PILL_BACKGROUND = Color3.fromRGB(28, 26, 34)
local PILL_FULL_BACKGROUND = Color3.fromRGB(170, 40, 40)
local BANNER_ALERT = Color3.fromRGB(200, 45, 45)
local BANNER_SUCCESS = Color3.fromRGB(50, 150, 70)
local WHITE = Color3.new(1, 1, 1)
local PILL_MAX_TEXT_SIZE = 22

local TEXT_DEPTH = "Profondeur : %d m"
local TEXT_LAYER = "Couche %d"
local TEXT_INVENTORY = "Sac : %d/%d"
-- Semaine 2 : remplacer par « Vends tes objets au marchand ».
local TEXT_INVENTORY_FULL = "Inventaire plein !"
local TEXT_LAYER_CLEARED = "Couche %d atteinte ! (%d m)"

local player = Players.LocalPlayer

local HudController = {}

local depthLabel: TextLabel
local layerLabel: TextLabel
local inventoryLabel: TextLabel
local inventoryPill: Frame
local banner: TextLabel
local bannerGeneration = 0
local fullSound: Sound

local function createPill(name: string, order: number, widthScale: number, parent: Instance): (Frame, TextLabel)
	local pill = Instance.new("Frame")
	pill.Name = name
	pill.LayoutOrder = order
	pill.Size = UDim2.fromScale(widthScale, 1)
	pill.BackgroundColor3 = PILL_BACKGROUND
	pill.BackgroundTransparency = 0.15
	pill.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = pill

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

local function buildUi()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HudGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5

	local bar = Instance.new("Frame")
	bar.Name = "TopBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 6)
	bar.Size = UDim2.fromScale(0.62, 0.065)
	bar.BackgroundTransparency = 1
	bar.Parent = gui

	local barLimit = Instance.new("UISizeConstraint")
	barLimit.MinSize = Vector2.new(300, 30)
	barLimit.MaxSize = Vector2.new(620, 46)
	barLimit.Parent = bar

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.02, 0)
	layout.Parent = bar

	local _depthPill, depth = createPill("Depth", 1, 0.4, bar)
	local _layerPill, layer = createPill("Layer", 2, 0.24, bar)
	local invPill, inventory = createPill("Inventory", 3, 0.3, bar)
	depthLabel, layerLabel, inventoryLabel, inventoryPill = depth, layer, inventory, invPill

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

	local bannerLimit = Instance.new("UISizeConstraint")
	bannerLimit.MinSize = Vector2.new(280, 28)
	bannerLimit.MaxSize = Vector2.new(560, 44)
	bannerLimit.Parent = banner

	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = UDim.new(0.3, 0)
	bannerCorner.Parent = banner

	local bannerPadding = Instance.new("UIPadding")
	bannerPadding.PaddingTop = UDim.new(0.15, 0)
	bannerPadding.PaddingBottom = UDim.new(0.15, 0)
	bannerPadding.PaddingLeft = UDim.new(0.03, 0)
	bannerPadding.PaddingRight = UDim.new(0.03, 0)
	bannerPadding.Parent = banner

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function readNumberAttribute(name: string, default: number): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function refresh()
	local depth = readNumberAttribute("Depth", 0)
	local layer = readNumberAttribute("Layer", 1)
	local count = readNumberAttribute("InventoryCount", 0)
	depthLabel.Text = string.format(TEXT_DEPTH, depth)
	layerLabel.Text = string.format(TEXT_LAYER, layer)
	inventoryLabel.Text = string.format(TEXT_INVENTORY, count, PlayerConfig.INVENTORY_LIMIT)
	inventoryPill.BackgroundColor3 = if count >= PlayerConfig.INVENTORY_LIMIT
		then PILL_FULL_BACKGROUND
		else PILL_BACKGROUND
end

local function showBanner(text: string, color: Color3)
	bannerGeneration += 1
	local myGeneration = bannerGeneration
	banner.Text = text
	banner.BackgroundColor3 = color
	banner.BackgroundTransparency = 0.1
	banner.TextTransparency = 0
	banner.Visible = true

	task.delay(UiConfig.BANNER_TIME, function()
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
	for _, name in { "Depth", "Layer", "InventoryCount" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end

	Remotes.get(Remotes.Names.InventoryFull).OnClientEvent:Connect(function()
		showBanner(TEXT_INVENTORY_FULL, BANNER_ALERT)
		fullSound:Play()
	end)

	Remotes.get(Remotes.Names.LayerCleared).OnClientEvent:Connect(function(layer: unknown, depth: unknown)
		if typeof(layer) == "number" and typeof(depth) == "number" then
			showBanner(string.format(TEXT_LAYER_CLEARED, layer, depth), BANNER_SUCCESS)
		end
	end)
end

return HudController
