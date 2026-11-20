--!strict
-- Briques d'interface partagées par les contrôleurs : coins arrondis, marges, textes, boutons,
-- fenêtres centrées avec titre et bouton Fermer, bloc des probabilités de rareté.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local UiConfig = require(Shared.Config.UiConfig)
local LuckOdds = require(Shared.LuckOdds)

local UiKit = {}

UiKit.WHITE = Color3.new(1, 1, 1)
UiKit.PANEL_BACKGROUND = Color3.fromRGB(28, 26, 34)
UiKit.CARD_BACKGROUND = Color3.fromRGB(44, 41, 54)
UiKit.MUTED_TEXT = Color3.fromRGB(190, 190, 200)
UiKit.ACTION_COLOR = Color3.fromRGB(60, 170, 80)
UiKit.DISABLED_COLOR = Color3.fromRGB(80, 80, 90)
UiKit.TAB_ON_COLOR = Color3.fromRGB(230, 160, 40)
UiKit.TAB_OFF_COLOR = Color3.fromRGB(60, 58, 72)
UiKit.CLOSE_COLOR = Color3.fromRGB(200, 60, 60)
UiKit.GOLD = Color3.fromRGB(255, 205, 60)
UiKit.DONE_COLOR = Color3.fromRGB(70, 160, 90)

local TEXT_CLOSE = "X"
local TEXT_ODDS_TITLE = "Chances de trouver chaque rareté"
local TEXT_ODDS_HEADER = "Sans bonus  •  Avec tes bonus (x%s)"
local TEXT_ODDS_ROW = "%s : %s %%  •  %s %%"

function UiKit.addCorner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius, 0)
	corner.Parent = parent
end

function UiKit.addPadding(parent: GuiObject, vertical: number, horizontal: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, vertical)
	padding.PaddingBottom = UDim.new(0, vertical)
	padding.PaddingLeft = UDim.new(0, horizontal)
	padding.PaddingRight = UDim.new(0, horizontal)
	padding.Parent = parent
end

function UiKit.limitText(label: TextLabel | TextButton, maxSize: number)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize
	limit.Parent = label
end

function UiKit.label(name: string, text: string, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = UiKit.WHITE
	label.Text = text
	label.Parent = parent
	return label
end

function UiKit.button(name: string, text: string, color: Color3, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = color
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = UiKit.WHITE
	button.Text = text
	button.Parent = parent
	UiKit.addCorner(button, 0.25)
	UiKit.addPadding(button, 6, 8)
	return button
end

-- 12345 -> "12 345"
function UiKit.formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (formatted:gsub("^ ", ""))
end

-- 125 -> "2:05"
function UiKit.formatDuration(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", total // 60, total % 60)
end

export type Window = {
	gui: ScreenGui,
	panel: Frame,
	header: Frame, -- zone libre à droite du titre (onglets)
	content: ScrollingFrame,
	close: TextButton,
}

-- Fenêtre centrée : titre à gauche, bouton Fermer à droite, liste défilante dessous.
function UiKit.window(name: string, title: string, maxSize: Vector2, scale: Vector2?): Window
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Enabled = false

	local panelScale = scale or UiConfig.PANEL_SIZE_SCALE
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(panelScale.X, panelScale.Y)
	panel.BackgroundColor3 = UiKit.PANEL_BACKGROUND
	panel.BackgroundTransparency = 0.05
	panel.Parent = gui
	UiKit.addCorner(panel, 0.04)
	UiKit.addPadding(panel, 10, 12)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = maxSize
	sizeLimit.Parent = panel

	local headerHeight = UiConfig.TOUCH_TARGET_MIN
	local titleLabel = UiKit.label("Title", title, panel)
	titleLabel.Size = UDim2.new(0.28, 0, 0, headerHeight)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Position = UDim2.new(0.3, 0, 0, 0)
	header.Size = UDim2.new(0.7, -(headerHeight + 8), 0, headerHeight)
	header.Parent = panel

	local close = UiKit.button("Close", TEXT_CLOSE, UiKit.CLOSE_COLOR, panel)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(headerHeight, headerHeight)
	close.Activated:Connect(function()
		gui.Enabled = false
	end)

	local content = Instance.new("ScrollingFrame")
	content.Name = "List"
	content.Position = UDim2.fromOffset(0, headerHeight + 8)
	content.Size = UDim2.new(1, 0, 1, -(headerHeight + 8))
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 8
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new()
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = content

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return { gui = gui, panel = panel, header = header, content = content, close = close }
end

-- Onglets dans l'en-tête d'une fenêtre. onSelect reçoit la clé de l'onglet touché.
function UiKit.tabs(
	header: Frame,
	entries: { { key: string, text: string } },
	onSelect: (key: string) -> ()
): { [string]: TextButton }
	local buttons: { [string]: TextButton } = {}
	local width = 1 / math.max(#entries, 2)
	for index, entry in entries do
		local button = UiKit.button("Tab" .. entry.key, entry.text, UiKit.TAB_OFF_COLOR, header)
		button.Position = UDim2.fromScale((index - 1) * width, 0)
		button.Size = UDim2.new(width, -6, 1, 0)
		button.Activated:Connect(function()
			onSelect(entry.key)
		end)
		buttons[entry.key] = button
	end
	return buttons
end

function UiKit.highlightTab(buttons: { [string]: TextButton }, current: string)
	for key, button in buttons do
		button.BackgroundColor3 = if key == current then UiKit.TAB_ON_COLOR else UiKit.TAB_OFF_COLOR
	end
end

-- Supprime les cartes d'une liste (garde le UIListLayout).
function UiKit.clear(list: Instance)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Probabilités de rareté, sans bonus et avec le multiplicateur du joueur (attribut LuckMultiplier).
function UiKit.oddsBlock(parent: Instance, order: number): Frame
	local multiplier = Players.LocalPlayer:GetAttribute("LuckMultiplier")
	local luck = if typeof(multiplier) == "number" then multiplier else 1
	local base, boosted = LuckOdds.oddsFor(1), LuckOdds.oddsFor(luck)

	local block = Instance.new("Frame")
	block.Name = "Odds"
	block.LayoutOrder = order
	block.Size = UDim2.new(1, -12, 0, UiConfig.SHOP_ODDS_HEIGHT)
	block.BackgroundColor3 = UiKit.CARD_BACKGROUND
	block.Parent = parent
	UiKit.addCorner(block, 0.06)
	UiKit.addPadding(block, 8, 12)

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = block

	local lineHeight = UiConfig.SHOP_ODDS_LINE_HEIGHT
	local title = UiKit.label("Title", TEXT_ODDS_TITLE, block)
	title.Size = UDim2.new(1, 0, 0, lineHeight)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local header = UiKit.label("Header", string.format(TEXT_ODDS_HEADER, LuckOdds.formatMultiplier(luck)), block)
	header.LayoutOrder = 1
	header.Size = UDim2.new(1, 0, 0, lineHeight)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = UiKit.MUTED_TEXT
	for index, rarity in Rarities.list do
		local row = UiKit.label(
			rarity.id,
			string.format(
				TEXT_ODDS_ROW,
				rarity.displayName,
				LuckOdds.formatPercent(base[rarity.id]),
				LuckOdds.formatPercent(boosted[rarity.id])
			),
			block
		)
		row.LayoutOrder = index + 1
		row.Size = UDim2.new(1, 0, 0, lineHeight)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = rarity.color
	end
	return block
end

return UiKit
