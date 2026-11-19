--!strict
-- Point d'entrée serveur : init() puis start() de chaque service, dans l'ordre.

type Service = {
	init: () -> (),
	start: () -> (),
}

local Services = script.Parent:WaitForChild("Services")

local orderedServices: { [number]: { name: string, module: Service } } = {
	{ name = "PlayerDataService", module = require(Services.PlayerDataService) :: any },
}

for _, entry in orderedServices do
	entry.module.init()
end

for _, entry in orderedServices do
	entry.module.start()
end

print("[Main] Serveur démarré (" .. #orderedServices .. " services)")
