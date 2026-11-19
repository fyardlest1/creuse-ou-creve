--!strict
-- Point d'entrée serveur : init() puis start() de chaque service, dans l'ordre.

type Service = {
	init: () -> (),
	start: () -> (),
}

local Services = script.Parent:WaitForChild("Services")

local orderedServices: { [number]: { name: string, module: Service } } = {
	{ name = "PlayerDataService", module = require(Services.PlayerDataService) :: any },
	{ name = "EconomyService", module = require(Services.EconomyService) :: any },
	{ name = "PlotService", module = require(Services.PlotService) :: any },
	{ name = "LootService", module = require(Services.LootService) :: any },
	{ name = "DigService", module = require(Services.DigService) :: any },
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
