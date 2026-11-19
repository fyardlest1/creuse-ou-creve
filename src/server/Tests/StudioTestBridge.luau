--!strict
-- Pont de test, chargé uniquement dans Studio : expose les services vivants aux scripts de test
-- (barre de commande, MCP) via une BindableFunction dans ServerStorage, hors de portée des clients.
-- Usage : ServerStorage.StudioTestBridge:Invoke("EconomyService", "addCoins", player, 100, "Sell")
-- Aides : Invoke("Test", "getData", player), Invoke("Test", "setField", player, "coins", 0),
--         Invoke("Test", "setStat", player, "itemsSold", 0)

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local BRIDGE_NAME = "StudioTestBridge"

local StudioTestBridge = {}

function StudioTestBridge.install(services: { [string]: any })
	if not RunService:IsStudio() then
		return
	end
	local PlayerDataService = services.PlayerDataService

	local testHelpers = {
		getData = function(player: Player): any
			return PlayerDataService.getData(player)
		end,
		setField = function(player: Player, field: string, value: any)
			local data = PlayerDataService.getData(player) :: any
			data[field] = value
			PlayerDataService.refreshAttributes(player)
		end,
		setStat = function(player: Player, field: string, value: any)
			local data = PlayerDataService.getData(player) :: any
			data.stats[field] = value
		end,
	}

	local bridge = Instance.new("BindableFunction")
	bridge.Name = BRIDGE_NAME
	bridge.OnInvoke = function(serviceName: string, methodName: string, ...: any): ...any
		local service = if serviceName == "Test" then testHelpers else services[serviceName]
		assert(service ~= nil, "[StudioTestBridge] Service inconnu : " .. tostring(serviceName))
		local method = service[methodName]
		assert(typeof(method) == "function", "[StudioTestBridge] Méthode inconnue : " .. tostring(methodName))
		return method(...)
	end
	bridge.Parent = ServerStorage
	print("[StudioTestBridge] Installé (Studio seulement)")
end

return StudioTestBridge
