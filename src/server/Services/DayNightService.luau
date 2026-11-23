--!strict
-- Horloge du cycle jour et nuit, commune à tout le serveur. Publie la phase en attributs sur
-- ReplicatedStorage (Phase, PhaseEndsAt) pour que chaque client calcule son minuteur seul,
-- et prévient les clients (PhaseChanged) et les services (onPhaseChanged) à chaque changement.
-- Nuit de sang (semaine 5) : tirée EventConfig.WARNING_SECONDS avant chaque nuit et annoncée à tous ;
-- elle dure plus longtemps et rend les mutations Maudites plus fréquentes (LootService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DayNightConfig = require(Shared.Config.DayNightConfig)
local EventConfig = require(Shared.Config.EventConfig)
local Remotes = require(Shared.Remotes)

export type Phase = "Day" | "Night"
type PhaseCallback = (phase: Phase, endsAt: number) -> ()

local DayNightService = {}

local phase: Phase = DayNightConfig.FIRST_PHASE :: Phase
local phaseEndsAt = 0
local callbacks: { PhaseCallback } = {}
local phaseChangedRemote: RemoteEvent
local nightStartedAt = 0 -- horodatage serveur du début de la nuit en cours (0 le jour)
local bloodNight = false -- la nuit en cours est une Nuit de sang
local nextNightBlood: boolean? = nil -- tirage pour la prochaine nuit (nil : pas encore tiré)
local warningRemote: RemoteEvent
local rng = Random.new()

-- Tirage de la Nuit de sang (15 % par nuit). Pur : testé par Tests/EventRules.luau.
function DayNightService.rollBloodNight(random: Random): boolean
	return random:NextNumber() < EventConfig.BLOOD_NIGHT_CHANCE
end

-- Durée d'une nuit : plus longue pour une Nuit de sang.
function DayNightService.getNightDuration(isBlood: boolean): number
	return if isBlood then EventConfig.BLOOD_NIGHT_DURATION else DayNightConfig.NIGHT_DURATION
end

local function getDuration(target: Phase): number
	return if target == "Night"
		then DayNightService.getNightDuration(nextNightBlood == true)
		else DayNightConfig.DAY_DURATION
end

-- Prochaine nuit tirée (ou forcée en test) : annoncée à tous si c'est une Nuit de sang.
local function decideNextNight(isBlood: boolean)
	nextNightBlood = isBlood
	if isBlood then
		local startsAt = if phase == "Day" then phaseEndsAt else Workspace:GetServerTimeNow()
		ReplicatedStorage:SetAttribute(EventConfig.ATTRIBUTE_BLOOD_NIGHT_STARTS_AT, startsAt)
		warningRemote:FireAllClients("bloodNight", startsAt)
		print("[DayNightService] Nuit de sang annoncée")
	end
end

-- endsAt est un horodatage serveur absolu : enchaîner les phases depuis la fin prévue de la
-- précédente (et non depuis l'instant de détection) évite toute dérive du cycle.
local function setPhase(target: Phase, endsAt: number, startedAt: number)
	local duration = endsAt - Workspace:GetServerTimeNow()
	phase = target
	phaseEndsAt = endsAt
	nightStartedAt = if target == "Night" then startedAt else 0
	bloodNight = target == "Night" and nextNightBlood == true
	if target == "Night" then
		nextNightBlood = nil -- la nuit suivante sera tirée à son tour
	end
	ReplicatedStorage:SetAttribute(EventConfig.ATTRIBUTE_BLOOD_NIGHT, bloodNight)
	ReplicatedStorage:SetAttribute(EventConfig.ATTRIBUTE_BLOOD_NIGHT_STARTS_AT, 0)
	ReplicatedStorage:SetAttribute(DayNightConfig.ATTRIBUTE_PHASE, phase)
	ReplicatedStorage:SetAttribute(DayNightConfig.ATTRIBUTE_PHASE_ENDS_AT, phaseEndsAt)
	phaseChangedRemote:FireAllClients(phase, phaseEndsAt)
	local label = if bloodNight then "Nuit de sang" elseif phase == "Night" then "Nuit" else "Jour"
	print(string.format("[DayNightService] %s (%d s)", label, duration))
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

-- La nuit en cours est-elle une Nuit de sang ?
function DayNightService.isBloodNight(): boolean
	return phase == "Night" and bloodNight
end

-- Commande de test, Studio seulement : la prochaine nuit sera (ou ne sera pas) une Nuit de sang.
function DayNightService.setNextNightBlood(isBlood: boolean)
	if not RunService:IsStudio() then
		warn("[DayNightService] setNextNightBlood est réservé à Studio")
		return
	end
	decideNextNight(isBlood)
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
	warningRemote = Remotes.get(Remotes.Names.WorldEventWarning)
	ReplicatedStorage:SetAttribute(EventConfig.ATTRIBUTE_BLOOD_NIGHT, false)
	ReplicatedStorage:SetAttribute(EventConfig.ATTRIBUTE_BLOOD_NIGHT_STARTS_AT, 0)
	-- Phase de départ publiée sans notification (aucun service n'a encore à réagir).
	phaseEndsAt = Workspace:GetServerTimeNow() + getDuration(phase)
	ReplicatedStorage:SetAttribute(DayNightConfig.ATTRIBUTE_PHASE, phase)
	ReplicatedStorage:SetAttribute(DayNightConfig.ATTRIBUTE_PHASE_ENDS_AT, phaseEndsAt)
end

function DayNightService.start()
	RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		-- Nuit de sang : tirée (et annoncée) WARNING_SECONDS avant la tombée de la nuit.
		if phase == "Day" and nextNightBlood == nil and now >= phaseEndsAt - EventConfig.WARNING_SECONDS then
			decideNextNight(DayNightService.rollBloodNight(rng))
		end
		if now >= phaseEndsAt then
			local nextPhase: Phase = if phase == "Day" then "Night" else "Day"
			setPhase(nextPhase, phaseEndsAt + getDuration(nextPhase), phaseEndsAt)
		end
	end)
end

return DayNightService
