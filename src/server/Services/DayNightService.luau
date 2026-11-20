--!strict
-- Horloge du cycle jour et nuit, commune à tout le serveur. Publie la phase en attributs sur
-- ReplicatedStorage (Phase, PhaseEndsAt) pour que chaque client calcule son minuteur seul,
-- et prévient les clients (PhaseChanged) et les services (onPhaseChanged) à chaque changement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DayNightConfig = require(Shared.Config.DayNightConfig)
local Remotes = require(Shared.Remotes)

export type Phase = "Day" | "Night"
type PhaseCallback = (phase: Phase, endsAt: number) -> ()

local DayNightService = {}

local phase: Phase = DayNightConfig.FIRST_PHASE :: Phase
local phaseEndsAt = 0
local callbacks: { PhaseCallback } = {}
local phaseChangedRemote: RemoteEvent
local nightStartedAt = 0 -- horodatage serveur du début de la nuit en cours (0 le jour)

local function getDuration(target: Phase): number
	return if target == "Night" then DayNightConfig.NIGHT_DURATION else DayNightConfig.DAY_DURATION
end

-- endsAt est un horodatage serveur absolu : enchaîner les phases depuis la fin prévue de la
-- précédente (et non depuis l'instant de détection) évite toute dérive du cycle.
local function setPhase(target: Phase, endsAt: number, startedAt: number)
	local duration = endsAt - Workspace:GetServerTimeNow()
	phase = target
	phaseEndsAt = endsAt
	nightStartedAt = if target == "Night" then startedAt else 0
	ReplicatedStorage:SetAttribute(DayNightConfig.ATTRIBUTE_PHASE, phase)
	ReplicatedStorage:SetAttribute(DayNightConfig.ATTRIBUTE_PHASE_ENDS_AT, phaseEndsAt)
	phaseChangedRemote:FireAllClients(phase, phaseEndsAt)
	print(string.format("[DayNightService] %s (%d s)", if phase == "Night" then "Nuit" else "Jour", duration))
	for _, callback in callbacks do
		task.spawn(callback, phase, phaseEndsAt)
	end
end

function DayNightService.getPhase(): Phase
	return phase
end

function DayNightService.isNight(): boolean
	return phase == "Night"
end

-- Identifiant de nuit : l'horodatage serveur (arrondi à la seconde) du début de la nuit. Il est unique
-- d'un serveur à l'autre, donc un Bouclier ne protège jamais une autre nuit que celle visée.
-- Nuit en cours la nuit, prochaine nuit le jour. Sert au Bouclier anti-vol.
function DayNightService.getTargetNightId(): number
	return math.floor(if phase == "Night" then nightStartedAt else phaseEndsAt)
end

-- Identifiant de la nuit en cours, ou 0 le jour.
function DayNightService.getCurrentNightId(): number
	return if phase == "Night" then math.floor(nightStartedAt) else 0
end

-- Horodatage serveur (GetServerTimeNow) de la fin de la phase actuelle.
function DayNightService.getPhaseEndsAt(): number
	return phaseEndsAt
end

-- Appelé à chaque changement de phase (jamais pour la phase de départ).
function DayNightService.onPhaseChanged(callback: PhaseCallback)
	table.insert(callbacks, callback)
end

-- Commande de test, Studio seulement : force le jour ou la nuit tout de suite, pour une durée normale
-- ou donnée. Refusée sur un serveur en ligne.
function DayNightService.forcePhase(target: Phase, duration: number?)
	if not RunService:IsStudio() then
		warn("[DayNightService] forcePhase est réservé à Studio")
		return
	end
	if target ~= "Day" and target ~= "Night" then
		warn("[DayNightService] Phase inconnue : " .. tostring(target))
		return
	end
	local now = Workspace:GetServerTimeNow()
	-- Une nuit forcée depuis le jour est « la prochaine nuit » : même identifiant que celui annoncé le jour
	-- (un Bouclier acheté pour la prochaine nuit s'applique donc aussi pendant les tests).
	local startedAt = if target == "Night" and phase == "Day" then phaseEndsAt else now
	setPhase(target, now + (duration or getDuration(target)), startedAt)
end

function DayNightService.init()
	phaseChangedRemote = Remotes.get(Remotes.Names.PhaseChanged)
	-- Phase de départ publiée sans notification (aucun service n'a encore à réagir).
	phaseEndsAt = Workspace:GetServerTimeNow() + getDuration(phase)
	ReplicatedStorage:SetAttribute(DayNightConfig.ATTRIBUTE_PHASE, phase)
	ReplicatedStorage:SetAttribute(DayNightConfig.ATTRIBUTE_PHASE_ENDS_AT, phaseEndsAt)
end

function DayNightService.start()
	RunService.Heartbeat:Connect(function()
		if Workspace:GetServerTimeNow() >= phaseEndsAt then
			local nextPhase: Phase = if phase == "Day" then "Night" else "Day"
			setPhase(nextPhase, phaseEndsAt + getDuration(nextPhase), phaseEndsAt)
		end
	end)
end

return DayNightService
