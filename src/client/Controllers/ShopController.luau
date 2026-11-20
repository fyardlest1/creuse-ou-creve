--!strict
-- Boutique : deux onglets (Passes, Bonus). Chaque carte donne l'effet en une phrase, le prix en Robux,
-- et "Possédé" pour un pass acheté. Les achats impossibles maintenant sont grisés avec la raison, calculée
-- par le serveur (ShopState) : le client ne fait qu'afficher et demander l'achat (PurchaseRequest).
-- Les produits de chance sont masqués si les objets aléatoires payants sont restreints pour le joueur.
-- L'onglet Bonus affiche les probabilités de rareté, avec et sans les bonus du joueur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local UiConfig = require(Shared.Config.UiConfig)
local Remotes = require(Shared.Remotes)
local UiKit = require(script.Parent.Parent.UiKit)

type Tab = "Passes" | "Bonus"

local WHITE = Color3.new(1, 1, 1)
local PANEL_BACKGROUND = Color3.fromRGB(28, 26, 34)
local CARD_BACKGROUND = Color3.fromRGB(44, 41, 54)
local MUTED_TEXT = Color3.fromRGB(190, 190, 200)
local BUY_COLOR = Color3.fromRGB(60, 170, 80)
local OWNED_COLOR = Color3.fromRGB(70, 120, 200)
local DISABLED_COLOR = Color3.fromRGB(80, 80, 90)
local TAB_ON_COLOR = Color3.fromRGB(230, 160, 40)
local TAB_OFF_COLOR = Color3.fromRGB(60, 58, 72)
local CLOSE_COLOR = Color3.fromRGB(200, 60, 60)
local PRICE_COLOR = Color3.fromRGB(255, 205, 60)

local TEXT_TITLE = "Boutique"
local TEXT_TAB_PASSES = "Passes"
local TEXT_TAB_BONUS = "Bonus"
local TEXT_CLOSE = "X"
local TEXT_PRICE = "%d R$"
local TEXT_BUY = "Acheter"
local TEXT_OWNED = "Possédé"
local TEXT_LOADING = "..."

local player = Players.LocalPlayer

local ShopController = {}

local gui: ScreenGui
local list: ScrollingFrame
local tabButtons: { [Tab]: TextButton } = {}
local currentTab: Tab = "Passes"
local shopState: { [string]: string } = {}
local purchaseRequest: RemoteEvent
local stateRequest: RemoteEvent

local function addCorner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius, 0)
	corner.Parent = parent
end

local function addPadding(parent: GuiObject, vertical: number, horizontal: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, vertical)
	padding.PaddingBottom = UDim.new(0, vertical)
	padding.PaddingLeft = UDim.new(0, horizontal)
	padding.PaddingRight = UDim.new(0, horizontal)
	padding.Parent = parent
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

local function createButton(name: string, text: string, color: Color3, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = color
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = WHITE
	button.Text = text
	button.Parent = parent
	addCorner(button, 0.25)
	addPadding(button, 6, 8)
	return button
end

local function isRestricted(): boolean
	return player:GetAttribute("PaidRandomItemsRestricted") == true
end

local function createCard(def: any, order: number)
	local card = Instance.new("Frame")
	card.Name = def.key
	card.LayoutOrder = order
	card.Size = UDim2.new(1, -12, 0, UiConfig.SHOP_CARD_HEIGHT)
	card.BackgroundColor3 = CARD_BACKGROUND
	card.Parent = list
	addCorner(card, 0.1)
	addPadding(card, 8, 12)

	local name = createLabel("ItemName", def.name, card)
	name.Size = UDim2.new(0.62, 0, 0, UiConfig.SHOP_TITLE_HEIGHT)
	name.TextXAlignment = Enum.TextXAlignment.Left

	local price = createLabel("Price", string.format(TEXT_PRICE, def.price), card)
	price.AnchorPoint = Vector2.new(1, 0)
	price.Position = UDim2.fromScale(1, 0)
	price.Size = UDim2.new(0.36, 0, 0, UiConfig.SHOP_TITLE_HEIGHT)
	price.TextXAlignment = Enum.TextXAlignment.Right
	price.TextColor3 = PRICE_COLOR

	local description = createLabel("Description", def.description, card)
	description.Position = UDim2.fromOffset(0, UiConfig.SHOP_TITLE_HEIGHT + 2)
	description.Size = UDim2.new(0.62, 0, 1, -(UiConfig.SHOP_TITLE_HEIGHT + 2))
	description.TextWrapped = true
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.TextColor3 = MUTED_TEXT
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = UiConfig.SHOP_DESCRIPTION_MAX_TEXT
	limit.Parent = description

	-- État : "" = achetable, "owned" = pass possédé, sinon la raison (grisé). nil = en attente du serveur.
	local state = shopState[def.key]
	local text, color, enabled
	if state == nil then
		text, color, enabled = TEXT_LOADING, DISABLED_COLOR, false
	elseif state == "owned" then
		text, color, enabled = TEXT_OWNED, OWNED_COLOR, false
	elseif state == "" then
		text, color, enabled = TEXT_BUY, BUY_COLOR, true
	else
		text, color, enabled = state, DISABLED_COLOR, false
	end
	local button = createButton("Action", text, color, card)
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.fromScale(1, 1)
	button.Size = UDim2.new(0.36, 0, 0, UiConfig.TOUCH_TARGET_MIN)
	button.AutoButtonColor = enabled
	if enabled then
		button.Activated:Connect(function()
			purchaseRequest:FireServer(def.key)
		end)
	end
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
	for tab, button in tabButtons do
		button.BackgroundColor3 = if tab == currentTab then TAB_ON_COLOR else TAB_OFF_COLOR
	end
	local restricted = isRestricted()
	local defs: { any } = if currentTab == "Passes" then MonetizationConfig.passes else MonetizationConfig.products
	local order = 0
	for _, def in defs do
		if not (def.isLuck and restricted) then
			order += 1
			createCard(def, order)
		end
	end
	if currentTab == "Bonus" then
		UiKit.oddsBlock(list, order + 1)
	end
end

local function buildUi()
	gui = Instance.new("ScreenGui")
	gui.Name = "ShopGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Enabled = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(UiConfig.PANEL_SIZE_SCALE.X, UiConfig.PANEL_SIZE_SCALE.Y)
	panel.BackgroundColor3 = PANEL_BACKGROUND
	panel.BackgroundTransparency = 0.05
	panel.Parent = gui
	addCorner(panel, 0.04)
	addPadding(panel, 10, 12)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = UiConfig.SHOP_PANEL_MAX_SIZE
	sizeLimit.Parent = panel

	local header = UiConfig.TOUCH_TARGET_MIN
	local title = createLabel("Title", TEXT_TITLE, panel)
	title.Size = UDim2.new(0.28, 0, 0, header)
	title.TextXAlignment = Enum.TextXAlignment.Left

	for index, tab in { "Passes", "Bonus" } :: { Tab } do
		local button = createButton(
			"Tab" .. tab,
			if tab == "Passes" then TEXT_TAB_PASSES else TEXT_TAB_BONUS,
			TAB_OFF_COLOR,
			panel
		)
		button.Position = UDim2.new(0.3 + (index - 1) * 0.22, 0, 0, 0)
		button.Size = UDim2.new(0.2, 0, 0, header)
		button.Activated:Connect(function()
			currentTab = tab
			render()
		end)
		tabButtons[tab] = button
	end

	local close = createButton("Close", TEXT_CLOSE, CLOSE_COLOR, panel)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(header, header)
	close.Activated:Connect(function()
		ShopController.close()
	end)

	list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(0, header + 8)
	list.Size = UDim2.new(1, 0, 1, -(header + 8))
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

function ShopController.open(tab: Tab?)
	currentTab = tab or currentTab
	gui.Enabled = true
	stateRequest:FireServer()
	render()
end

function ShopController.close()
	gui.Enabled = false
end

function ShopController.toggle()
	if gui.Enabled then
		ShopController.close()
	else
		ShopController.open()
	end
end

function ShopController.init()
	purchaseRequest = Remotes.get(Remotes.Names.PurchaseRequest)
	stateRequest = Remotes.get(Remotes.Names.ShopStateRequest)
	buildUi()
end

function ShopController.start()
	Remotes.get(Remotes.Names.ShopState).OnClientEvent:Connect(function(state: unknown)
		if typeof(state) == "table" then
			shopState = state :: { [string]: string }
			render()
		end
	end)
	-- Tant que la boutique est ouverte, l'état suit (nuit, événement, pass acheté...).
	task.spawn(function()
		while true do
			task.wait(UiConfig.SHOP_REFRESH_INTERVAL)
			if gui.Enabled then
				stateRequest:FireServer()
			end
		end
	end)
	for _, name in { "OwnedPasses", "LuckMultiplier", "PaidRandomItemsRestricted" } do
		player:GetAttributeChangedSignal(name):Connect(render)
	end
end

return ShopController
