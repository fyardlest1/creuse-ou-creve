--!strict
-- Forge : liste des pelles avec prix, coups par case, bonus de chance et couche accessible.
-- États : Équipée, Possédée, Acheter (grisé avec le montant manquant), Bloquée (pelle précédente requise).
-- Le client n'envoie que l'intention d'achat ; le serveur valide et répond par ShovelChanged.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Shovels = require(Shared.Config.Shovels)
local Strata = require(Shared.Config.Strata)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local UiConfig = require(Shared.Config.UiConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local Remotes = require(Shared.Remotes)

local WHITE = Color3.new(1, 1, 1)
local PANEL_BACKGROUND = Color3.fromRGB(28, 26, 34)
local ROW_BACKGROUND = Color3.fromRGB(44, 41, 54)
local MUTED_TEXT = Color3.fromRGB(190, 190, 200)
local BUY_COLOR = Color3.fromRGB(60, 170, 80)
local DISABLED_COLOR = Color3.fromRGB(80, 80, 90)
local EQUIPPED_COLOR = Color3.fromRGB(240, 190, 60)
local OWNED_COLOR = Color3.fromRGB(70, 120, 200)
local CLOSE_COLOR = Color3.fromRGB(200, 60, 60)

local TEXT_TITLE = "Forge"
local TEXT_CLOSE = "X"
local TEXT_PRICE_FREE = "Gratuite"
local TEXT_PRICE = "%s Pièces"
local TEXT_STATS = "%d coups par case  •  Chance +%d %%  •  Jusqu'à : %s"
local TEXT_EQUIPPED = "Équipée"
local TEXT_OWNED = "Possédée"
local TEXT_BUY = "Acheter (%s)"
local TEXT_MISSING = "Il manque %s Pièces"
local TEXT_LOCKED = "Bloquée : %s requise"
local TEXT_COINS = "Tes Pièces : %s"

local player = Players.LocalPlayer

local ForgeController = {}

local gui: ScreenGui
local list: ScrollingFrame
local coinsLabel: TextLabel
local buyShovelRemote: RemoteEvent
local buySound: Sound
local forgePosition: Vector3? = nil
local awaitingResult = false

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

local function createLabel(name: string, text: string, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.Text = text
	label.Parent = parent
	return label
end

local function getCoins(): number
	local value = player:GetAttribute("Coins")
	return if typeof(value) == "number" then value else 0
end

local function getOwned(): { [string]: boolean }
	local owned: { [string]: boolean } = {}
	local value = player:GetAttribute("OwnedShovels")
	if typeof(value) == "string" then
		for _, id in value:split(",") do
			owned[id] = true
		end
	end
	owned[Shovels.DEFAULT_ID] = true
	return owned
end

-- Texte, couleur et activation du bouton d'une pelle.
local function getButtonState(shovel: Types.ShovelDef, owned: { [string]: boolean }): (string, Color3, boolean)
	if player:GetAttribute("EquippedShovel") == shovel.id then
		return TEXT_EQUIPPED, EQUIPPED_COLOR, false
	end
	if owned[shovel.id] then
		return TEXT_OWNED, OWNED_COLOR, false
	end
	local previous = Shovels.getPrevious(shovel.id)
	if previous ~= nil and not owned[previous.id] then
		return string.format(TEXT_LOCKED, previous.name), DISABLED_COLOR, false
	end
	local missing = shovel.price - getCoins()
	if missing > 0 then
		return string.format(TEXT_MISSING, formatNumber(missing)), DISABLED_COLOR, false
	end
	return string.format(TEXT_BUY, string.format(TEXT_PRICE, formatNumber(shovel.price))), BUY_COLOR, true
end

local function createRow(shovel: Types.ShovelDef, order: number, owned: { [string]: boolean })
	local row = Instance.new("Frame")
	row.Name = shovel.id
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -12, 0, UiConfig.FORGE_ROW_HEIGHT)
	row.BackgroundColor3 = ROW_BACKGROUND
	addCorner(row, 0.12)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = row

	local nameLabel = createLabel("ShovelName", shovel.name, row)
	nameLabel.Size = UDim2.fromScale(0.42, 0.38)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left

	local priceText = if shovel.price == 0
		then TEXT_PRICE_FREE
		else string.format(TEXT_PRICE, formatNumber(shovel.price))
	local priceLabel = createLabel("Price", priceText, row)
	priceLabel.Position = UDim2.fromScale(0.42, 0)
	priceLabel.Size = UDim2.fromScale(0.2, 0.38)
	priceLabel.TextColor3 = EQUIPPED_COLOR
	priceLabel.TextXAlignment = Enum.TextXAlignment.Left

	local stats = createLabel(
		"Stats",
		string.format(TEXT_STATS, shovel.hitsPerCell, shovel.luckBonus, Strata.byId[shovel.maxStratum].name),
		row
	)
	stats.Position = UDim2.fromScale(0, 0.5)
	stats.Size = UDim2.fromScale(0.62, 0.32)
	stats.TextColor3 = MUTED_TEXT
	stats.TextXAlignment = Enum.TextXAlignment.Left

	local text, color, enabled = getButtonState(shovel, owned)
	local button = Instance.new("TextButton")
	button.Name = "Action"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.fromScale(1, 0.5)
	button.Size = UDim2.new(0.36, 0, 0, UiConfig.CHEST_BUTTON_MIN_HEIGHT + 8)
	button.BackgroundColor3 = color
	button.AutoButtonColor = enabled
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = WHITE
	button.Text = text
	button.Parent = row
	addCorner(button, 0.25)

	local buttonPadding = Instance.new("UIPadding")
	buttonPadding.PaddingTop = UDim.new(0.18, 0)
	buttonPadding.PaddingBottom = UDim.new(0.18, 0)
	buttonPadding.PaddingLeft = UDim.new(0.05, 0)
	buttonPadding.PaddingRight = UDim.new(0.05, 0)
	buttonPadding.Parent = button

	if enabled then
		button.Activated:Connect(function()
			if awaitingResult then
				return
			end
			awaitingResult = true
			buyShovelRemote:FireServer(shovel.id)
			task.delay(EconomyConfig.BUY_COOLDOWN, function()
				awaitingResult = false
			end)
		end)
	end

	row.Parent = list
end

local function render()
	if gui == nil or not gui.Enabled then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	coinsLabel.Text = string.format(TEXT_COINS, formatNumber(getCoins()))
	local owned = getOwned()
	for order, shovel in Shovels.list do
		createRow(shovel, order, owned)
	end
end

local function buildUi()
	gui = Instance.new("ScreenGui")
	gui.Name = "ForgeGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Enabled = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.55)
	panel.Size = UDim2.fromScale(0.92, 0.8)
	panel.BackgroundColor3 = PANEL_BACKGROUND
	panel.BackgroundTransparency = 0.05
	panel.Parent = gui
	addCorner(panel, 0.04)

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = UiConfig.FORGE_PANEL_MAX_SIZE
	limit.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel

	local headerHeight = UiConfig.CHEST_BUTTON_MIN_HEIGHT
	local title = createLabel("Title", TEXT_TITLE, panel)
	title.Size = UDim2.new(0.3, 0, 0, headerHeight)
	title.TextXAlignment = Enum.TextXAlignment.Left

	coinsLabel = createLabel("Coins", "", panel)
	coinsLabel.AnchorPoint = Vector2.new(1, 0)
	coinsLabel.Position = UDim2.new(1, -(headerHeight + 10), 0, 0)
	coinsLabel.Size = UDim2.new(0.45, 0, 0, headerHeight)
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
	coinsLabel.TextColor3 = EQUIPPED_COLOR

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.fromScale(1, 0)
	closeButton.Size = UDim2.fromOffset(headerHeight, headerHeight)
	closeButton.BackgroundColor3 = CLOSE_COLOR
	closeButton.Font = Enum.Font.FredokaOne
	closeButton.TextScaled = true
	closeButton.TextColor3 = WHITE
	closeButton.Text = TEXT_CLOSE
	closeButton.Parent = panel
	addCorner(closeButton, 0.25)
	closeButton.Activated:Connect(function()
		ForgeController.close()
	end)

	list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.new(0, 0, 0, headerHeight + 10)
	list.Size = UDim2.new(1, 0, 1, -(headerHeight + 10))
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function getCharacterPosition(): Vector3?
	local character = player.Character
	local rootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if rootPart ~= nil and rootPart:IsA("BasePart") then rootPart.Position else nil
end

-- Ferme la Forge quand le joueur s'éloigne (le serveur refuserait de toute façon).
local function watchDistance()
	while gui.Enabled and forgePosition ~= nil do
		local position = getCharacterPosition()
		if position == nil or (position - forgePosition).Magnitude > EconomyConfig.FORGE_MAX_DISTANCE then
			ForgeController.close()
			break
		end
		task.wait(UiConfig.MERCHANT_CLOSE_CHECK_INTERVAL)
	end
end

local function onPromptTriggered(prompt: ProximityPrompt)
	if prompt:GetAttribute(WorldConfig.INTERACTION_ATTRIBUTE) ~= WorldConfig.INTERACTIONS.Forge then
		return
	end
	local anchor = prompt.Parent
	forgePosition = if anchor ~= nil and anchor:IsA("Attachment") then anchor.WorldPosition else nil
	ForgeController.open()
	task.spawn(watchDistance)
end

function ForgeController.open()
	gui.Enabled = true
	render()
end

function ForgeController.close()
	gui.Enabled = false
end

function ForgeController.init()
	buildUi()
	buyShovelRemote = Remotes.get(Remotes.Names.BuyShovel)
	buySound = Instance.new("Sound")
	buySound.Name = "BuyShovel"
	buySound.SoundId = UiConfig.SOUND_REVEAL_SPECTACULAR
	buySound.Volume = UiConfig.VOLUME_REVEAL
	buySound.Parent = SoundService
end

function ForgeController.start()
	ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
	Remotes.get(Remotes.Names.ShovelChanged).OnClientEvent:Connect(function(_shovelId: unknown)
		awaitingResult = false
		buySound:Play()
		render()
	end)
	for _, name in { "Coins", "OwnedShovels", "EquippedShovel" } do
		player:GetAttributeChangedSignal(name):Connect(render)
	end
end

return ForgeController
