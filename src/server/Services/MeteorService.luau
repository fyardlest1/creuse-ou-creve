--!strict
-- Pluie de météorites (plan semaine 5, section 7) : toutes les 30 minutes, pendant 3 minutes, les chances
-- de Rare et mieux sont doublées pour tous, dans la formule unique de la chance (LootService, plafond x10).
-- Annoncée à tout le serveur WARNING_SECONDS avant. Les météorites elles-mêmes sont un effet visuel,
-- dessiné par chaque client (WorldEventController) d'après les attributs publiés ici.
--
-- Le calendrier (Schedule) est pur : il avance avec l'heure qu'on lui donne, pour être testé par
-- Tests/EventRules.luau sans attendre 30 minutes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventConfig = require(Shared.Config.EventConfig)
local Remotes = require(Shared.Remotes)

export type ScheduleEvent = "warning" | "start" | "end"

local Schedule = {}
Schedule.__index = Schedule

export type Schedule = typeof(setmetatable(
	{} :: {
		nextStartAt: number, -- début de la prochaine pluie
		warned: boolean, -- la prochaine pluie a déjà été annoncée
		announcedStartAt: number, -- début de la dernière pluie annoncée
		activeStartAt: number, -- pluie en cours : début (0 si aucune)
		activeEndsAt: number, -- pluie en cours : fin (0 si aucune)
	},
	Schedule
))

-- Première pluie METEOR_INTERVAL après openedAt (ouverture du serveur).
function Schedule.new(openedAt: number): Schedule
	return setmetatable({
		nextStartAt = openedAt + EventConfig.METEOR_INTERVAL,
		warned = false,
		announcedStartAt = 0,
		activeStartAt = 0,
		activeEndsAt = 0,
	}, Schedule)
end

-- Avance jusqu'à now ; retourne les étapes franchies, dans l'ordre.
function Schedule.step(self: Schedule, now: number): { ScheduleEvent }
	local events: { ScheduleEvent } = {}
	if self.activeEndsAt ~= 0 and now >= self.activeEndsAt then
		self.activeStartAt = 0
		self.activeEndsAt = 0
		table.insert(events, "end")
	end
	if not self.warned and now >= self.nextStartAt - EventConfig.WARNING_SECONDS then
		self.warned = true
		self.announcedStartAt = self.nextStartAt
		table.insert(events, "warning")
	end
	if now >= self.nextStartAt then
		self.activeStartAt = self.nextStartAt
		self.activeEndsAt = self.nextStartAt + EventConfig.METEOR_DURATION
		-- Prochaine pluie : un intervalle après le début de celle-ci (le cycle ne dérive pas).
		self.nextStartAt += EventConfig.METEOR_INTERVAL
		self.warned = false
		table.insert(events, "start")
	end
	return events
end

function Schedule.isActive(self: Schedule, now: number): boolean
	return self.activeEndsAt ~= 0 and now >= self.activeStartAt and now < self.activeEndsAt
end

-- Test : la prochaine pluie commence à startsAt (annoncée dès le prochain step).
function Schedule.forceNext(self: Schedule, startsAt: number)
	self.nextStartAt = startsAt
	self.warned = false
end

local MeteorService = {}
MeteorService.Schedule = Schedule

local schedule: Schedule
local warningRemote: RemoteEvent

local function publish()
	local announced = schedule.warned or schedule.activeEndsAt ~= 0
	local startsAt = if schedule.activeEndsAt ~= 0 then schedule.activeStartAt else schedule.nextStartAt
	local endsAt = if schedule.activeEndsAt ~= 0
		then schedule.activeEndsAt
		else schedule.nextStartAt + EventConfig.METEOR_DURATION
	ReplicatedStorage:SetAttribute(EventConfig.ATTRIBUTE_METEOR_STARTS_AT, if announced then startsAt else 0)
	ReplicatedStorage:SetAttribute(EventConfig.ATTRIBUTE_METEOR_ENDS_AT, if announced then endsAt else 0)
end

-- Pluie de météorites en cours ? (utilisé par la formule de la chance, via BoostService)
function MeteorService.isActive(): boolean
	return schedule ~= nil and schedule:isActive(Workspace:GetServerTimeNow())
end

-- Commande de test, Studio seulement : une pluie commence dans WARNING_SECONDS (annonce comprise).
function MeteorService.startSoon()
	if not RunService:IsStudio() then
		warn("[MeteorService] startSoon est réservé à Studio")
		return
	end
	schedule:forceNext(Workspace:GetServerTimeNow() + EventConfig.WARNING_SECONDS)
end

function MeteorService.init()
	warningRemote = Remotes.get(Remotes.Names.WorldEventWarning)
	schedule = Schedule.new(Workspace:GetServerTimeNow())
	publish()
end

function MeteorService.start()
	RunService.Heartbeat:Connect(function()
		local events = schedule:step(Workspace:GetServerTimeNow())
		if #events == 0 then
			return
		end
		for _, event in events do
			if event == "warning" then
				warningRemote:FireAllClients("meteor", schedule.announcedStartAt)
				print("[MeteorService] Pluie de météorites annoncée")
			elseif event == "start" then
				print(string.format("[MeteorService] Pluie de météorites (%d s)", EventConfig.METEOR_DURATION))
			else
				print("[MeteorService] Fin de la pluie de météorites")
			end
		end
		publish()
	end)
end

return MeteorService
