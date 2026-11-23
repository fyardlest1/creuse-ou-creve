--!strict
-- Codes promo (plan semaine 5, section 10). Le client envoie le texte saisi ; le serveur vérifie
-- (texte, code connu, pas expiré, pas déjà utilisé par ce joueur), enregistre le code dans le profil,
-- puis accorde la récompense, sans yield entre les deux : un code ne peut jamais servir deux fois.
-- Réponse au client : CodeResult (statut, et récompense si accepté).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PromoCodes = require(Shared.Config.PromoCodes)
local Remotes = require(Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local BoostService = require(script.Parent.BoostService)

export type Status = "ok" | "invalid" | "unknown" | "used" | "expired"

local PromoCodeService = {}

local lastTry: { [Player]: number } = {}
local resultRemote: RemoteEvent

-- Texte saisi -> code normalisé (majuscules, sans espaces autour), ou nil si la saisie est invalide.
function PromoCodeService.normalize(input: unknown): string?
	if typeof(input) ~= "string" or #input > PromoCodes.MAX_LENGTH * 2 then
		return nil
	end
	local trimmed = string.upper((string.gsub(input, "^%s*(.-)%s*$", "%1")))
	if #trimmed == 0 or #trimmed > PromoCodes.MAX_LENGTH then
		return nil
	end
	return trimmed
end

-- Règle pure : le code peut-il être utilisé par ce joueur maintenant ?
function PromoCodeService.check(redeemed: { string }, input: unknown, now: number): (PromoCodes.CodeDef?, Status)
	local code = PromoCodeService.normalize(input)
	if code == nil then
		return nil, "invalid"
	end
	local def = PromoCodes.byCode[code]
	if def == nil then
		return nil, "unknown"
	end
	if table.find(redeemed, def.code) ~= nil then
		return nil, "used"
	end
	if def.expiresAt ~= nil and now > def.expiresAt then
		return nil, "expired"
	end
	return def, "ok"
end

local function grant(player: Player, data: any, def: PromoCodes.CodeDef)
	local reward = def.reward
	if reward.coins ~= nil and reward.coins > 0 then
		EconomyService.addCoins(player, reward.coins, "Reward", "PromoCode_" .. def.code)
	end
	if reward.luckPotion ~= nil and reward.luckPotion > 0 then
		BoostService.addToReserve(player, data, "luckPotion", reward.luckPotion)
	end
	if reward.shield ~= nil and reward.shield > 0 then
		BoostService.addToReserve(player, data, "shield", reward.shield)
	end
end

local function onRedeem(player: Player, input: unknown)
	local now = os.clock()
	if now - (lastTry[player] or -math.huge) < PromoCodes.COOLDOWN then
		return -- trop rapide : ignoré (le client grise son bouton pendant ce temps)
	end
	lastTry[player] = now
	local data = PlayerDataService.getData(player)
	if data == nil then
		return
	end
	local def, status = PromoCodeService.check(data.redeemedCodes, input, os.time())
	if def == nil then
		resultRemote:FireClient(player, status, nil)
		return
	end
	table.insert(data.redeemedCodes, def.code)
	grant(player, data, def)
	print(string.format("[PromoCodeService] %s utilise le code %s", player.Name, def.code))
	resultRemote:FireClient(player, status, def.reward)
end

function PromoCodeService.init()
	resultRemote = Remotes.get(Remotes.Names.CodeResult)
end

function PromoCodeService.start()
	Remotes.get(Remotes.Names.RedeemCode).OnServerEvent:Connect(onRedeem)
	Players.PlayerRemoving:Connect(function(player)
		lastTry[player] = nil
	end)
end

return PromoCodeService
