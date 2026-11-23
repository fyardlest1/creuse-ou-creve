--!strict
-- Point d'entrée client : init() puis start() de chaque contrôleur, dans l'ordre.

type Controller = {
	init: () -> (),
	start: () -> (),
}

local Controllers = script.Parent:WaitForChild("Controllers")

local orderedControllers: { [number]: { name: string, module: Controller } } = {
	{ name = "LocaleController", module = require(Controllers:WaitForChild("LocaleController")) :: any },
	{ name = "PromoCodeController", module = require(Controllers:WaitForChild("PromoCodeController")) :: any },
	{
		name = "SoundSettingsController",
		module = require(Controllers:WaitForChild("SoundSettingsController")) :: any,
	},
	{ name = "HudController", module = require(Controllers:WaitForChild("HudController")) :: any },
	{ name = "DayNightController", module = require(Controllers:WaitForChild("DayNightController")) :: any },
	{ name = "RevealController", module = require(Controllers:WaitForChild("RevealController")) :: any },
	{
		name = "AnnouncementController",
		module = require(Controllers:WaitForChild("AnnouncementController")) :: any,
	},
	{ name = "WorldEventController", module = require(Controllers:WaitForChild("WorldEventController")) :: any },
	{ name = "AuraController", module = require(Controllers:WaitForChild("AuraController")) :: any },
	{ name = "WorldSignController", module = require(Controllers:WaitForChild("WorldSignController")) :: any },
	{ name = "ShovelController", module = require(Controllers:WaitForChild("ShovelController")) :: any },
	{ name = "DigController", module = require(Controllers:WaitForChild("DigController")) :: any },
	{ name = "DigHintController", module = require(Controllers:WaitForChild("DigHintController")) :: any },
	{ name = "ChestController", module = require(Controllers:WaitForChild("ChestController")) :: any },
	{ name = "MerchantController", module = require(Controllers:WaitForChild("MerchantController")) :: any },
	{ name = "ForgeController", module = require(Controllers:WaitForChild("ForgeController")) :: any },
	{
		name = "CosmeticShopController",
		module = require(Controllers:WaitForChild("CosmeticShopController")) :: any,
	},
	{ name = "LockpickController", module = require(Controllers:WaitForChild("LockpickController")) :: any },
	{ name = "StealController", module = require(Controllers:WaitForChild("StealController")) :: any },
	{ name = "VipController", module = require(Controllers:WaitForChild("VipController")) :: any },
	{ name = "ShopController", module = require(Controllers:WaitForChild("ShopController")) :: any },
	{ name = "RetentionController", module = require(Controllers:WaitForChild("RetentionController")) :: any },
}

for _, entry in orderedControllers do
	entry.module.init()
end

for _, entry in orderedControllers do
	entry.module.start()
end

print("[Main] Client démarré (" .. #orderedControllers .. " contrôleurs)")
