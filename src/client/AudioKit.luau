--!strict
-- Sons du client : chaque son appartient à un groupe (Musique ou Effets) que le joueur peut couper dans
-- le menu Son. Les réglages sont enregistrés par le serveur (SettingsService) et publiés en attributs
-- du joueur (MusicMuted, EffectsMuted) ; le client les applique tout de suite, sans attendre.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared.Config.AudioConfig)
local Remotes = require(Shared.Remotes)

export type Kind = "music" | "effects"

local ATTRIBUTES: { [Kind]: string } = { music = "MusicMuted", effects = "EffectsMuted" }
local GROUP_NAMES: { [Kind]: string } = { music = "Music", effects = "Effects" }
local GROUP_VOLUMES: { [Kind]: number } =
	{ music = AudioConfig.MUSIC_GROUP_VOLUME, effects = AudioConfig.EFFECTS_GROUP_VOLUME }

local player = Players.LocalPlayer

local AudioKit = {}

local groups: { [Kind]: SoundGroup } = {}
local localMuted: { [Kind]: boolean? } = {} -- choix fait sur ce client, en attendant le serveur
local started = false

function AudioKit.isMuted(kind: Kind): boolean
	local pending = localMuted[kind]
	if pending ~= nil then
		return pending
	end
	return player:GetAttribute(ATTRIBUTES[kind]) == true
end

local function applyGroup(kind: Kind)
	local group = groups[kind]
	if group ~= nil then
		group.Volume = if AudioKit.isMuted(kind) then 0 else GROUP_VOLUMES[kind]
	end
end

local function ensureStarted()
	if started then
		return
	end
	started = true
	for kind, name in GROUP_NAMES do
		local group = Instance.new("SoundGroup")
		group.Name = name
		group.Parent = SoundService
		groups[kind] = group
		applyGroup(kind)
		player:GetAttributeChangedSignal(ATTRIBUTES[kind]):Connect(function()
			localMuted[kind] = nil -- le serveur a répondu : sa valeur fait foi
			applyGroup(kind)
		end)
	end
end

function AudioKit.group(kind: Kind): SoundGroup
	ensureStarted()
	return groups[kind]
end

-- Crée un son du groupe donné (effets par défaut), dans SoundService ou dans parent (son 3D).
function AudioKit.create(name: string, def: AudioConfig.SoundDef, kind: Kind?, parent: Instance?): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.id
	sound.Volume = def.volume
	sound.PlaybackSpeed = def.pitch or 1
	sound.SoundGroup = AudioKit.group(kind or "effects")
	sound.Parent = parent or SoundService
	return sound
end

-- Le joueur coupe ou rétablit un groupe : appliqué tout de suite, puis enregistré par le serveur.
function AudioKit.setMuted(kind: Kind, muted: boolean)
	ensureStarted()
	localMuted[kind] = muted
	applyGroup(kind)
	Remotes.get(Remotes.Names.SetAudioSetting):FireServer(kind, muted)
end

return AudioKit
