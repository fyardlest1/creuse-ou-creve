--!strict
-- Ambiance du cycle jour et nuit : éclairage (transition de 10 s), minuteur "Nuit dans 1:20" /
-- "Jour dans 0:45" (rouge la nuit), bandeau à la tombée de la nuit, cloche au changement de phase.
-- La phase vient des attributs de ReplicatedStorage : le minuteur se calcule sans Remote.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DayNightConfig = require(Shared.Config.DayNightConfig)
local UiConfig = require(Shared.Config.UiConfig)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local HudController = require(script.Parent.HudController)
local HudLayout = require(script.Parent.Parent.HudLayout)

local DAY_TIMER_BACKGROUND = Color3.fromRGB(28, 26, 34)
local NIGHT_TIMER_BACKGROUND = Color3.fromRGB(170, 40, 40)
local WHITE = Color3.new(1, 1, 1)

local player = Players.LocalPlayer

local DayNightController = {}

local timerPill: Frame
local timerLabel: TextLabel
local bell: Sound
local nightAmbience: Sound?
local lightingTween: Tween? = nil
local clockTween: Tween? = nil
-- L'heure est animée sur cette valeur (qui peut dépasser 24), puis recopiée modulo 24 :
-- Lighting.ClockTime ne reboucle pas une valeur interpolée au-delà de 24.
local clockDriver: NumberValue

local function getPhase(): string
	local phase = ReplicatedStorage:GetAttribute(DayNightConfig.ATTRIBUTE_PHASE)
	return if phase == "Night" then "Night" else "Day"
end

local function getEndsAt(): number
	local endsAt = ReplicatedStorage:GetAttribute(DayNightConfig.ATTRIBUTE_PHASE_ENDS_AT)
	return if typeof(endsAt) == "number" then endsAt else Workspace:GetServerTimeNow()
end

-- Éclairage de la phase, en transition douce (ou tout de suite à l'arrivée du joueur).
local function applyLighting(phase: string, instant: boolean)
	local target = table.clone(if phase == "Night" then DayNightConfig.NIGHT_LIGHTING else DayNightConfig.DAY_LIGHTING)
	local clock = target.ClockTime :: number
	target.ClockTime = nil
	if lightingTween ~= nil then
		lightingTween:Cancel()
	end
	if clockTween ~= nil then
		clockTween:Cancel()
	end
	if instant then
		for property, value in target do
			(Lighting :: any)[property] = value
		end
		clockDriver.Value = clock
		return
	end
	local info = TweenInfo.new(DayNightConfig.TRANSITION_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	lightingTween = TweenService:Create(Lighting, info, target)
	lightingTween:Play()
	-- L'heure avance toujours (pas de coucher de soleil à l'envers) : pour revenir au jour, on passe minuit.
	local current = clockDriver.Value % 24
	clockDriver.Value = current
	local goal = if clock < current then clock + 24 else clock
	clockTween = TweenService:Create(clockDriver, info, { Value = goal })
	clockTween:Play()
end

local function buildTimer()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DayNightGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5

	-- Première pastille du haut, à gauche (HudLayout).
	timerPill = Instance.new("Frame")
	timerPill.Name = "Timer"
	timerPill.BackgroundColor3 = DAY_TIMER_BACKGROUND
	timerPill.BackgroundTransparency = 0.15
	timerPill.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = timerPill

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.15, 0)
	padding.PaddingBottom = UDim.new(0.15, 0)
	padding.PaddingLeft = UDim.new(0.08, 0)
	padding.PaddingRight = UDim.new(0.08, 0)
	padding.Parent = timerPill

	timerLabel = Instance.new("TextLabel")
	timerLabel.Size = UDim2.fromScale(1, 1)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Font = Enum.Font.FredokaOne
	timerLabel.TextScaled = true
	timerLabel.TextColor3 = WHITE
	timerLabel.Parent = timerPill

	HudLayout.observe(function(layout: HudLayout.Layout)
		HudLayout.place(timerPill, layout.pills.timer)
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function updateTimer()
	local remaining = math.max(0, math.ceil(getEndsAt() - Workspace:GetServerTimeNow()))
	local night = getPhase() == "Night"
	timerLabel.Text =
		Locale.t(if night then "daynight.untilDay" else "daynight.untilNight", remaining // 60, remaining % 60)
	timerPill.BackgroundColor3 = if night then NIGHT_TIMER_BACKGROUND else DAY_TIMER_BACKGROUND
end

local function onPhaseChanged(phase: unknown)
	local current = if phase == "Night" then "Night" else "Day"
	applyLighting(current, false)
	bell:Play()
	if current == "Night" then
		HudController.showBanner(Locale.t("daynight.nightfall"), "alert", true)
	else
		HudController.showBanner(Locale.t("daynight.daybreak"), "info")
	end
	local ambience = nightAmbience
	if ambience ~= nil then
		if current == "Night" then
			ambience:Play()
		else
			ambience:Stop()
		end
	end
end

function DayNightController.init()
	buildTimer()
	clockDriver = Instance.new("NumberValue")
	clockDriver.Name = "ClockDriver"
	clockDriver.Value = Lighting.ClockTime
	clockDriver.Changed:Connect(function(value: number)
		Lighting.ClockTime = value % 24
	end)
	bell = Instance.new("Sound")
	bell.Name = "PhaseBell"
	bell.SoundId = DayNightConfig.SOUND_PHASE_BELL
	bell.Volume = DayNightConfig.VOLUME_PHASE_BELL
	bell.PlaybackSpeed = DayNightConfig.PITCH_PHASE_BELL
	bell.Parent = SoundService

	-- Ambiance nocturne discrète : seulement si un son est configuré.
	if DayNightConfig.SOUND_NIGHT_AMBIENCE ~= "" then
		local ambience = Instance.new("Sound")
		ambience.Name = "NightAmbience"
		ambience.SoundId = DayNightConfig.SOUND_NIGHT_AMBIENCE
		ambience.Volume = DayNightConfig.VOLUME_NIGHT_AMBIENCE
		ambience.Looped = true
		ambience.Parent = SoundService
		nightAmbience = ambience
	end
end

function DayNightController.start()
	applyLighting(getPhase(), true)
	if getPhase() == "Night" and nightAmbience ~= nil then
		(nightAmbience :: Sound):Play()
	end
	Remotes.get(Remotes.Names.PhaseChanged).OnClientEvent:Connect(onPhaseChanged)
	RunService.RenderStepped:Connect(updateTimer)
end

return DayNightController
