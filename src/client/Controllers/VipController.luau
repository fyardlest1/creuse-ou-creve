--!strict
-- Étiquette VIP dans le chat : chaque client préfixe les messages des joueurs VIP par "[VIP]" en doré.
-- Le serveur pose l'attribut VIP sur le joueur quand il possède le pass (BoostService).
-- Salon VIP : les prompts réservés aux VIP (Marchand VIP) ne s'affichent que chez un VIP. Ce n'est que
-- de l'affichage : le serveur revalide la vente (EconomyService).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Locale = require(Shared.Locale)
local WorldConfig = require(Shared.Config.WorldConfig)

local VipController = {}

local function onIncomingMessage(message: TextChatMessage): TextChatMessageProperties?
	local source = message.TextSource
	local sender = if source ~= nil then Players:GetPlayerByUserId(source.UserId) else nil
	if sender == nil or sender:GetAttribute("VIP") ~= true then
		return nil
	end
	local properties = Instance.new("TextChatMessageProperties")
	properties.PrefixText = string.format(
		'<font color="%s">[%s]</font> %s',
		MonetizationConfig.VIP_TAG_COLOR_HEX,
		Locale.t("vip.tag"),
		message.PrefixText
	)
	return properties
end

function VipController.init() end

local function isVip(): boolean
	return Players.LocalPlayer:GetAttribute("VIP") == true
end

local function applyVipOnly(prompt: Instance)
	if prompt:IsA("ProximityPrompt") then
		prompt.Enabled = isVip()
	end
end

function VipController.start()
	TextChatService.OnIncomingMessage = onIncomingMessage
	for _, prompt in CollectionService:GetTagged(WorldConfig.VIP_ONLY_TAG) do
		applyVipOnly(prompt)
	end
	CollectionService:GetInstanceAddedSignal(WorldConfig.VIP_ONLY_TAG):Connect(applyVipOnly)
	Players.LocalPlayer:GetAttributeChangedSignal("VIP"):Connect(function()
		for _, prompt in CollectionService:GetTagged(WorldConfig.VIP_ONLY_TAG) do
			applyVipOnly(prompt)
		end
	end)
end

return VipController
