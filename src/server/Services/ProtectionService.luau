--!strict
-- Protection débutant : les 20 premières minutes de jeu cumulées, un joueur ne peut ni être volé,
-- ni voler (symétrique). Compte playTime pendant que le joueur est connecté (sauvegardé avec le profil)
-- et publie l'attribut ProtectedUntil (horodatage serveur de fin, 0 si non protégé).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StealConfig = require(Shared.Config.StealConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ATTRIBUTE_PROTECTED_UNTIL = "ProtectedUntil"

local ProtectionService = {}

-- Temps de protection restant (secondes) pour un temps de jeu donné. Fonction pure, testable.
function ProtectionService.remainingFor(playTime: number): number
	return math.max(0, StealConfig.PROTECTION_SECONDS - playTime)
end

function ProtectionService.remainingProtection(player: Player): number
	local data = PlayerDataService.getData(player)
	if data == nil then
		-- Profil pas encore chargé : on protège par prudence (ni voler, ni être volé).
		return StealConfig.PROTECTION_SECONDS
	end
	return ProtectionService.remainingFor(data.playTime)
end

function ProtectionService.isProtected(player: Player): boolean
	return ProtectionService.remainingProtection(player) > 0
end

local function publish(player: Player)
	local remaining = ProtectionService.remainingProtection(player)
	local protectedUntil = if remaining > 0 then Workspace:GetServerTimeNow() + remaining else 0
	player:SetAttribute(ATTRIBUTE_PROTECTED_UNTIL, protectedUntil)
end

-- Ajoute le temps réellement écoulé à chaque joueur chargé ; republie à la fin de la protection.
local function tick(elapsed: number)
	for _, player in Players:GetPlayers() do
		local data = PlayerDataService.getData(player)
		if data ~= nil then
			local wasProtected = ProtectionService.remainingFor(data.playTime) > 0
			data.playTime += elapsed
			if wasProtected and ProtectionService.remainingFor(data.playTime) <= 0 then
				publish(player)
				print(string.format("[ProtectionService] Fin de la protection débutant pour %s", player.Name))
			end
		end
	end
end

function ProtectionService.init() end

function ProtectionService.start()
	PlayerDataService.onLoaded(function(player: Player)
		publish(player)
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(StealConfig.PLAYTIME_TICK)
			local now = os.clock()
			tick(now - last)
			last = now
		end
	end)
end

return ProtectionService
