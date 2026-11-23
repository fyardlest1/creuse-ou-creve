--!strict
-- Case « Codes » de la fenêtre Réglages (plan semaine 5, section 10) : une zone de saisie, un bouton
-- Valider et une ligne de résultat. Le client n'envoie que le texte saisi ; le serveur décide
-- (PromoCodeService) et répond par CodeResult.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PromoCodes = require(Shared.Config.PromoCodes)
local UiConfig = require(Shared.Config.UiConfig)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local UiKit = require(script.Parent.Parent.UiKit)

local STATUS_KEYS: { [string]: string } = {
	invalid = "code.invalid",
	unknown = "code.unknown",
	used = "code.used",
	expired = "code.expired",
}

local PromoCodeController = {}

local redeemRemote: RemoteEvent
local resultLabel: TextLabel? = nil
local waiting = false

local function showResult(text: string, color: Color3)
	local label = resultLabel
	if label ~= nil then
		label.Text = text
		label.TextColor3 = color
	end
end

-- Récompense -> « 2 000 Pièces, 1 Potion de chance » dans la langue du joueur.
local function describeReward(reward: { [string]: any }): string
	local parts: { string } = {}
	if typeof(reward.coins) == "number" and reward.coins > 0 then
		table.insert(parts, Locale.t("common.coins", Locale.number(reward.coins)))
	end
	if typeof(reward.luckPotion) == "number" and reward.luckPotion > 0 then
		table.insert(parts, Locale.t("code.reward.luckPotion", reward.luckPotion))
	end
	if typeof(reward.shield) == "number" and reward.shield > 0 then
		table.insert(parts, Locale.t("code.reward.shield", reward.shield))
	end
	return table.concat(parts, ", ")
end

local function onResult(status: unknown, reward: unknown)
	if status == "ok" and typeof(reward) == "table" then
		showResult(Locale.t("code.ok", describeReward(reward :: any)), UiKit.DONE_COLOR)
	elseif typeof(status) == "string" and STATUS_KEYS[status] ~= nil then
		showResult(Locale.t(STATUS_KEYS[status]), UiKit.CLOSE_COLOR)
	end
end

-- Construit la case dans la liste de la fenêtre Réglages, à la position `order`.
function PromoCodeController.build(parent: Instance, order: number)
	local title = UiKit.label("CodesTitle", Locale.t("code.title"), parent)
	title.LayoutOrder = order
	title.Size = UDim2.new(1, -UiConfig.CHEST_CARD_PADDING, 0, UiConfig.CODE_TITLE_HEIGHT)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local row = Instance.new("Frame")
	row.Name = "CodeRow"
	row.LayoutOrder = order + 1
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -UiConfig.CHEST_CARD_PADDING, 0, UiConfig.SOUND_SETTINGS_ROW_HEIGHT)
	row.Parent = parent

	local box = Instance.new("TextBox")
	box.Name = "CodeBox"
	box.Size = UDim2.new(1 - UiConfig.CODE_BUTTON_WIDTH, -8, 1, 0)
	box.BackgroundColor3 = UiKit.CARD_BACKGROUND
	box.TextColor3 = UiKit.WHITE
	box.PlaceholderText = Locale.t("code.placeholder")
	box.PlaceholderColor3 = UiKit.MUTED_TEXT
	box.Font = Enum.Font.FredokaOne
	box.TextScaled = true
	box.ClearTextOnFocus = false
	box.Text = ""
	box.Parent = row
	UiKit.addCorner(box, 0.2)
	UiKit.addPadding(box, 8, 10)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > PromoCodes.MAX_LENGTH then
			box.Text = string.sub(box.Text, 1, PromoCodes.MAX_LENGTH)
		end
	end)

	local button = UiKit.button("Submit", Locale.t("code.submit"), UiKit.ACTION_COLOR, row)
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.fromScale(1, 0)
	button.Size = UDim2.fromScale(UiConfig.CODE_BUTTON_WIDTH, 1)

	local result = UiKit.label("CodeResult", "", parent)
	result.LayoutOrder = order + 2
	result.Size = UDim2.new(1, -UiConfig.CHEST_CARD_PADDING, 0, UiConfig.CODE_RESULT_HEIGHT)
	result.TextXAlignment = Enum.TextXAlignment.Left
	resultLabel = result

	local function submit()
		if waiting or #box.Text == 0 then
			return
		end
		-- Une demande à la fois : le serveur applique de toute façon sa propre cadence.
		waiting = true
		button.BackgroundColor3 = UiKit.DISABLED_COLOR
		showResult("", UiKit.MUTED_TEXT)
		redeemRemote:FireServer(box.Text)
		task.delay(PromoCodes.COOLDOWN, function()
			waiting = false
			button.BackgroundColor3 = UiKit.ACTION_COLOR
		end)
	end
	button.Activated:Connect(submit)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)
end

function PromoCodeController.init()
	redeemRemote = Remotes.get(Remotes.Names.RedeemCode)
end

function PromoCodeController.start()
	Remotes.get(Remotes.Names.CodeResult).OnClientEvent:Connect(onResult)
end

return PromoCodeController
