--!strict
-- Ambiance du cycle jour et nuit : éclairage (transition de 10 s), minuteur "Nuit dans 1:20" /
-- "Jour dans 0:45" (rouge la nuit), bandeau à la tombée de la nuit, cloche au changement de phase.
-- La phase vient des attributs de ReplicatedStorage : le minuteur se calcule sans Remote.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DayNightConfig = require(Shared.Config.DayNightConfig)
local AudioConfig = require(Shared.Config.AudioConfig)
local AudioKit = require(script.Parent.Parent.AudioKit)
local EventConfig = require(Shared.Config.EventConfig)
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
local bloodBell: Sound
local dayMusic: Sound
local nightMusic: Sound
local lightingTween: Tween? = nil
local clockTween: Tween? = nil
local bloodTint: ColorCorrectionEffect -- teinte rouge pendant une Nuit de sang (blanche sinon)
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
	-- Nuit de sang : ciel rouge sombre, toujours lisible, et légère teinte rouge de l'image.
	local blood = phase == "Night" and ReplicatedStorage:GetAttribute(EventConfig.ATTRIBUTE_BLOOD_NIGHT) == true
	local source = if blood
		then EventConfig.BLOOD_NIGHT_LIGHTING
		elseif phase == "Night" then DayNightConfig.NIGHT_LIGHTING
		else DayNightConfig.DAY_LIGHTING
	local target = table.clone(source)
	local tintGoal = if blood then EventConfig.BLOOD_NIGHT_TINT else Color3.new(1, 1, 1)
	if instant then
		bloodTint.TintColor = tintGoal
	else
		TweenService:Create(bloodTint, TweenInfo.new(DayNightConfig.TRANSITION_TIME), { TintColor = tintGoal }):Play()
	end
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

-- Dernier affichage du minuteur : le texte n'est refait que quand la seconde ou la phase change.
local shownRemaining = -1
local shownNight: boolean? = nil

local function updateTimer()
	local remaining = math.max(0, math.ceil(getEndsAt() - Workspace:GetServerTimeNow()))
	local night = getPhase() == "Night"
	if remaining == shownRemaining and night == shownNight then
		return
	end
	shownRemaining, shownNight = remaining, night
	timerLabel.Text =
		Locale.t(if night then "daynight.untilDay" else "daynight.untilNight", remaining // 60, remaining % 60)
	timerPill.BackgroundColor3 = if night then NIGHT_TIMER_BACKGROUND else DAY_TIMER_BACKGROUND
end

-- Musique de fond : celle de la phase, en fondu (ou tout de suite à l'arrivée du joueur).
local function playMusic(phase: string, instant: boolean)
	local playing = if phase == "Night" then nightMusic else dayMusic
	local stopping = if phase == "Night" then dayMusic else nightMusic
	local info = TweenInfo.new(if instant then 0 else AudioConfig.MUSIC_FADE_TIME)
	local fadeOut = TweenService:Create(stopping, info, { Volume = 0 })
	fadeOut.Completed:Connect(function()
		if stopping.Volume == 0 then
			stopping:Stop()
		end
	end)
	fadeOut:Play()
	if not playing.IsPlaying then
		playing.Volume = 0
		playing:Play()
	end
	local target = if phase == "Night" then AudioConfig.MUSIC_NIGHT.volume else AudioConfig.MUSIC_DAY.volume
	TweenService:Create(playing, info, { Volume = target }):Play()
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
	playMusic(current, false)
end

function DayNightController.init()
	buildTimer()
	bloodTint = Instance.new("ColorCorrectionEffect")
	bloodTint.Name = "BloodNightTint"
	bloodTint.TintColor = Color3.new(1, 1, 1)
	bloodTint.Parent = Lighting
	clockDriver = Instance.new("NumberValue")
	clockDriver.Name = "ClockDriver"
	clockDriver.Value = Lighting.ClockTime
	clockDriver.Changed:Connect(function(value: number)
		Lighting.ClockTime = value % 24
	end)
	bell = AudioKit.create("PhaseBell", AudioConfig.PHASE_BELL)
	bloodBell = AudioKit.create("BloodNightBell", AudioConfig.BLOOD_NIGHT)
	dayMusic = AudioKit.create("DayMusic", AudioConfig.MUSIC_DAY, "music")
	dayMusic.Looped = true
	nightMusic = AudioKit.create("NightMusic", AudioConfig.MUSIC_NIGHT, "music")
	nightMusic.Looped = true
end

function DayNightController.start()
	applyLighting(getPhase(), true)
	playMusic(getPhase(), true)
	Remotes.get(Remotes.Names.PhaseChanged).OnClientEvent:Connect(onPhaseChanged)
	-- L'attribut de la Nuit de sang peut arriver juste après PhaseChanged : on réapplique.
	ReplicatedStorage:GetAttributeChangedSignal(EventConfig.ATTRIBUTE_BLOOD_NIGHT):Connect(function()
		applyLighting(getPhase(), false)
		if ReplicatedStorage:GetAttribute(EventConfig.ATTRIBUTE_BLOOD_NIGHT) == true then
			bloodBell:Play() -- cloche grave : la Nuit de sang commence
		end
	end)
	RunService.RenderStepped:Connect(updateTimer)
end

return DayNightController
