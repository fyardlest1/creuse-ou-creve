--!strict
-- Étiquette VIP dans le chat : chaque client préfixe les messages des joueurs VIP par "[VIP]" en doré.
-- Le serveur pose l'attribut VIP sur le joueur quand il possède le pass (BoostService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Locale = require(Shared.Locale)

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

function VipController.start()
	TextChatService.OnIncomingMessage = onIncomingMessage
end

return VipController
