--!strict
-- Tests des codes promo (plan semaine 5, section 10).
-- Lancement dans Studio (côté serveur, pendant un playtest) :
--   require(game.ServerScriptService.Server.Tests.PromoCodeRules).run()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PromoCodes = require(Shared.Config.PromoCodes)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local Services = script.Parent.Parent.Services
local PromoCodeService = require(Services.PromoCodeService)
local PlayerDataService = require(Services.PlayerDataService)

local PromoCodeRules = {}

local results: { string } = {}
local passed = 0
local failed = 0

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		table.insert(results, "  OK    " .. name)
	else
		failed += 1
		table.insert(results, "  ÉCHEC " .. name .. (if detail then " (" .. detail .. ")" else ""))
	end
end

local NOW = DateTime.fromUniversalTime(2026, 12, 1).UnixTimestamp

local function testLaunchCodes()
	local creuse, tresor, discord = PromoCodes.byCode.CREUSE, PromoCodes.byCode.TRESOR, PromoCodes.byCode.DISCORD
	check("CREUSE : 1 Potion de chance", creuse ~= nil and creuse.reward.luckPotion == 1 and creuse.reward.coins == nil)
	check("TRESOR : 2 000 Pièces", tresor ~= nil and tresor.reward.coins == 2000)
	check("DISCORD : 1 Bouclier", discord ~= nil and discord.reward.shield == 1)
	check("codes de lancement sans date d'expiration", creuse.expiresAt == nil and tresor.expiresAt == nil)
end

local function testNormalize()
	check("insensible aux majuscules", PromoCodeService.normalize("creuse") == "CREUSE")
	check("espaces autour ignorés", PromoCodeService.normalize("  TrEsOr \n") == "TRESOR")
	check("vide refusé", PromoCodeService.normalize("   ") == nil)
	check("pas une chaîne refusé", PromoCodeService.normalize(123) == nil)
	check("trop long refusé", PromoCodeService.normalize(string.rep("A", PromoCodes.MAX_LENGTH + 1)) == nil)
	check("texte énorme refusé", PromoCodeService.normalize(string.rep("A", 10000)) == nil)
end

local function testCheck()
	local redeemed: { string } = {}
	local def, status = PromoCodeService.check(redeemed, "creuse", NOW)
	check("code valide accepté", def ~= nil and status == "ok")
	table.insert(redeemed, "CREUSE")
	def, status = PromoCodeService.check(redeemed, "CREUSE", NOW)
	check("une seule fois par joueur", def == nil and status == "used")
	def, status = PromoCodeService.check(redeemed, " Creuse ", NOW)
	check("une seule fois, quelle que soit l'écriture", def == nil and status == "used")
	def, status = PromoCodeService.check(redeemed, "TRESOR", NOW)
	check("un autre code reste utilisable", def ~= nil and status == "ok")
	def, status = PromoCodeService.check(redeemed, "INCONNU", NOW)
	check("code inconnu refusé", def == nil and status == "unknown")
	def, status = PromoCodeService.check(redeemed, nil, NOW)
	check("saisie invalide refusée", def == nil and status == "invalid")
end

local function testExpiry()
	-- Code daté fabriqué pour le test (la config de lancement n'en a pas).
	local expiresAt = PromoCodes.utc(2026, 12, 31)
	check("utc : fin du jour inclus", expiresAt == DateTime.fromUniversalTime(2026, 12, 31, 23, 59, 59).UnixTimestamp)
	local saved = (PromoCodes.byCode :: any).TRESOR
	local dated = { code = "TRESOR", reward = saved.reward, expiresAt = expiresAt }
	-- byCode est une table normale (seul le module est figé) : on remet le vrai code juste après.
	(PromoCodes.byCode :: any).TRESOR = dated
	local before = select(2, PromoCodeService.check({}, "TRESOR", expiresAt))
	local after = select(2, PromoCodeService.check({}, "TRESOR", expiresAt + 1));
	(PromoCodes.byCode :: any).TRESOR = saved
	check("valable jusqu'à la date d'expiration", before == "ok", tostring(before))
	check("refusé après la date d'expiration", after == "expired", tostring(after))
end

local function testMigration()
	local data: any = { version = 7, inventory = {} }
	PlayerDataService.migrate(data)
	check("migration v7 -> v8 (version courante)", data.version == PlayerConfig.DATA_VERSION and data.version >= 8)
	check("migration : aucun code utilisé", typeof(data.redeemedCodes) == "table" and #data.redeemedCodes == 0)
end

function PromoCodeRules.run(): (string, number, number)
	results = {}
	passed = 0
	failed = 0
	testLaunchCodes()
	testNormalize()
	testCheck()
	testExpiry()
	testMigration()
	local report =
		string.format("[PromoCodeRules] %d OK, %d échec(s)\n%s", passed, failed, table.concat(results, "\n"))
	print(report)
	return report, passed, failed
end

return PromoCodeRules
