--!strict
-- Mini-jeu de crochetage, côté voleur (plan semaine 5, section 6). Le serveur l'ouvre (LockpickStarted)
-- quand le voleur touche « Crocheter ». Toucher l'écran (ou cliquer, ou Espace) quand le curseur est
-- dans la zone verte, 3 fois de suite ; un échec fait recommencer la série. Espace est réservé au
-- mini-jeu tant qu'il est ouvert (le personnage ne saute pas).
-- Le client n'envoie qu'une intention, « réussi » ou « abandon » : le serveur vérifie la durée réelle,
-- la distance et toutes les règles du vol. Il ferme le mini-jeu par StealSucceeded ou StealCancelled.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StealConfig = require(Shared.Config.StealConfig)
local UiConfig = require(Shared.Config.UiConfig)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local Lockpick = require(Shared.Lockpick)
local UiKit = require(script.Parent.Parent.UiKit)

local BAR_COLOR = Color3.fromRGB(60, 58, 72)
local ZONE_COLOR = Color3.fromRGB(70, 200, 90)
local CURSOR_COLOR = Color3.new(1, 1, 1)
local MISS_COLOR = Color3.fromRGB(220, 60, 60)
local PIP_OFF_COLOR = Color3.fromRGB(80, 78, 92)
local PIP_ON_COLOR = Color3.fromRGB(70, 200, 90)
local KEY_ACTION = "LockpickTap"

local player = Players.LocalPlayer

local LockpickController = {}

type Session = {
	settings: Lockpick.Settings,
	startedAt: number,
	zoneCenter: number,
	streak: number,
	done: boolean, -- série réussie : on attend la durée minimale, puis la réponse du serveur
}

local gui: ScreenGui
local panel: Frame
local titleLabel: TextLabel
local hintLabel: TextLabel
local bar: Frame
local zone: Frame
local cursor: Frame
local pips: { Frame } = {}
local hitSound: Sound
local missSound: Sound
local resultRemote: RemoteEvent
local session: Session? = nil
local rng = Random.new()

local function compactScreen(): boolean
	local camera = Workspace.CurrentCamera
	return camera ~= nil and camera.ViewportSize.Y < UiConfig.COMPACT_SCREEN_HEIGHT
end

local function placeZone(current: Session)
	zone.Position = UDim2.fromScale(current.zoneCenter, 0.5)
	zone.Size = UDim2.fromScale(current.settings.zoneWidth, 1)
end

local function refreshPips(current: Session)
	for index, pip in pips do
		pip.Visible = index <= current.settings.hitsRequired
		pip.BackgroundColor3 = if index <= current.streak then PIP_ON_COLOR else PIP_OFF_COLOR
	end
end

local function flashBar(color: Color3)
	bar.BackgroundColor3 = color
	TweenService:Create(bar, TweenInfo.new(UiConfig.LOCKPICK_FEEDBACK_TIME), { BackgroundColor3 = BAR_COLOR }):Play()
end

local function close()
	session = nil
	gui.Enabled = false
	ContextActionService:UnbindAction(KEY_ACTION)
end

-- Série réussie : le client attend la durée minimale (le serveur mesure toujours au moins autant),
-- puis envoie « réussi ». Le serveur ferme le mini-jeu en répondant.
local function finish(current: Session)
	current.done = true
	hintLabel.Text = Locale.t("lockpick.unlocking")
	local waitFor = Lockpick.sendDelay(current.settings) - (os.clock() - current.startedAt)
	task.delay(math.max(0, waitFor), function()
		if session == current then
			resultRemote:FireServer("success")
		end
	end)
end

local function onTap()
	local current = session
	if current == nil or current.done then
		return
	end
	local elapsed = os.clock() - current.startedAt
	local position = Lockpick.cursorAt(elapsed, current.settings.travelTime)
	if Lockpick.isInZone(position, current.zoneCenter, current.settings.zoneWidth) then
		current.streak += 1
		hitSound:Play()
		flashBar(ZONE_COLOR)
		refreshPips(current)
		if current.streak >= current.settings.hitsRequired then
			finish(current)
			return
		end
		current.zoneCenter = Lockpick.newZoneCenter(rng, current.settings.zoneWidth)
		placeZone(current)
		hintLabel.Text = Locale.t("lockpick.hint", current.settings.hitsRequired)
	else
		current.streak = 0
		missSound:Play()
		flashBar(MISS_COLOR)
		refreshPips(current)
		hintLabel.Text = Locale.t("lockpick.miss")
	end
end

local function onKey(_: string, state: Enum.UserInputState, _: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		onTap()
	end
	return Enum.ContextActionResult.Sink
end

local function open(settings: Lockpick.Settings, victimName: string)
	local current: Session = {
		settings = settings,
		startedAt = os.clock(),
		zoneCenter = Lockpick.newZoneCenter(rng, settings.zoneWidth),
		streak = 0,
		done = false,
	}
	session = current
	local size = if compactScreen() then UiConfig.LOCKPICK_PANEL_SIZE_COMPACT else UiConfig.LOCKPICK_PANEL_SIZE
	panel.Size = UDim2.fromOffset(size.X, size.Y)
	titleLabel.Text = Locale.t("lockpick.title", victimName)
	hintLabel.Text = Locale.t("lockpick.hint", settings.hitsRequired)
	placeZone(current)
	refreshPips(current)
	bar.BackgroundColor3 = BAR_COLOR
	gui.Enabled = true
	ContextActionService:BindActionAtPriority(
		KEY_ACTION,
		onKey,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space
	)
	-- Filet de sécurité : le serveur abandonne de lui-même après PICK_MAX_SECONDS.
	task.delay(StealConfig.PICK_MAX_SECONDS + 1, function()
		if session == current then
			close()
		end
	end)
end

local function buildUi()
	gui = Instance.new("ScreenGui")
	gui.Name = "LockpickGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 11 -- devant le HUD et les fenêtres, derrière les annonces et la révélation
	gui.IgnoreGuiInset = true
	gui.Enabled = false

	-- Tout l'écran est la zone tactile du mini-jeu (bien plus grande que 44 px).
	local tapArea = Instance.new("TextButton")
	tapArea.Name = "TapArea"
	tapArea.Size = UDim2.fromScale(1, 1)
	tapArea.BackgroundColor3 = Color3.new(0, 0, 0)
	tapArea.BackgroundTransparency = UiConfig.LOCKPICK_VEIL_TRANSPARENCY
	tapArea.Text = ""
	tapArea.AutoButtonColor = false
	tapArea.Parent = gui
	tapArea.Activated:Connect(onTap)

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, UiConfig.LOCKPICK_PANEL_Y)
	panel.BackgroundColor3 = UiKit.PANEL_BACKGROUND
	panel.BackgroundTransparency = 0.05
	panel.Active = false -- les touches sur le panneau comptent aussi (passent au TapArea)
	panel.Parent = gui
	UiKit.addCorner(panel, 0.08)
	UiKit.addPadding(panel, UiConfig.LOCKPICK_PADDING, UiConfig.LOCKPICK_PADDING)

	local touch = UiConfig.TOUCH_TARGET_MIN
	local abortButton = UiKit.button("Abort", Locale.t("lockpick.abort"), UiKit.CLOSE_COLOR, panel)
	abortButton.AnchorPoint = Vector2.new(1, 0)
	abortButton.Position = UDim2.fromScale(1, 0)
	abortButton.Size = UDim2.fromOffset(UiConfig.LOCKPICK_ABORT_WIDTH, touch)
	abortButton.Activated:Connect(function()
		if session ~= nil then
			resultRemote:FireServer("abort")
			close() -- sans attendre la réponse du serveur
		end
	end)

	titleLabel = UiKit.label("Title", "", panel)
	titleLabel.Size = UDim2.new(1, -(UiConfig.LOCKPICK_ABORT_WIDTH + UiConfig.LOCKPICK_PADDING), 0, touch)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left

	bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(0, touch + UiConfig.LOCKPICK_PADDING)
	bar.Size = UDim2.new(1, 0, 0, UiConfig.LOCKPICK_BAR_HEIGHT)
	bar.BackgroundColor3 = BAR_COLOR
	bar.ClipsDescendants = true
	bar.Parent = panel
	UiKit.addCorner(bar, 0.3)

	zone = Instance.new("Frame")
	zone.Name = "Zone"
	zone.AnchorPoint = Vector2.new(0.5, 0.5)
	zone.BackgroundColor3 = ZONE_COLOR
	zone.BorderSizePixel = 0
	zone.Parent = bar

	cursor = Instance.new("Frame")
	cursor.Name = "Cursor"
	cursor.AnchorPoint = Vector2.new(0.5, 0.5)
	cursor.Position = UDim2.fromScale(0, 0.5)
	cursor.Size = UDim2.new(0, UiConfig.LOCKPICK_CURSOR_WIDTH, 1, 0)
	cursor.BackgroundColor3 = CURSOR_COLOR
	cursor.BorderSizePixel = 0
	cursor.ZIndex = 2
	cursor.Parent = bar

	-- Pastilles de la série, puis la consigne en bas.
	local pipRow = Instance.new("Frame")
	pipRow.Name = "Streak"
	pipRow.Position = UDim2.fromOffset(0, touch + UiConfig.LOCKPICK_BAR_HEIGHT + 2 * UiConfig.LOCKPICK_PADDING)
	pipRow.Size = UDim2.new(1, 0, 0, UiConfig.LOCKPICK_PIP_SIZE)
	pipRow.BackgroundTransparency = 1
	pipRow.Parent = panel
	local pipLayout = Instance.new("UIListLayout")
	pipLayout.FillDirection = Enum.FillDirection.Horizontal
	pipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pipLayout.Padding = UDim.new(0, UiConfig.LOCKPICK_PADDING)
	pipLayout.Parent = pipRow
	for index = 1, StealConfig.PICK_HITS_REQUIRED do
		local pip = Instance.new("Frame")
		pip.Name = "Pip" .. index
		pip.LayoutOrder = index
		pip.Size = UDim2.fromOffset(UiConfig.LOCKPICK_PIP_SIZE, UiConfig.LOCKPICK_PIP_SIZE)
		pip.BackgroundColor3 = PIP_OFF_COLOR
		pip.Parent = pipRow
		UiKit.addCorner(pip, 0.5)
		table.insert(pips, pip)
	end

	hintLabel = UiKit.label("Hint", "", panel)
	hintLabel.AnchorPoint = Vector2.new(0, 1)
	hintLabel.Position = UDim2.fromScale(0, 1)
	hintLabel.Size = UDim2.new(1, 0, 0, UiConfig.LOCKPICK_HINT_HEIGHT)
	hintLabel.TextColor3 = UiKit.MUTED_TEXT

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function createSound(name: string, soundId: string, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end

-- Mini-jeu ouvert (StealController masque alors le prompt « Crocheter »).
function LockpickController.isOpen(): boolean
	return session ~= nil
end

function LockpickController.init()
	buildUi()
	hitSound = createSound("LockpickHit", UiConfig.SOUND_LOCKPICK_HIT, UiConfig.VOLUME_LOCKPICK)
	missSound = createSound("LockpickMiss", UiConfig.SOUND_LOCKPICK_MISS, UiConfig.VOLUME_LOCKPICK)
end

function LockpickController.start()
	resultRemote = Remotes.get(Remotes.Names.LockpickResult)
	Remotes.get(Remotes.Names.LockpickStarted).OnClientEvent:Connect(function(settings: unknown, victimName: unknown)
		if typeof(settings) ~= "table" or typeof(victimName) ~= "string" then
			return
		end
		local raw = settings :: { [string]: unknown }
		if
			typeof(raw.zoneWidth) ~= "number"
			or typeof(raw.travelTime) ~= "number"
			or typeof(raw.hitsRequired) ~= "number"
			or typeof(raw.minSeconds) ~= "number"
		then
			return
		end
		open(settings :: Lockpick.Settings, victimName)
	end)
	-- Le serveur conclut : vol réussi, ou annulé (abandon, trop loin, éjecté, jour...).
	Remotes.get(Remotes.Names.StealSucceeded).OnClientEvent:Connect(function(_: unknown, _: unknown, thiefName: unknown)
		if thiefName == player.Name then
			close()
		end
	end)
	Remotes.get(Remotes.Names.StealCancelled).OnClientEvent:Connect(function()
		close() -- la victime ne voit jamais le mini-jeu : sans effet chez elle
	end)
	player.CharacterRemoving:Connect(function()
		if session ~= nil then
			resultRemote:FireServer("abort")
			close()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local current = session
		if current == nil then
			return
		end
		local elapsed = os.clock() - current.startedAt
		cursor.Position = UDim2.fromScale(Lockpick.cursorAt(elapsed, current.settings.travelTime), 0.5)
	end)
end

return LockpickController
