--!strict
-- Interface du coffre : grille de cartes triée par valeur décroissante, compteur "18/30", étoile de favori.
-- Mode "view" pour consulter (prompt du coffre, bouton du HUD), mode "sell" (ouvert par le Marchand)
-- avec "Tout vendre" et "Vendre" par carte.
-- Le coffre affiché est toujours celui envoyé par le serveur (InventoryUpdated).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Items = require(Shared.Config.Items)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local UiConfig = require(Shared.Config.UiConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local ItemIcon = require(script.Parent.Parent.ItemIcon)

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
local STAR_ON_COLOR = Color3.fromRGB(255, 200, 40)
local STAR_OFF_COLOR = Color3.fromRGB(120, 120, 135)

-- Symboles, identiques dans toutes les langues (les textes passent par Locale).
local TEXT_COUNTER = "%d/%d"
local TEXT_CLOSE = "X"
local TEXT_STAR_ON = "★"
local TEXT_STAR_OFF = "☆"
local STOLEN_COLOR = Color3.fromRGB(255, 110, 110)

local player = Players.LocalPlayer

-- Places du coffre (30, ou 60 avec Coffre agrandi), publiées par le serveur.
local function getInventoryLimit(): number
	local limit = player:GetAttribute("InventoryLimit")
	return if typeof(limit) == "number" then limit else PlayerConfig.INVENTORY_LIMIT
end

local ChestController = {}

local inventory: { Types.ItemInstance } = {}
local mode: ChestMode = "view"
local sellCallbacks: SellCallbacks? = nil
local changedCallbacks: { () -> () } = {}
local toggleFavoriteRemote: RemoteEvent

local gui: ScreenGui
local titleLabel: TextLabel
local counterLabel: TextLabel
local sellAllButton: TextButton
local grid: ScrollingFrame
local emptyLabel: TextLabel
local gridLayout: UIGridLayout

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

	-- Mise en page en pixels, de haut en bas : rareté (+ étoile à droite), mutation, nom, valeur,
	-- bouton "Vendre". Les zones tactiles font au moins TOUCH_TARGET_MIN pixels.
	local touch = UiConfig.TOUCH_TARGET_MIN
	local line = UiConfig.CHEST_CARD_LINE_HEIGHT
	local hasSellButton = mode == "sell" and not item.favorite
	local bottomReserved = if hasSellButton then touch + UiConfig.CHEST_CARD_GAP else 0

	local rarityLabel = createLabel("Rarity", Locale.rarity(item.rarity), card)
	rarityLabel.Size = UDim2.new(1, -touch, 0, line)
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
	rarityLabel.TextColor3 = rarityColor

	-- Étoile de favori : un favori ne peut pas être vendu. Zone tactile carrée dans le coin.
	local star = Instance.new("TextButton")
	star.Name = "Favorite"
	star.AnchorPoint = Vector2.new(1, 0)
	star.Position = UDim2.new(1, UiConfig.CHEST_CARD_STAR_INSET, 0, -UiConfig.CHEST_CARD_STAR_INSET)
	star.Size = UDim2.fromOffset(touch, touch)
	star.BackgroundTransparency = 1
	star.Font = Enum.Font.GothamBold
	star.TextScaled = true
	star.Text = if item.favorite then TEXT_STAR_ON else TEXT_STAR_OFF
	star.TextColor3 = if item.favorite then STAR_ON_COLOR else STAR_OFF_COLOR
	star.Parent = card
	local starPadding = Instance.new("UIPadding")
	local inner = UDim.new(0, UiConfig.CHEST_CARD_STAR_PADDING)
	starPadding.PaddingTop, starPadding.PaddingBottom, starPadding.PaddingLeft, starPadding.PaddingRight =
		inner, inner, inner, inner
	starPadding.Parent = star
	star.Activated:Connect(function()
		toggleFavoriteRemote:FireServer(item.uid)
	end)

	local mutation = if item.mutation ~= nil then Mutations.byId[item.mutation] else nil
	if mutation ~= nil then
		local badge = createLabel("Mutation", Locale.mutation(mutation.id), card)
		badge.Position = UDim2.fromOffset(0, line + 2)
		badge.Size = UDim2.new(1, -touch, 0, UiConfig.CHEST_CARD_BADGE_HEIGHT)
		badge.BackgroundTransparency = 0
		badge.BackgroundColor3 = mutation.color
		-- Texte sombre sur couleur claire, blanc sur couleur sombre (Maudit).
		local _, _, brightness = mutation.color:ToHSV()
		badge.TextColor3 = if brightness > 0.7 then PANEL_BACKGROUND else WHITE
		addCorner(badge, 0.5)
	end

	-- Le nom commence sous l'étoile, pour ne jamais la chevaucher ; l'icône est à sa gauche, centrée
	-- dans la même zone.
	local nameTop = touch - UiConfig.CHEST_CARD_STAR_INSET
	local stolenReserved = if item.stolenFrom ~= nil then line else 0
	local belowName = line + stolenReserved + bottomReserved + 2
	local iconSize = UiConfig.CHEST_CARD_ICON_SIZE
	local icon = ItemIcon.create(item.itemId, rarityColor, card)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 0, 0.5, (nameTop - belowName) / 2)
	icon.Size = UDim2.new(0, iconSize, 1, -(nameTop + belowName))
	local iconLimit = Instance.new("UISizeConstraint")
	iconLimit.MaxSize = Vector2.new(iconSize, iconSize)
	iconLimit.Parent = icon

	local nameLeft = iconSize + UiConfig.CHEST_CARD_ICON_GAP
	local nameLabel = createLabel("ItemName", if itemDef ~= nil then Locale.item(item.itemId) else item.itemId, card)
	nameLabel.Position = UDim2.fromOffset(nameLeft, nameTop)
	nameLabel.Size = UDim2.new(1, -nameLeft, 1, -(nameTop + belowName))
	nameLabel.TextWrapped = true
	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MaxTextSize = UiConfig.CHEST_CARD_NAME_MAX_TEXT
	nameLimit.Parent = nameLabel

	-- Trophée : un objet volé affiche sa provenance.
	if item.stolenFrom ~= nil then
		local stolen = createLabel("StolenFrom", Locale.t("chest.stolenFrom", item.stolenFrom), card)
		stolen.AnchorPoint = Vector2.new(0, 1)
		stolen.Position = UDim2.new(0, 0, 1, -(bottomReserved + line))
		stolen.Size = UDim2.new(1, 0, 0, line)
		stolen.TextColor3 = STOLEN_COLOR
	end

	local valueLabel = createLabel("Value", Locale.t("common.coins", Locale.number(item.value)), card)
	valueLabel.AnchorPoint = Vector2.new(0, 1)
	valueLabel.Position = UDim2.new(0, 0, 1, -bottomReserved)
	valueLabel.Size = UDim2.new(1, 0, 0, line)
	valueLabel.TextColor3 = MUTED_TEXT

	if hasSellButton then
		local sellButton = createButton("Sell", Locale.t("chest.sellOne"), SELL_ONE_COLOR, card)
		sellButton.AnchorPoint = Vector2.new(0.5, 1)
		sellButton.Position = UDim2.fromScale(0.5, 1)
		sellButton.Size = UDim2.new(1, 0, 0, touch)
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

	titleLabel.Text = Locale.t(if mode == "sell" then "chest.titleSell" else "chest.title")
	counterLabel.Text = string.format(TEXT_COUNTER, #inventory, getInventoryLimit())

	local sellable = getSellableTotal()
	sellAllButton.Visible = mode == "sell"
	sellAllButton.Text = Locale.t("chest.sellAll", Locale.number(sellable))
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
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(UiConfig.PANEL_SIZE_SCALE.X, UiConfig.PANEL_SIZE_SCALE.Y)
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
	titleLabel = createLabel("Title", Locale.t("chest.title"), panel)
	titleLabel.Size = UDim2.new(0.22, 0, 0, headerHeight)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left

	counterLabel = createLabel("Counter", "", panel)
	counterLabel.AnchorPoint = Vector2.new(1, 0)
	counterLabel.Position = UDim2.new(1, -(headerHeight + 10), 0, 0)
	counterLabel.Size = UDim2.new(0.14, 0, 0, headerHeight)
	counterLabel.TextXAlignment = Enum.TextXAlignment.Right

	local closeButton = createButton("Close", TEXT_CLOSE, CLOSE_COLOR, panel)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.fromScale(1, 0)
	closeButton.Size = UDim2.fromOffset(headerHeight, headerHeight)
	closeButton.Activated:Connect(function()
		ChestController.close()
	end)

	-- Bouton "Tout vendre" dans la ligne d'en-tête (mode vente seulement) : sur un téléphone bas,
	-- une ligne de plus empêcherait de voir une rangée de cartes en entier.
	sellAllButton = createButton("SellAll", "", SELL_ALL_COLOR, panel)
	sellAllButton.Position = UDim2.new(0.24, 0, 0, 0)
	sellAllButton.Size = UDim2.new(0.62, -(headerHeight + 16), 0, headerHeight)
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
	gridLayout = layout
	layout.CellPadding = UDim2.fromOffset(UiConfig.CHEST_CARD_PADDING, UiConfig.CHEST_CARD_PADDING)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 4)
	gridPadding.PaddingBottom = UDim.new(0, 4)
	gridPadding.Parent = grid

	emptyLabel = createLabel("Empty", Locale.t("chest.empty"), panel)
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
	local top = headerHeight + 8
	grid.Position = UDim2.new(0, 0, 0, top)
	grid.Size = UDim2.new(1, 0, 1, -top)
end

-- Cartes plus petites sur les écrans bas, pour voir deux rangées sur un téléphone en paysage.
local function updateCardSize()
	local camera = workspace.CurrentCamera
	local compact = camera ~= nil and camera.ViewportSize.Y < UiConfig.COMPACT_SCREEN_HEIGHT
	local size = if compact then UiConfig.CHEST_CARD_SIZE_COMPACT else UiConfig.CHEST_CARD_SIZE
	gridLayout.CellSize = UDim2.fromOffset(size.X, size.Y)
end

function ChestController.open(newMode: ChestMode, callbacks: SellCallbacks?)
	updateCardSize()
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

-- Prompt "Ouvrir le coffre" : seulement le coffre de sa propre parcelle (le vol viendra en semaine 3).
local function onPromptTriggered(prompt: ProximityPrompt)
	if prompt:GetAttribute(WorldConfig.INTERACTION_ATTRIBUTE) ~= WorldConfig.INTERACTIONS.Chest then
		return
	end
	local chest = prompt:FindFirstAncestorWhichIsA("Model")
	local plot = if chest ~= nil then chest.Parent else nil
	if plot == nil or plot:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	ChestController.open("view")
end

-- Bouton du HUD : ouvre le coffre en consultation, ou le ferme s'il est déjà ouvert.
function ChestController.toggle()
	if ChestController.isOpen() then
		ChestController.close()
	else
		ChestController.open("view")
	end
end

function ChestController.init()
	buildUi()
	toggleFavoriteRemote = Remotes.get(Remotes.Names.ToggleFavorite)
end

function ChestController.start()
	ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
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
