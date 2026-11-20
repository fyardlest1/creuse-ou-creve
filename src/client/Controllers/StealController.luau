--!strict
-- Vol, côté client : affichage des prompts (confort seulement, le serveur revalide tout), alerte de la
-- victime (son, bandeau, flèche vers son coffre), clignotement rouge des coffres crochetés, messages
-- d'annulation et carte de résultat ("Tu as volé : ..." / "On t'a volé : ...").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DayNightConfig = require(Shared.Config.DayNightConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local StealConfig = require(Shared.Config.StealConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local Rarities = require(Shared.Config.Rarities)
local UiConfig = require(Shared.Config.UiConfig)
local Remotes = require(Shared.Remotes)
local HudController = require(script.Parent.HudController)

local TEXT_ALERT = "Un voleur ouvre ton coffre !"
local TEXT_ARROW_CHEST = "Ton coffre"
local TEXT_VICTIM_SAFE = "Le voleur est reparti les mains vides"
local TEXT_THIEF_EJECTED = "Voleur éjecté !"
local TEXT_EJECT_ACTION = "Éjecter"
local TEXT_EJECTED = "Éjecté par %s ! Étourdi %d s"
local TEXT_THIEF_CANCELLED = "Crochetage annulé : %s"
local TEXT_STOLEN_BY_ME = "Tu as volé :"
local TEXT_STOLEN_FROM_ME = "On t'a volé :"
local TEXT_STOLEN_FROM_ME_BY = "par %s"
local TEXT_STOLEN_BY_ME_FROM = "à %s"
local CANCEL_REASONS: { [string]: string } = {
	["relâché"] = "tu as relâché",
	["éjecté"] = "tu as été éjecté",
	["trop loin"] = "tu t'es trop éloigné",
	["jour"] = "le jour se lève",
	["départ"] = "le joueur est parti",
}
-- Raisons affichées au-dessus du coffre d'un autre joueur, la nuit, quand le vol est impossible.
local TEXT_SELF_PROTECTED = "Tu es protégé (%d min)"
local TEXT_VICTIM_PROTECTED = "Protégé (%d min)"
local TEXT_ROBBED = "Déjà pillé cette nuit"
local TEXT_THIEF_LIMIT = "Tu as déjà volé %d fois cette nuit"
local TEXT_CHEST_FULL = "Ton coffre est plein"
local TEXT_BANNED = "Tu as été éjecté de ce coffre"

local WHITE = Color3.new(1, 1, 1)
local CARD_BACKGROUND = Color3.fromRGB(28, 26, 34)
local BLINK_COLOR = Color3.fromRGB(255, 40, 40)
local LABEL_BACKGROUND = Color3.fromRGB(28, 26, 34)

local player = Players.LocalPlayer

local StealController = {}

type ChestView = {
	plot: Model,
	body: BasePart,
	open: ProximityPrompt?,
	pick: ProximityPrompt?,
	label: TextLabel,
	labelGui: BillboardGui,
	highlight: Highlight,
}

local chests: { ChestView } = {}
local bannedOwners: { [number]: boolean } = {} -- coffres dont j'ai été éjecté cette nuit
local alarm: Sound
local alertThiefId: number? = nil
local ejectPrompt: ProximityPrompt? = nil
local ejectRequest: RemoteEvent
local stunGui: ScreenGui
local card: Frame
local cardTitle: TextLabel
local cardItem: TextLabel
local cardSubtitle: TextLabel
local cardStroke: UIStroke
local cardGeneration = 0

local function isNight(): boolean
	return ReplicatedStorage:GetAttribute(DayNightConfig.ATTRIBUTE_PHASE) == "Night"
end

local function remainingProtection(target: Player): number
	local protectedUntil = target:GetAttribute("ProtectedUntil")
	return if typeof(protectedUntil) == "number" then protectedUntil - Workspace:GetServerTimeNow() else 0
end

local function getOwner(plot: Model): Player?
	local ownerId = plot:GetAttribute("OwnerUserId")
	if typeof(ownerId) ~= "number" or ownerId == 0 then
		return nil
	end
	return Players:GetPlayerByUserId(ownerId)
end

-- Reflet local des règles du serveur, pour expliquer au joueur pourquoi il ne peut pas crocheter.
local function getBlockText(victim: Player): string?
	local selfRemaining = remainingProtection(player)
	if selfRemaining > 0 then
		return string.format(TEXT_SELF_PROTECTED, math.ceil(selfRemaining / 60))
	end
	local victimRemaining = remainingProtection(victim)
	if victimRemaining > 0 then
		return string.format(TEXT_VICTIM_PROTECTED, math.ceil(victimRemaining / 60))
	end
	if victim:GetAttribute("RobbedTonight") == true then
		return TEXT_ROBBED
	end
	if bannedOwners[victim.UserId] then
		return TEXT_BANNED
	end
	local steals = player:GetAttribute("StealsTonight")
	if typeof(steals) == "number" and steals >= StealConfig.MAX_STEALS_PER_NIGHT then
		return string.format(TEXT_THIEF_LIMIT, steals)
	end
	local count = player:GetAttribute("InventoryCount")
	if typeof(count) == "number" and count >= PlayerConfig.INVENTORY_LIMIT then
		return TEXT_CHEST_FULL
	end
	return nil
end

local function trackChest(plot: Model)
	local chest = plot:WaitForChild("Chest", 10)
	local body = if chest ~= nil then chest:FindFirstChild("Body") else nil
	if chest == nil or body == nil or not body:IsA("BasePart") then
		return
	end
	local view: ChestView = {
		plot = plot,
		body = body,
		open = nil,
		pick = nil,
		label = nil :: any,
		labelGui = nil :: any,
		highlight = nil :: any,
	}
	for _, prompt in body:GetChildren() do
		if prompt:IsA("ProximityPrompt") then
			local interaction = prompt:GetAttribute(WorldConfig.INTERACTION_ATTRIBUTE)
			if interaction == WorldConfig.INTERACTIONS.Chest then
				view.open = prompt
			elseif interaction == WorldConfig.INTERACTIONS.Pick then
				view.pick = prompt
			end
		end
	end

	-- Étiquette locale au-dessus du coffre (raison d'un vol impossible).
	local anchor = Instance.new("Attachment")
	anchor.Name = "StealLabelAnchor"
	anchor.Position = Vector3.new(0, UiConfig.STEAL_LABEL_HEIGHT, 0)
	anchor.Parent = body
	local labelGui = Instance.new("BillboardGui")
	labelGui.Name = "StealLabel"
	labelGui.Size = UDim2.fromOffset(UiConfig.STEAL_LABEL_SIZE.X, UiConfig.STEAL_LABEL_SIZE.Y)
	labelGui.MaxDistance = UiConfig.STEAL_LABEL_MAX_DISTANCE
	labelGui.Adornee = anchor
	labelGui.Enabled = false
	labelGui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = LABEL_BACKGROUND
	label.BackgroundTransparency = 0.2
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.Parent = labelGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label
	view.label = label
	view.labelGui = labelGui

	-- Clignotement rouge local pendant un crochetage (attribut BeingPicked, posé par le serveur).
	local highlight = Instance.new("Highlight")
	highlight.Name = "PickBlink"
	highlight.FillColor = BLINK_COLOR
	highlight.OutlineColor = BLINK_COLOR
	highlight.Enabled = false
	highlight.Adornee = chest
	highlight.Parent = chest
	view.highlight = highlight

	table.insert(chests, view)
end

-- Prompts et étiquettes de chaque coffre, selon la phase, le propriétaire et les règles.
local function refreshChests()
	local night = isNight()
	for _, view in chests do
		local owner = getOwner(view.plot)
		local own = owner == player
		if view.open ~= nil then
			view.open.Enabled = own
		end
		local blockText = if night and owner ~= nil and not own then getBlockText(owner) else nil
		if view.pick ~= nil then
			view.pick.Enabled = night and owner ~= nil and not own and blockText == nil
		end
		view.labelGui.Enabled = blockText ~= nil
		if blockText ~= nil then
			view.label.Text = blockText
		end
	end
end

local function updateBlink()
	local on = math.sin(os.clock() * math.pi * 2 * UiConfig.STEAL_BLINK_FREQUENCY) > 0
	for _, view in chests do
		local picked = view.body.Parent ~= nil
			and (view.body.Parent :: Instance):GetAttribute(WorldConfig.ATTRIBUTE_BEING_PICKED) == true
		view.highlight.Enabled = picked
		if picked then
			view.highlight.FillTransparency = if on then 0.3 else 0.85
		end
	end
end

local function findMyChestPosition(): Vector3?
	for _, view in chests do
		if getOwner(view.plot) == player then
			return view.body.Position
		end
	end
	return nil
end

local function removeEjectPrompt()
	local prompt = ejectPrompt
	ejectPrompt = nil
	if prompt ~= nil then
		prompt:Destroy()
	end
end

local function stopAlert()
	alertThiefId = nil
	alarm:Stop()
	HudController.setArrowTarget(nil)
	removeEjectPrompt()
end

-- Prompt "Éjecter" au-dessus du voleur, créé par ce client : la victime est seule à le voir.
local function showEjectPrompt(thief: Player)
	removeEjectPrompt()
	local character = thief.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EjectPrompt"
	prompt.ActionText = TEXT_EJECT_ACTION
	prompt.ObjectText = thief.DisplayName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = StealConfig.EJECT_MAX_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = WorldConfig.PROMPT_KEY
	prompt.Triggered:Connect(function()
		ejectRequest:FireServer(thief.UserId)
	end)
	prompt.Parent = root
	ejectPrompt = prompt
end

local function buildCard()
	local gui = Instance.new("ScreenGui")
	gui.Name = "StealCardGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15

	card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.42)
	card.Size = UDim2.fromScale(0.45, 0.3)
	card.BackgroundColor3 = CARD_BACKGROUND
	card.Visible = false
	card.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(260, 120)
	limit.MaxSize = Vector2.new(460, 200)
	limit.Parent = card
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.08, 0)
	corner.Parent = card
	cardStroke = Instance.new("UIStroke")
	cardStroke.Thickness = 4
	cardStroke.Parent = card

	local function label(name: string, y: number, height: number): TextLabel
		local text = Instance.new("TextLabel")
		text.Name = name
		text.BackgroundTransparency = 1
		text.Position = UDim2.fromScale(0.05, y)
		text.Size = UDim2.fromScale(0.9, height)
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = WHITE
		text.Parent = card
		return text
	end
	cardTitle = label("Title", 0.08, 0.22)
	cardItem = label("Item", 0.34, 0.34)
	cardSubtitle = label("Subtitle", 0.72, 0.2)

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function showCard(title: string, itemName: string, rarity: string, subtitle: string)
	cardGeneration += 1
	local generation = cardGeneration
	local rarityDef = Rarities.byId[rarity :: any]
	local color = if rarityDef ~= nil then rarityDef.color else WHITE
	cardTitle.Text = title
	cardItem.Text = itemName
	cardItem.TextColor3 = color
	cardStroke.Color = color
	cardSubtitle.Text = subtitle
	card.Visible = true
	card.Size = UDim2.fromScale(0.36, 0.24)
	TweenService:Create(card, TweenInfo.new(UiConfig.REVEAL_APPEAR_TIME, Enum.EasingStyle.Back), {
		Size = UDim2.fromScale(0.45, 0.3),
	}):Play()
	task.delay(UiConfig.STEAL_CARD_TIME, function()
		if cardGeneration == generation then
			card.Visible = false
		end
	end)
end

local function onStealStarted(thiefName: unknown, thiefUserId: unknown)
	if typeof(thiefName) ~= "string" then
		return
	end
	alertThiefId = if typeof(thiefUserId) == "number" then thiefUserId else nil
	local thief = if alertThiefId ~= nil then Players:GetPlayerByUserId(alertThiefId) else nil
	if thief ~= nil then
		showEjectPrompt(thief)
	end
	HudController.showBanner(TEXT_ALERT, "alert", true)
	alarm:Play()
	local chestPosition = findMyChestPosition()
	if chestPosition ~= nil then
		HudController.setArrowTarget(chestPosition, TEXT_ARROW_CHEST, UiConfig.STEAL_ARROW_REACH)
	end
end

local function onStealCancelled(reason: unknown, otherName: unknown)
	local reasonText = if typeof(reason) == "string" then reason else ""
	if alertThiefId ~= nil and typeof(otherName) == "string" then
		local thief = Players:GetPlayerByUserId(alertThiefId)
		if thief ~= nil and thief.Name == otherName then
			-- Je suis la victime : mon coffre est sauf.
			stopAlert()
			HudController.showBanner(
				if reasonText == "éjecté" then TEXT_THIEF_EJECTED else TEXT_VICTIM_SAFE,
				"success"
			)
			return
		end
	end
	-- Je suis le voleur.
	HudController.showBanner(string.format(TEXT_THIEF_CANCELLED, CANCEL_REASONS[reasonText] or reasonText), "info")
end

local function onStealSucceeded(itemName: unknown, rarity: unknown, thiefName: unknown, victimName: unknown)
	if typeof(itemName) ~= "string" or typeof(rarity) ~= "string" then
		return
	end
	if thiefName == player.Name then
		showCard(TEXT_STOLEN_BY_ME, itemName, rarity, string.format(TEXT_STOLEN_BY_ME_FROM, tostring(victimName)))
	else
		stopAlert()
		showCard(TEXT_STOLEN_FROM_ME, itemName, rarity, string.format(TEXT_STOLEN_FROM_ME_BY, tostring(thiefName)))
	end
end

-- Éjecté : bannissement local de ce coffre (affichage), voile et message d'étourdissement.
local function onEjected(ownerName: unknown, stunSeconds: unknown)
	if typeof(ownerName) ~= "string" or typeof(stunSeconds) ~= "number" then
		return
	end
	local owner = Players:FindFirstChild(ownerName)
	if owner ~= nil and owner:IsA("Player") then
		bannedOwners[owner.UserId] = true
	end
	HudController.showBanner(string.format(TEXT_EJECTED, ownerName, stunSeconds), "alert", true)
	stunGui.Enabled = true
	task.delay(stunSeconds, function()
		stunGui.Enabled = false
	end)
end

local function buildStunOverlay()
	stunGui = Instance.new("ScreenGui")
	stunGui.Name = "StunGui"
	stunGui.ResetOnSpawn = false
	stunGui.IgnoreGuiInset = true
	stunGui.DisplayOrder = 3
	stunGui.Enabled = false
	local veil = Instance.new("Frame")
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = UiConfig.STUN_VEIL_COLOR
	veil.BackgroundTransparency = UiConfig.STUN_VEIL_TRANSPARENCY
	veil.BorderSizePixel = 0
	veil.Parent = stunGui
	stunGui.Parent = player:WaitForChild("PlayerGui")
end

-- Coffres dont j'ai été éjecté cette nuit (les bannissements sont levés au lever du jour).
function StealController.markBanned(ownerUserId: number)
	bannedOwners[ownerUserId] = true
end

-- Voleur en train de crocheter mon coffre (pour le prompt "Éjecter"), ou nil.
function StealController.getAlertThiefId(): number?
	return alertThiefId
end

function StealController.init()
	buildCard()
	buildStunOverlay()
	ejectRequest = Remotes.get(Remotes.Names.EjectRequest)
	alarm = Instance.new("Sound")
	alarm.Name = "StealAlarm"
	alarm.SoundId = UiConfig.SOUND_STEAL_ALARM
	alarm.Volume = UiConfig.VOLUME_STEAL_ALARM
	alarm.PlaybackSpeed = UiConfig.PITCH_STEAL_ALARM
	alarm.Looped = true
	alarm.Parent = SoundService
end

function StealController.start()
	local plots = Workspace:WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		if plot:IsA("Model") then
			task.spawn(trackChest, plot)
		end
	end

	Remotes.get(Remotes.Names.StealStarted).OnClientEvent:Connect(onStealStarted)
	Remotes.get(Remotes.Names.StealCancelled).OnClientEvent:Connect(onStealCancelled)
	Remotes.get(Remotes.Names.StealSucceeded).OnClientEvent:Connect(onStealSucceeded)
	Remotes.get(Remotes.Names.Ejected).OnClientEvent:Connect(onEjected)
	Remotes.get(Remotes.Names.PhaseChanged).OnClientEvent:Connect(function(phase: unknown)
		if phase == "Day" then
			bannedOwners = {}
			stopAlert()
		end
	end)

	task.spawn(function()
		while true do
			refreshChests()
			task.wait(UiConfig.STEAL_REFRESH_INTERVAL)
		end
	end)
	RunService.RenderStepped:Connect(updateBlink)
end

return StealController
