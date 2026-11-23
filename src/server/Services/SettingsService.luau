--!strict
-- Réglages du joueur enregistrés dans ses données : pour l'instant, couper la musique ou les effets
-- sonores (menu Son). Le client envoie son choix, le serveur valide puis enregistre et publie les
-- attributs MusicMuted et EffectsMuted (lus par AudioKit).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared.Config.AudioConfig)
local Remotes = require(Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)

local SettingsService = {}

local lastChange: { [Player]: number } = {}

local function onSetAudioSetting(player: Player, kind: unknown, muted: unknown)
	if (kind ~= "music" and kind ~= "effects") or typeof(muted) ~= "boolean" then
		warn("[SettingsService] Réglage invalide refusé (" .. player.Name .. ")")
		return
	end
	local now = os.clock()
	if now - (lastChange[player] or -math.huge) < AudioConfig.SETTING_COOLDOWN then
		return
	end
	lastChange[player] = now
	local data = PlayerDataService.getData(player)
	if data == nil then
		return
	end
	if kind == "music" then
		data.settings.musicMuted = muted
	else
		data.settings.effectsMuted = muted
	end
	PlayerDataService.refreshAttributes(player)
end

function SettingsService.init() end

function SettingsService.start()
	Remotes.get(Remotes.Names.SetAudioSetting).OnServerEvent:Connect(onSetAudioSetting)
	Players.PlayerRemoving:Connect(function(player)
		lastChange[player] = nil
	end)
end

return SettingsService
