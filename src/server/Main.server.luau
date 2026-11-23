--!strict
-- Point d'entrée serveur : init() puis start() de chaque service, dans l'ordre.

type Service = {
	init: () -> (),
	start: () -> (),
}

local Services = script.Parent:WaitForChild("Services")

local orderedServices: { [number]: { name: string, module: Service } } = {
	{ name = "PlayerDataService", module = require(Services.PlayerDataService) :: any },
	{ name = "DayNightService", module = require(Services.DayNightService) :: any },
	{ name = "MeteorService", module = require(Services.MeteorService) :: any },
	{ name = "ProtectionService", module = require(Services.ProtectionService) :: any },
	{ name = "EconomyService", module = require(Services.EconomyService) :: any },
	{ name = "PlotService", module = require(Services.PlotService) :: any },
	{ name = "WorldService", module = require(Services.WorldService) :: any },
	{ name = "ShovelVisualService", module = require(Services.ShovelVisualService) :: any },
	{ name = "ShopService", module = require(Services.ShopService) :: any },
	{ name = "StealService", module = require(Services.StealService) :: any },
	{ name = "PurchaseService", module = require(Services.PurchaseService) :: any },
	{ name = "BoostService", module = require(Services.BoostService) :: any },
	{ name = "LootService", module = require(Services.LootService) :: any },
	{ name = "DigService", module = require(Services.DigService) :: any },
	{ name = "AutoDigService", module = require(Services.AutoDigService) :: any },
	{ name = "VipLoungeService", module = require(Services.VipLoungeService) :: any },
	{ name = "CosmeticService", module = require(Services.CosmeticService) :: any },
	{ name = "PromoCodeService", module = require(Services.PromoCodeService) :: any },
	{ name = "SettingsService", module = require(Services.SettingsService) :: any },
	{ name = "RetentionService", module = require(Services.RetentionService) :: any },
}

for _, entry in orderedServices do
	entry.module.init()
end

for _, entry in orderedServices do
	entry.module.start()
end

local RunService = game:GetService("RunService")
if RunService:IsStudio() then
	local servicesByName: { [string]: any } = {}
	for _, entry in orderedServices do
		servicesByName[entry.name] = entry.module
	end
	require(script.Parent:WaitForChild("Tests"):WaitForChild("StudioTestBridge")).install(servicesByName)
end

print("[Main] Serveur démarré (" .. #orderedServices .. " services)")
