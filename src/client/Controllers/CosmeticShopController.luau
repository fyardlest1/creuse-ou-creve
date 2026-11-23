--!strict
-- Repaire des Voleurs (plan semaine 5, section 9) : boutique de cosmétiques en Points de Voleur.
-- Le prompt du stand ouvre la fenêtre : solde, puis une ligne par cosmétique (Acheter, Porter, Retirer).
-- Le client n'envoie que des intentions ; le serveur valide et met à jour les attributs du joueur
-- (ThiefPoints, OwnedCosmetics, EquippedMask, EquippedBag), que la fenêtre suit.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared.Config.Cosmetics)
local CosmeticShop = require(Shared.CosmeticShop)
local StealConfig = require(Shared.Config.StealConfig)
local UiConfig = require(Shared.Config.UiConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local UiKit = require(script.Parent.Parent.UiKit)

local ATTRIBUTES = { "ThiefPoints", "OwnedCosmetics", "EquippedMask", "EquippedBag" }

local player = Players.LocalPlayer

local CosmeticShopController = {}

local window: UiKit.Window? = nil
local shopPosition: Vector3? = nil
local buyRemote: RemoteEvent
local equipRemote: RemoteEvent

-- État lu dans les attributs publiés par le serveur.
local function readState(): (CosmeticShop.State, number)
	local owned: { string } = {}
	local ownedText = player:GetAttribute("OwnedCosmetics")
	if typeof(ownedText) == "string" and ownedText ~= "" then
		owned = ownedText:split(",")
	end
	local mask = player:GetAttribute("EquippedMask")
	local bag = player:GetAttribute("EquippedBag")
	local points = player:GetAttribute("ThiefPoints")
	return {
		owned = owned,
		mask = if typeof(mask) == "string" and mask ~= "" then mask else nil,
		bag = if typeof(bag) == "string" and bag ~= "" then bag else nil,
	},
		if typeof(points) == "number" then points else 0
end

local function infoLine(name: string, text: string, order: number, color: Color3, parent: Instance)
	local label = UiKit.label(name, text, parent)
	label.LayoutOrder = order
	label.Size = UDim2.new(1, -12, 0, UiConfig.COSMETIC_INFO_HEIGHT)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = color
end

local function createRow(def: Cosmetics.CosmeticDef, order: number, state: CosmeticShop.State, points: number)
	local current = window :: UiKit.Window
	local row = Instance.new("Frame")
	row.Name = def.id
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -12, 0, UiConfig.COSMETIC_ROW_HEIGHT)
	row.BackgroundColor3 = UiKit.CARD_BACKGROUND
	row.Parent = current.content
	UiKit.addCorner(row, 0.15)
	UiKit.addPadding(row, UiConfig.COSMETIC_ROW_PADDING, 10)

	-- Vignette à la couleur du cosmétique, avec l'initiale de son nom.
	local name = Locale.t("cosmetic." .. def.id)
	local swatch = UiKit.label("Swatch", utf8.char(utf8.codepoint(name, 1)), row)
	swatch.BackgroundTransparency = 0
	swatch.BackgroundColor3 = def.color
	swatch.Size = UDim2.fromScale(1, 1)
	swatch.SizeConstraint = Enum.SizeConstraint.RelativeYY
	UiKit.addCorner(swatch, 0.25)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Parent = swatch

	local text = Instance.new("Frame")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Position = UDim2.new(0, UiConfig.COSMETIC_ROW_HEIGHT, 0, 0)
	text.Size = UDim2.new(1 - UiConfig.COSMETIC_BUTTON_WIDTH, -(UiConfig.COSMETIC_ROW_HEIGHT + 8), 1, 0)
	text.Parent = row
	local nameLabel = UiKit.label("Name", name, text)
	nameLabel.Size = UDim2.fromScale(1, 0.55)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	local detail = UiKit.label(
		"Detail",
		Locale.t("cosmetic.slot." .. def.slot) .. "  ·  " .. Locale.t("cosmetic.price", def.price),
		text
	)
	detail.Position = UDim2.fromScale(0, 0.58)
	detail.Size = UDim2.fromScale(1, 0.42)
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextColor3 = UiKit.MUTED_TEXT

	-- Bouton selon l'état : Retirer (porté), Porter (possédé), Acheter, ou montant manquant (grisé).
	local worn = (if def.slot == "mask" then state.mask else state.bag) == def.id
	local owned = CosmeticShop.owns(state, def.id)
	local label, color, active
	if worn then
		label, color, active = Locale.t("cosmetic.remove"), UiConfig.COSMETIC_WORN_COLOR, true
	elseif owned then
		label, color, active = Locale.t("cosmetic.wear"), UiKit.ACTION_COLOR, true
	elseif points >= def.price then
		label, color, active = Locale.t("cosmetic.buy"), UiKit.TAB_ON_COLOR, true
	else
		label, color, active = Locale.t("cosmetic.missing", def.price - points), UiKit.DISABLED_COLOR, false
	end
	local button = UiKit.button("Action", label, color, row)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.fromScale(1, 0.5)
	button.Size = UDim2.new(UiConfig.COSMETIC_BUTTON_WIDTH, 0, 0, UiConfig.TOUCH_TARGET_MIN)
	button.AutoButtonColor = active
	button.Activated:Connect(function()
		if not active then
			return
		end
		if worn then
			equipRemote:FireServer(def.slot, "")
		elseif owned then
			equipRemote:FireServer(def.slot, def.id)
		else
			buyRemote:FireServer(def.id)
		end
	end)
end

local function refresh()
	local current = window
	if current == nil or not current.gui.Enabled then
		return
	end
	UiKit.clear(current.content)
	local state, points = readState()
	infoLine(
		"Points",
		Locale.t("cosmetic.points", Locale.number(points)),
		0,
		UiConfig.COSMETIC_POINTS_COLOR,
		current.content
	)
	infoLine(
		"Hint",
		Locale.t("cosmetic.hint", StealConfig.THIEF_POINTS_PER_STEAL),
		1,
		UiKit.MUTED_TEXT,
		current.content
	)
	for index, def in Cosmetics.list do
		createRow(def, index + 1, state, points)
	end
end

local function getCharacterPosition(): Vector3?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

-- Ferme la fenêtre quand le joueur s'éloigne du stand (le serveur refuserait l'achat de toute façon).
local function watchDistance()
	while window ~= nil and window.gui.Enabled and shopPosition ~= nil do
		local position = getCharacterPosition()
		if position == nil or (position - shopPosition).Magnitude > Cosmetics.SHOP_MAX_DISTANCE then
			window.gui.Enabled = false
			break
		end
		task.wait(UiConfig.COSMETIC_CLOSE_CHECK_INTERVAL)
	end
end

local function open(prompt: ProximityPrompt)
	if window == nil then
		window = UiKit.window(
			"CosmeticShopGui",
			Locale.t("cosmetic.title"),
			UiConfig.COSMETIC_PANEL_MAX_SIZE,
			UiConfig.PANEL_SIZE_SCALE
		)
	end
	local current = window :: UiKit.Window
	local anchor = prompt.Parent
	shopPosition = if anchor ~= nil and anchor:IsA("Attachment") then anchor.WorldPosition else nil
	current.gui.Enabled = true
	refresh()
	task.spawn(watchDistance)
end

function CosmeticShopController.isOpen(): boolean
	return window ~= nil and window.gui.Enabled
end

function CosmeticShopController.init()
	buyRemote = Remotes.get(Remotes.Names.BuyCosmetic)
	equipRemote = Remotes.get(Remotes.Names.EquipCosmetic)
end

function CosmeticShopController.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt:GetAttribute(WorldConfig.INTERACTION_ATTRIBUTE) == WorldConfig.INTERACTIONS.ThiefShop then
			open(prompt)
		end
	end)
	for _, name in ATTRIBUTES do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
end

return CosmeticShopController
