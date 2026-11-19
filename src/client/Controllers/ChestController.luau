--!strict
-- Interface du coffre : grille de cartes triée par valeur décroissante, compteur "18/30".
-- Mode "view" pour consulter, mode "sell" (ouvert par le Marchand) avec "Tout vendre" et "Vendre" par carte.
-- Le coffre affiché est toujours celui envoyé par le serveur (InventoryUpdated).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Items = require(Shared.Config.Items)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local UiConfig = require(Shared.Config.UiConfig)
local Remotes = require(Shared.Remotes)

export type ChestMode = "view" | "sell"
export type SellCallbacks = {
	sellOne: (uid: string) -> (),
	sellAll: () -> (),
}

local WHITE = Color3.new(1, 1, 1)
local PANEL_BACKGROUND = Color3.fromRGB(28, 26, 34)
local CARD_BACKGROUND = Color3.fromRGB(44, 41, 54)
local SELL_ALL_COLOR = Color3.fromRGB(60, 170, 80)
local SELL_ALL_DISABLED_COLOR = Color3.fromRGB(80, 80, 90)
local SELL_ONE_COLOR = Color3.fromRGB(230, 160, 40)
local CLOSE_COLOR = Color3.fromRGB(200, 60, 60)
local MUTED_TEXT = Color3.fromRGB(190, 190, 200)

local TEXT_TITLE = "Coffre"
local TEXT_TITLE_SELL = "Marchand"
local TEXT_COUNTER = "%d/%d"
local TEXT_VALUE = "%s Pièces"
local TEXT_SELL_ONE = "Vendre"
local TEXT_SELL_ALL = "Tout vendre (%s Pièces)"
local TEXT_EMPTY = "Ton coffre est vide. Va creuser !"
local TEXT_CLOSE = "X"

local player = Players.LocalPlayer

local ChestController = {}

local inventory: { Types.ItemInstance } = {}
local mode: ChestMode = "view"
local sellCallbacks: SellCallbacks? = nil
local changedCallbacks: { () -> () } = {}

local gui: ScreenGui
local titleLabel: TextLabel
local counterLabel: TextLabel
local sellAllButton: TextButton
local grid: ScrollingFrame
local emptyLabel: TextLabel

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
	button.AutoButtonColor = true
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = WHITE
	button.Text = text
	button.Parent = parent
	addCorner(button, 0.25)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.15, 0)
	padding.PaddingBottom = UDim.new(0.15, 0)
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.Parent = button
	return button
end

-- Copie triée par valeur décroissante (uid en cas d'égalité, pour un ordre stable).
local function getSortedItems(): { Types.ItemInstance }
	local sorted = table.clone(inventory)
	table.sort(sorted, function(a, b)
		if a.value ~= b.value then
			return a.value > b.value
		end
		return a.uid < b.uid
	end)
	return sorted
end

local function getSellableTotal(): number
	local total = 0
	for _, item in inventory do
		if not item.favorite then
			total += item.value
		end
	end
	return total
end

local function createCard(item: Types.ItemInstance, order: number): Frame
	local rarity = Rarities.byId[item.rarity]
	local itemDef = Items.byId[item.itemId]
	local rarityColor = if rarity ~= nil then rarity.color else MUTED_TEXT

	local card = Instance.new("Frame")
	card.Name = item.uid
	card.LayoutOrder = order
	card.BackgroundColor3 = CARD_BACKGROUND
	addCorner(card, 0.08)

	local stroke = Instance.new("UIStroke")
	stroke.Color = rarityColor
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = card

	local rarityLabel = createLabel("Rarity", if rarity ~= nil then rarity.displayName else item.rarity, card)
	rarityLabel.Size = UDim2.fromScale(1, 0.14)
	rarityLabel.TextColor3 = rarityColor

	local nameLabel = createLabel("ItemName", if itemDef ~= nil then itemDef.name else item.itemId, card)
	nameLabel.Position = UDim2.fromScale(0, 0.15)
	nameLabel.Size = UDim2.fromScale(1, 0.3)
	nameLabel.TextWrapped = true

	local mutation = if item.mutation ~= nil then Mutations.byId[item.mutation] else nil
	if mutation ~= nil then
		local badge = createLabel("Mutation", mutation.displayName, card)
		badge.Position = UDim2.fromScale(0.15, 0.46)
		badge.Size = UDim2.fromScale(0.7, 0.12)
		badge.BackgroundTransparency = 0
		badge.BackgroundColor3 = mutation.color
		badge.TextColor3 = PANEL_BACKGROUND
		addCorner(badge, 0.5)
	end

	local valueLabel = createLabel("Value", string.format(TEXT_VALUE, formatNumber(item.value)), card)
	valueLabel.Position = UDim2.fromScale(0, 0.6)
	valueLabel.Size = UDim2.fromScale(1, 0.14)
	valueLabel.TextColor3 = MUTED_TEXT

	if mode == "sell" and not item.favorite then
		local sellButton = createButton("Sell", TEXT_SELL_ONE, SELL_ONE_COLOR, card)
		sellButton.AnchorPoint = Vector2.new(0.5, 1)
		sellButton.Position = UDim2.fromScale(0.5, 1)
		sellButton.Size = UDim2.new(0.9, 0, 0.22, 0)
		sellButton.Activated:Connect(function()
			if sellCallbacks ~= nil then
				sellCallbacks.sellOne(item.uid)
			end
		end)
	end

	return card
end

local function render()
	if gui == nil or not gui.Enabled then
		return
	end
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	titleLabel.Text = if mode == "sell" then TEXT_TITLE_SELL else TEXT_TITLE
	counterLabel.Text = string.format(TEXT_COUNTER, #inventory, PlayerConfig.INVENTORY_LIMIT)

	local sellable = getSellableTotal()
	sellAllButton.Visible = mode == "sell"
	sellAllButton.Text = string.format(TEXT_SELL_ALL, formatNumber(sellable))
	sellAllButton.BackgroundColor3 = if sellable > 0 then SELL_ALL_COLOR else SELL_ALL_DISABLED_COLOR
	sellAllButton.Active = sellable > 0

	emptyLabel.Visible = #inventory == 0
	for order, item in getSortedItems() do
		createCard(item, order).Parent = grid
	end
end

local function buildUi()
	gui = Instance.new("ScreenGui")
	gui.Name = "ChestGui"
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
	limit.MaxSize = UiConfig.CHEST_PANEL_MAX_SIZE
	limit.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel

	-- En-tête : titre, compteur, bouton fermer
	local headerHeight = UiConfig.CHEST_BUTTON_MIN_HEIGHT
	titleLabel = createLabel("Title", TEXT_TITLE, panel)
	titleLabel.Size = UDim2.new(0.4, 0, 0, headerHeight)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left

	counterLabel = createLabel("Counter", "", panel)
	counterLabel.AnchorPoint = Vector2.new(1, 0)
	counterLabel.Position = UDim2.new(1, -(headerHeight + 10), 0, 0)
	counterLabel.Size = UDim2.new(0.25, 0, 0, headerHeight)
	counterLabel.TextXAlignment = Enum.TextXAlignment.Right

	local closeButton = createButton("Close", TEXT_CLOSE, CLOSE_COLOR, panel)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.fromScale(1, 0)
	closeButton.Size = UDim2.fromOffset(headerHeight, headerHeight)
	closeButton.Activated:Connect(function()
		ChestController.close()
	end)

	-- Bouton "Tout vendre", bien visible sous l'en-tête (mode vente seulement)
	sellAllButton = createButton("SellAll", "", SELL_ALL_COLOR, panel)
	sellAllButton.Position = UDim2.new(0, 0, 0, headerHeight + 8)
	sellAllButton.Size = UDim2.new(1, 0, 0, headerHeight + 8)
	sellAllButton.Activated:Connect(function()
		if sellCallbacks ~= nil and getSellableTotal() > 0 then
			sellCallbacks.sellAll()
		end
	end)

	grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 8
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.Parent = panel

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(UiConfig.CHEST_CARD_SIZE.X, UiConfig.CHEST_CARD_SIZE.Y)
	layout.CellPadding = UDim2.fromOffset(UiConfig.CHEST_CARD_PADDING, UiConfig.CHEST_CARD_PADDING)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 4)
	gridPadding.PaddingBottom = UDim.new(0, 4)
	gridPadding.Parent = grid

	emptyLabel = createLabel("Empty", TEXT_EMPTY, panel)
	emptyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	emptyLabel.Position = UDim2.fromScale(0.5, 0.55)
	emptyLabel.Size = UDim2.fromScale(0.8, 0.1)
	emptyLabel.TextColor3 = MUTED_TEXT
	emptyLabel.Visible = false

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- La grille prend la place restante sous l'en-tête (et sous "Tout vendre" en mode vente).
local function layoutGrid()
	local headerHeight = UiConfig.CHEST_BUTTON_MIN_HEIGHT
	local top = if mode == "sell" then headerHeight * 2 + 24 else headerHeight + 8
	grid.Position = UDim2.new(0, 0, 0, top)
	grid.Size = UDim2.new(1, 0, 1, -top)
end

function ChestController.open(newMode: ChestMode, callbacks: SellCallbacks?)
	mode = newMode
	sellCallbacks = callbacks
	gui.Enabled = true
	layoutGrid()
	render()
end

function ChestController.close()
	gui.Enabled = false
	sellCallbacks = nil
end

function ChestController.isOpen(): boolean
	return gui.Enabled
end

function ChestController.getMode(): ChestMode
	return mode
end

-- Dernier coffre reçu du serveur (lecture seule).
function ChestController.getInventory(): { Types.ItemInstance }
	return inventory
end

-- Appelé à chaque nouveau coffre reçu du serveur.
function ChestController.onChanged(callback: () -> ())
	table.insert(changedCallbacks, callback)
end

function ChestController.init()
	buildUi()
end

function ChestController.start()
	Remotes.get(Remotes.Names.InventoryUpdated).OnClientEvent:Connect(function(items: unknown)
		if typeof(items) ~= "table" then
			return
		end
		inventory = items :: { Types.ItemInstance }
		render()
		for _, callback in changedCallbacks do
			task.spawn(callback)
		end
	end)
end

return ChestController
