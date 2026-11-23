--!strict
-- Tests du salon VIP et de la boutique de cosmétiques de voleur (plan semaine 5, section 9).
-- Lancement dans Studio (côté serveur, pendant un playtest) :
--   require(game.ServerScriptService.Server.Tests.CosmeticRules).run()

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared.Config.Cosmetics)
local CosmeticShop = require(Shared.CosmeticShop)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Services = script.Parent.Parent.Services
local PlayerDataService = require(Services.PlayerDataService)
local EconomyService = require(Services.EconomyService)
local VipLoungeService = require(Services.VipLoungeService)

local CosmeticRules = {}

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

local function newState(): CosmeticShop.State
	return { owned = {} }
end

local function testCatalog()
	local masks, bags = 0, 0
	for _, def in Cosmetics.list do
		if def.slot == "mask" then
			masks += 1
		elseif def.slot == "bag" then
			bags += 1
		end
		check("prix entier positif : " .. def.id, def.price > 0 and def.price % 1 == 0)
		check("au moins une pièce : " .. def.id, #def.parts > 0)
	end
	check("3 masques", masks == 3, tostring(masks))
	check("2 sacs à dos", bags == 2, tostring(bags))
	-- Prix en Points de Voleur, jamais en Robux : aucun produit ni pass ne porte un id de cosmétique.
	local robux = false
	for _, product in MonetizationConfig.products do
		robux = robux or Cosmetics.byId[product.key] ~= nil
	end
	for _, pass in MonetizationConfig.passes do
		robux = robux or Cosmetics.byId[pass.key] ~= nil
	end
	check("aucun cosmétique vendu en Robux", not robux)
end

local function testBuy()
	local state = newState()
	local def, reason = CosmeticShop.checkBuy(state, 2, "burglar_mask")
	check("achat refusé sans assez de points", def == nil and reason == "points", tostring(reason))
	def, reason = CosmeticShop.checkBuy(state, 99, "inconnu")
	check("achat refusé : id inconnu", def == nil and reason == "unknown")
	def, reason = CosmeticShop.checkBuy(state, 99, 42)
	check("achat refusé : id pas une chaîne", def == nil and reason == "unknown")
	def, reason = CosmeticShop.checkBuy(state, 99, string.rep("a", Cosmetics.ID_MAX_LENGTH + 1))
	check("achat refusé : id trop long", def == nil and reason == "unknown")

	def = CosmeticShop.checkBuy(state, 3, "burglar_mask")
	check("achat permis avec le prix exact", def ~= nil)
	local points = CosmeticShop.applyBuy(state, 3, def :: Cosmetics.CosmeticDef)
	check("points retirés", points == 0, tostring(points))
	check("cosmétique possédé", CosmeticShop.owns(state, "burglar_mask"))
	check("cosmétique porté tout de suite", state.mask == "burglar_mask")
	def, reason = CosmeticShop.checkBuy(state, 99, "burglar_mask")
	check("achat refusé : déjà possédé", def == nil and reason == "owned")

	local bag = CosmeticShop.checkBuy(state, 10, "loot_sack")
	CosmeticShop.applyBuy(state, 10, bag :: Cosmetics.CosmeticDef)
	check("un sac ne remplace pas le masque", state.mask == "burglar_mask" and state.bag == "loot_sack")
end

local function testEquip()
	local state: CosmeticShop.State = { owned = { "burglar_mask", "loot_sack" }, mask = nil, bag = nil }
	local ok, id = CosmeticShop.checkEquip(state, "mask", "burglar_mask")
	check("porter un masque possédé", ok and id == "burglar_mask")
	local _, _, reason = CosmeticShop.checkEquip(state, "mask", "venetian_mask")
	check("refus : masque non possédé", reason == "notOwned")
	ok, _, reason = CosmeticShop.checkEquip(state, "bag", "burglar_mask")
	check("refus : masque dans l'emplacement du sac", not ok and reason == "slot")
	ok, _, reason = CosmeticShop.checkEquip(state, "hat", "burglar_mask")
	check("refus : emplacement inconnu", not ok and reason == "slot")
	ok, id = CosmeticShop.checkEquip(state, "bag", "")
	check("retirer le sac", ok and id == nil)
end

local function testMigration()
	local data: any = { version = 5, inventory = {}, thiefPoints = 7, settings = {} }
	PlayerDataService.migrate(data)
	check(
		"migration v5 -> v6 (puis version courante)",
		data.version == PlayerConfig.DATA_VERSION and data.cosmetics ~= nil
	)
	check("migration : aucun cosmétique, points gardés", #data.cosmetics.owned == 0 and data.thiefPoints == 7)
end

local function testFirstPointHint()
	local data: any = { version = 6, inventory = {}, thiefPoints = 3, settings = {}, cosmetics = { owned = {} } }
	PlayerDataService.migrate(data)
	check("migration v6 -> v7 (puis version courante)", data.version == PlayerConfig.DATA_VERSION)
	check("migration : message pas encore montré", data.thiefPointHintDone == false)
	local done: any = { version = 6, inventory = {}, thiefPointHintDone = true }
	PlayerDataService.migrate(done)
	check("migration : message déjà montré, gardé", done.thiefPointHintDone == true)
	check("délai du message après le bandeau du vol", Cosmetics.HINT_DELAY > 0)
end

local function testVipLounge()
	local box = CFrame.new(10, 5, 0)
	local size = WorldConfig.VIP_LOUNGE_SIZE
	check("dans le salon : centre", VipLoungeService.isInside(Vector3.new(10, 5, 0), box, size))
	check(
		"hors du salon : devant la porte",
		not VipLoungeService.isInside(Vector3.new(10 + size.X / 2 + 1, 3, 0), box, size)
	)
	check(
		"porte non bloquante pour les VIP",
		not PhysicsService:CollisionGroupsAreCollidable(
			WorldConfig.VIP_DOOR_COLLISION_GROUP,
			WorldConfig.VIP_MEMBER_COLLISION_GROUP
		)
	)
	check(
		"porte bloquante pour les autres",
		PhysicsService:CollisionGroupsAreCollidable(WorldConfig.VIP_DOOR_COLLISION_GROUP, "Default")
	)
	-- Le salon tient entre les deux rangées de parcelles.
	local halfOuterZ = size.Z / 2 + WorldConfig.VIP_WALL_THICKNESS
	check("salon entre les rangées de parcelles", halfOuterZ < PlotConfig.ROW_SPACING / 2, tostring(halfOuterZ))

	local merchant, vip = Vector3.new(0, 0, 0), Vector3.new(-30, 0, 0)
	local nearVip = vip + Vector3.new(EconomyConfig.MERCHANT_MAX_DISTANCE - 1, 0, 0)
	check("vente au Marchand VIP : VIP accepté", EconomyService.isNearMerchant(nearVip, merchant, vip, true))
	check("vente au Marchand VIP : non VIP refusé", not EconomyService.isNearMerchant(nearVip, merchant, vip, false))
	check(
		"vente au Marchand : tout le monde",
		EconomyService.isNearMerchant(Vector3.new(3, 0, 0), merchant, vip, false)
	)
	check("vente : trop loin des deux", not EconomyService.isNearMerchant(Vector3.new(200, 0, 0), merchant, vip, true))
end

function CosmeticRules.run(): (string, number, number)
	results = {}
	passed = 0
	failed = 0
	testCatalog()
	testBuy()
	testEquip()
	testMigration()
	testFirstPointHint()
	testVipLounge()
	local report = string.format("[CosmeticRules] %d OK, %d échec(s)\n%s", passed, failed, table.concat(results, "\n"))
	print(report)
	return report, passed, failed
end

return CosmeticRules
