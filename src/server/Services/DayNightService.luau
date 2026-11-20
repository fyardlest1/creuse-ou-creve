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

local function getDuration(target: Phase): number
	return if target == "Night" then DayNightConfig.NIGHT_DURATION else DayNightConfig.DAY_DURATION
end

-- endsAt est un horodatage serveur absolu : enchaîner les phases depuis la fin prévue de la
-- précédente (et non depuis l'instant de détection) évite toute dérive du cycle.
local function setPhase(target: Phase, endsAt: number)
	local duration = endsAt - Workspace:GetServerTimeNow()
	phase = target
	phaseEndsAt = endsAt
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
	setPhase(target, Workspace:GetServerTimeNow() + (duration or getDuration(target)))
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
			setPhase(nextPhase, phaseEndsAt + getDuration(nextPhase))
		end
	end)
end

return DayNightService
