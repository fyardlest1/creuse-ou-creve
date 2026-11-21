--!strict
-- Rétention côté client : fenêtre "Aujourd'hui" (calendrier de 7 jours et 3 quêtes), Index de collection
-- (une page par couche, probabilités affichées), Réserve de bonus (potions et boucliers à activer).
-- Tout l'état vient du serveur (RetentionState, attributs du joueur) ; le client n'envoie que des intentions
-- (DailyClaim, UseBoost). Les annonces du serveur (quête réussie, palier d'Index) passent en bandeaux, l'une
-- après l'autre.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Strata = require(Shared.Config.Strata)
local RetentionConfig = require(Shared.Config.RetentionConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local UiConfig = require(Shared.Config.UiConfig)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local UiKit = require(script.Parent.Parent.UiKit)

type Payload = Types.RetentionStatePayload

-- Symboles, identiques dans toutes les langues (les textes passent par Locale).
local TEXT_UNKNOWN = "???"
local TEXT_REWARD_JOIN = " + "

local player = Players.LocalPlayer

local RetentionController = {}

local questsWindow: UiKit.Window
local indexWindow: UiKit.Window
local reserveWindow: UiKit.Window
local indexTabs: { [string]: TextButton } = {}
local currentLayer = 1
local state: Payload? = nil
local dailyClaim: RemoteEvent
local useBoost: RemoteEvent
local stateRequest: RemoteEvent
local notices: { Locale.LocText } = {}
local showingNotices = false
local autoOpened = false
local showBanner: ((text: string) -> ())? = nil

local function rewardText(reward: RetentionConfig.Reward, coinMultiplier: number?): string
	local parts = {}
	if reward.coins ~= nil and reward.coins > 0 then
		table.insert(parts, Locale.t("common.coins", UiKit.formatNumber(reward.coins * (coinMultiplier or 1))))
	end
	if reward.luckPotion ~= nil and reward.luckPotion > 0 then
		table.insert(parts, Locale.t("retention.rewardPotion"))
	end
	if reward.shield ~= nil and reward.shield > 0 then
		table.insert(parts, Locale.t("retention.rewardShield"))
	end
	return table.concat(parts, TEXT_REWARD_JOIN)
end

local function section(parent: Instance, name: string, text: string, order: number)
	local label = UiKit.label(name, text, parent)
	label.LayoutOrder = order
	label.Size = UDim2.new(1, -12, 0, UiConfig.RETENTION_SECTION_HEIGHT)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = UiKit.GOLD
end

local function card(parent: Instance, name: string, order: number, height: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -12, 0, height)
	frame.BackgroundColor3 = UiKit.CARD_BACKGROUND
	frame.Parent = parent
	UiKit.addCorner(frame, 0.1)
	UiKit.addPadding(frame, 6, 10)
	return frame
end

------------------------------------------------------------------------------------------------
-- Fenêtre "Aujourd'hui" : calendrier et quêtes
------------------------------------------------------------------------------------------------

local function renderDaily(current: Payload, list: ScrollingFrame)
	section(list, "DailySection", Locale.t("retention.dailySection"), 1)
	local daily = current.daily
	local calendar = card(list, "Calendar", 2, UiConfig.DAILY_CELL_HEIGHT)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = calendar
	local dayCount = #RetentionConfig.DAILY_REWARDS
	-- Après le jour 7 réclamé, un nouveau tour commence : aucune case cochée.
	local checkedUpTo = if daily.available and daily.lastDay == dayCount then 0 else daily.lastDay
	for day, reward in RetentionConfig.DAILY_REWARDS do
		local cell = Instance.new("Frame")
		cell.Name = "Day" .. day
		cell.LayoutOrder = day
		cell.Size = UDim2.new(1 / dayCount, -4, 1, 0)
		local isNext = daily.available and day == daily.nextDay
		cell.BackgroundColor3 = if isNext
			then UiKit.TAB_ON_COLOR
			elseif day <= checkedUpTo then UiKit.DONE_COLOR
			else UiKit.TAB_OFF_COLOR
		cell.Parent = calendar
		UiKit.addCorner(cell, 0.15)
		UiKit.addPadding(cell, 3, 3)
		local title = UiKit.label("Day", Locale.t("retention.day", day), cell)
		title.Size = UDim2.fromScale(1, 0.4)
		local text = UiKit.label("Reward", (if day <= checkedUpTo then "✓ " else "") .. rewardText(reward), cell)
		text.Position = UDim2.fromScale(0, 0.42)
		text.Size = UDim2.fromScale(1, 0.58)
		text.TextWrapped = true
		UiKit.limitText(text, UiConfig.RETENTION_SMALL_TEXT)
	end

	local claim = UiKit.button(
		"Claim",
		Locale.t(if daily.available then "retention.claim" else "retention.comeBack"),
		if daily.available then UiKit.ACTION_COLOR else UiKit.DISABLED_COLOR,
		list
	)
	claim.LayoutOrder = 3
	claim.Size = UDim2.new(1, -12, 0, UiConfig.TOUCH_TARGET_MIN)
	claim.AutoButtonColor = daily.available
	if daily.available then
		claim.Activated:Connect(function()
			dailyClaim:FireServer()
		end)
	end
end

local function renderQuests()
	if not questsWindow.gui.Enabled then
		return
	end
	local list = questsWindow.content
	UiKit.clear(list)
	local current = state
	if current == nil then
		return
	end
	renderDaily(current, list)
	section(list, "QuestsSection", Locale.t("retention.questsSection"), 4)
	for index, quest in current.quests do
		local row = card(list, "Quest" .. index, 4 + index, UiConfig.QUEST_ROW_HEIGHT)
		row.BackgroundColor3 = if quest.done then UiKit.DONE_COLOR else UiKit.CARD_BACKGROUND
		local text = UiKit.label("Text", Locale.t("quest." .. quest.kind, UiKit.formatNumber(quest.target)), row)
		text.Size = UDim2.new(0.68, 0, 0.5, 0)
		text.TextXAlignment = Enum.TextXAlignment.Left
		local reward = UiKit.label(
			"Reward",
			if quest.done
				then Locale.t("retention.questDone")
				else Locale.t("retention.questReward", UiKit.formatNumber(quest.reward)),
			row
		)
		reward.AnchorPoint = Vector2.new(1, 0)
		reward.Position = UDim2.fromScale(1, 0)
		reward.Size = UDim2.new(0.3, 0, 0.5, 0)
		reward.TextXAlignment = Enum.TextXAlignment.Right
		reward.TextColor3 = UiKit.GOLD

		-- Barre de progression
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.Position = UDim2.new(0, 0, 0.58, 0)
		bar.Size = UDim2.new(1, 0, 0.38, 0)
		bar.BackgroundColor3 = UiKit.PANEL_BACKGROUND
		bar.Parent = row
		UiKit.addCorner(bar, 0.5)
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(math.clamp(quest.progress / math.max(quest.target, 1), 0, 1), 1)
		fill.BackgroundColor3 = UiKit.GOLD
		fill.Parent = bar
		UiKit.addCorner(fill, 0.5)
		local count =
			UiKit.label("Count", UiKit.formatNumber(quest.progress) .. " / " .. UiKit.formatNumber(quest.target), bar)
		count.Size = UDim2.fromScale(1, 1)
		count.TextStrokeTransparency = 0.4
	end
	local bonus = UiKit.label(
		"Bonus",
		Locale.t(if current.questsBonusClaimed then "retention.bonusDone" else "retention.bonus"),
		list
	)
	bonus.LayoutOrder = 10
	bonus.Size = UDim2.new(1, -12, 0, UiConfig.RETENTION_SECTION_HEIGHT)
	bonus.TextColor3 = UiKit.MUTED_TEXT
end

------------------------------------------------------------------------------------------------
-- Index de collection
------------------------------------------------------------------------------------------------

local function renderIndex()
	if not indexWindow.gui.Enabled then
		return
	end
	UiKit.highlightTab(indexTabs, tostring(currentLayer))
	local list = indexWindow.content
	UiKit.clear(list)
	local current = state
	if current == nil then
		return
	end
	local stratum = Strata.byLayer[currentLayer]
	local items = {}
	for _, item in Items.list do
		if item.layer == currentLayer then
			table.insert(items, item)
		end
	end
	local found = 0
	for _, item in items do
		if current.index[item.id] ~= nil then
			found += 1
		end
	end
	local percent = if #items == 0 then 0 else math.floor(found / #items * 100)

	local progress = UiKit.label(
		"Progress",
		Locale.t("retention.indexProgress", Locale.stratum(stratum.id), found, #items, percent),
		list
	)
	progress.LayoutOrder = 1
	progress.Size = UDim2.new(1, -12, 0, UiConfig.RETENTION_SECTION_HEIGHT)
	progress.TextXAlignment = Enum.TextXAlignment.Left

	-- Paliers : ce qu'on gagne à 25, 50, 75 et 100 % (cochés une fois atteints).
	local tiers = card(list, "Tiers", 2, UiConfig.INDEX_TIERS_HEIGHT)
	local tierLayout = Instance.new("UIListLayout")
	tierLayout.FillDirection = Enum.FillDirection.Horizontal
	tierLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tierLayout.Padding = UDim.new(0, 4)
	tierLayout.Parent = tiers
	for index, tier in RetentionConfig.INDEX_TIERS do
		local reached = current.indexRewards[currentLayer .. ":" .. tier.percent] == true
		local rewardLabel = if tier.title
			then Locale.t("retention.rewardTitle")
			else rewardText(tier.reward or {}, RetentionConfig.INDEX_COIN_REWARD_MULTIPLIER_BY_LAYER[currentLayer])
		local cell = UiKit.label(
			"Tier" .. tier.percent,
			(if reached then "✓ " else "") .. Locale.t("retention.tier", tier.percent, rewardLabel),
			tiers
		)
		cell.LayoutOrder = index
		cell.Size = UDim2.new(1 / #RetentionConfig.INDEX_TIERS, -4, 1, 0)
		cell.BackgroundTransparency = 0
		cell.BackgroundColor3 = if reached then UiKit.DONE_COLOR else UiKit.TAB_OFF_COLOR
		cell.TextWrapped = true
		UiKit.addCorner(cell, 0.2)
		UiKit.limitText(cell, UiConfig.RETENTION_SMALL_TEXT)
	end

	-- Grille des objets : trouvés en couleur avec leurs mutations, les autres en silhouette.
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.LayoutOrder = 3
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, -12, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.Parent = list
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(UiConfig.INDEX_CELL_SIZE.X, UiConfig.INDEX_CELL_SIZE.Y)
	gridLayout.CellPadding = UDim2.fromOffset(6, 6)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	for order, item in items do
		local rarity = Rarities.byId[item.rarity]
		local mutationsFound = current.index[item.id]
		local cell = Instance.new("Frame")
		cell.Name = item.id
		cell.LayoutOrder = order
		cell.BackgroundColor3 = if mutationsFound ~= nil then UiKit.CARD_BACKGROUND else UiKit.PANEL_BACKGROUND
		cell.Parent = grid
		UiKit.addCorner(cell, 0.12)
		UiKit.addPadding(cell, 4, 5)
		local stroke = Instance.new("UIStroke")
		stroke.Color = rarity.color
		stroke.Thickness = 2
		stroke.Transparency = if mutationsFound ~= nil then 0 else 0.6
		stroke.Parent = cell

		local name = UiKit.label("ItemName", if mutationsFound ~= nil then Locale.item(item.id) else TEXT_UNKNOWN, cell)
		name.Size = UDim2.fromScale(1, 0.55)
		name.TextWrapped = true
		name.TextColor3 = if mutationsFound ~= nil then UiKit.WHITE else UiKit.MUTED_TEXT
		UiKit.limitText(name, UiConfig.RETENTION_SMALL_TEXT)
		local rarityLabel = UiKit.label("Rarity", Locale.rarity(rarity.id), cell)
		rarityLabel.Position = UDim2.fromScale(0, 0.55)
		rarityLabel.Size = UDim2.fromScale(1, 0.22)
		rarityLabel.TextColor3 = rarity.color

		-- Pastilles des mutations trouvées pour cet objet
		if mutationsFound ~= nil then
			local dots = Instance.new("Frame")
			dots.Name = "Mutations"
			dots.BackgroundTransparency = 1
			dots.Position = UDim2.fromScale(0, 0.8)
			dots.Size = UDim2.fromScale(1, 0.2)
			dots.Parent = cell
			local dotsLayout = Instance.new("UIListLayout")
			dotsLayout.FillDirection = Enum.FillDirection.Horizontal
			dotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			dotsLayout.Padding = UDim.new(0, 3)
			dotsLayout.Parent = dots
			for _, mutation in Mutations.list do
				if mutationsFound[mutation.id] then
					local dot = Instance.new("Frame")
					dot.Name = mutation.id
					dot.Size = UDim2.fromOffset(UiConfig.INDEX_MUTATION_DOT, UiConfig.INDEX_MUTATION_DOT)
					dot.BackgroundColor3 = mutation.color
					dot.Parent = dots
					UiKit.addCorner(dot, 0.5)
				end
			end
		end
	end

	UiKit.oddsBlock(list, 4)
end

------------------------------------------------------------------------------------------------
-- Réserve
------------------------------------------------------------------------------------------------

local function readNumber(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function reserveRow(list: Instance, order: number, kind: string, title: string, description: string)
	local count = readNumber(if kind == "luckPotion" then "ReserveLuckPotion" else "ReserveShield")
	local row = card(list, kind, order, UiConfig.RESERVE_ROW_HEIGHT)
	local name = UiKit.label("ItemName", title, row)
	name.Size = UDim2.new(0.62, 0, 0.45, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local text = UiKit.label("Description", description, row)
	text.Position = UDim2.fromScale(0, 0.48)
	text.Size = UDim2.new(0.62, 0, 0.52, 0)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextWrapped = true
	text.TextColor3 = UiKit.MUTED_TEXT
	UiKit.limitText(text, UiConfig.RETENTION_SMALL_TEXT)

	local planned = kind == "shield" and player:GetAttribute("ShieldPlanned") == true
	local enabled = count > 0 and not planned
	local label = Locale.t(
		if count <= 0 then "retention.empty" elseif planned then "retention.shieldPlanned" else "retention.activate"
	)
	local button = UiKit.button("Action", label, if enabled then UiKit.ACTION_COLOR else UiKit.DISABLED_COLOR, row)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.fromScale(1, 0.5)
	button.Size = UDim2.new(0.34, 0, 0, UiConfig.TOUCH_TARGET_MIN)
	button.AutoButtonColor = enabled
	if enabled then
		button.Activated:Connect(function()
			useBoost:FireServer(kind)
		end)
	end
end

local function renderReserve()
	if not reserveWindow.gui.Enabled then
		return
	end
	local list = reserveWindow.content
	UiKit.clear(list)
	local hint = UiKit.label("Hint", Locale.t("retention.reserveHint"), list)
	hint.Size = UDim2.new(1, -12, 0, UiConfig.RETENTION_SECTION_HEIGHT)
	hint.TextWrapped = true
	hint.TextColor3 = UiKit.MUTED_TEXT
	reserveRow(
		list,
		1,
		"luckPotion",
		Locale.t("retention.potionRow", readNumber("ReserveLuckPotion")),
		Locale.t(
			"retention.potionDescription",
			MonetizationConfig.POTION_MULTIPLIER,
			MonetizationConfig.POTION_DURATION // 60
		)
	)
	reserveRow(
		list,
		2,
		"shield",
		Locale.t("retention.shieldRow", readNumber("ReserveShield")),
		Locale.t("retention.shieldDescription")
	)
end

------------------------------------------------------------------------------------------------
-- Annonces du serveur, une après l'autre
------------------------------------------------------------------------------------------------

local function pumpNotices()
	if showingNotices then
		return
	end
	showingNotices = true
	task.spawn(function()
		while #notices > 0 do
			local text = table.remove(notices, 1) :: Locale.LocText
			if showBanner ~= nil then
				showBanner(Locale.render(text))
			end
			task.wait(UiConfig.BANNER_LONG_TIME + UiConfig.BANNER_FADE_TIME)
		end
		showingNotices = false
	end)
end

------------------------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------------------------

local function toggle(window: UiKit.Window, render: () -> ())
	window.gui.Enabled = not window.gui.Enabled
	if window.gui.Enabled then
		stateRequest:FireServer()
		render()
	end
end

function RetentionController.toggleQuests()
	toggle(questsWindow, renderQuests)
end

function RetentionController.toggleIndex()
	toggle(indexWindow, renderIndex)
end

function RetentionController.toggleReserve()
	toggle(reserveWindow, renderReserve)
end

-- Le HUD fournit l'affichage des bandeaux (évite une dépendance circulaire).
function RetentionController.setBannerHandler(handler: (text: string) -> ())
	showBanner = handler
end

function RetentionController.init()
	dailyClaim = Remotes.get(Remotes.Names.DailyClaim)
	useBoost = Remotes.get(Remotes.Names.UseBoost)
	stateRequest = Remotes.get(Remotes.Names.RetentionStateRequest)
	questsWindow = UiKit.window("QuestsGui", Locale.t("retention.todayTitle"), UiConfig.RETENTION_PANEL_MAX_SIZE)
	indexWindow = UiKit.window("IndexGui", Locale.t("retention.indexTitle"), UiConfig.RETENTION_PANEL_MAX_SIZE)
	reserveWindow = UiKit.window(
		"ReserveGui",
		Locale.t("retention.reserveTitle"),
		UiConfig.RESERVE_PANEL_MAX_SIZE,
		UiConfig.RESERVE_PANEL_SCALE
	)
	local entries = {}
	for _, stratum in Strata.list do
		table.insert(entries, { key = tostring(stratum.layer), text = Locale.stratum(stratum.id) })
	end
	indexTabs = UiKit.tabs(indexWindow.header, entries, function(key: string)
		currentLayer = tonumber(key) or 1
		renderIndex()
	end)
end

function RetentionController.start()
	Remotes.get(Remotes.Names.RetentionState).OnClientEvent:Connect(function(payload: unknown)
		if typeof(payload) ~= "table" then
			return
		end
		state = payload :: Payload
		renderQuests()
		renderIndex()
		-- Récompense du jour disponible : la fenêtre s'ouvre une fois par session, sauf pendant
		-- l'accueil d'un nouveau joueur (la main qui montre où creuser passe d'abord).
		local current = state :: Payload
		if current.daily.available and not autoOpened and player:GetAttribute("ShowDigHint") ~= true then
			autoOpened = true
			if not questsWindow.gui.Enabled then
				RetentionController.toggleQuests()
			end
		end
	end)
	Remotes.get(Remotes.Names.RetentionNotice).OnClientEvent:Connect(function(text: unknown)
		if Locale.isLocText(text) then
			table.insert(notices, text :: Locale.LocText)
			pumpNotices()
		end
	end)
	for _, name in { "ReserveLuckPotion", "ReserveShield", "ShieldPlanned" } do
		player:GetAttributeChangedSignal(name):Connect(renderReserve)
	end
	player:GetAttributeChangedSignal("LuckMultiplier"):Connect(renderIndex)
	stateRequest:FireServer()
end

return RetentionController
