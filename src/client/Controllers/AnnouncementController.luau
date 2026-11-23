--!strict
-- Annonces à tout le serveur (plan semaine 5, section 3), dans un seul style : Légendaire (doré), Secret
-- (arc-en-ciel) et Événement chance (orange). Un son distinct, une annonce après l'autre.
-- Le serveur envoie des identifiants ; chaque client compose le texte dans sa langue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local UiConfig = require(Shared.Config.UiConfig)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local HudLayout = require(script.Parent.Parent.HudLayout)
local RevealGate = require(script.Parent.Parent.RevealGate)

type Kind = "Legendary" | "Secret" | "event"
type Announcement = { text: string, kind: Kind }

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 50)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 70)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 230, 110)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(70, 150, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
})
local WHITE = Color3.new(1, 1, 1)
local MAX_QUEUE = 5 -- au-delà, les plus anciennes sont abandonnées (serveur très actif)

local player = Players.LocalPlayer

local AnnouncementController = {}

local banner: Frame
local label: TextLabel
local gradient: UIGradient
local sound: Sound
local queue: { Announcement } = {}
local showing = false

local function buildUi()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AnnouncementGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Parent = player:WaitForChild("PlayerGui")

	banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.BackgroundColor3 = UiConfig.ANNOUNCE_LEGENDARY_COLOR
	banner.Visible = false
	banner.Parent = gui
	-- Sous les bandeaux du HUD, dans la même colonne (hors liste des joueurs et flèche).
	HudLayout.observe(function(layout: HudLayout.Layout)
		local width = layout.bannerRight - layout.bannerLeft
		banner.Position = UDim2.fromOffset((layout.bannerLeft + layout.bannerRight) / 2, layout.announceTop)
		banner.Size = UDim2.fromOffset(math.min(UiConfig.ANNOUNCE_SIZE.X, width), layout.announceHeight)
	end)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = banner
	local stroke = Instance.new("UIStroke")
	stroke.Color = WHITE
	stroke.Thickness = 2
	stroke.Parent = banner

	gradient = Instance.new("UIGradient")
	gradient.Color = RAINBOW
	gradient.Enabled = false
	gradient.Parent = banner

	label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.TextStrokeTransparency = 0.2
	label.Parent = banner
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.15, 0)
	padding.PaddingBottom = UDim.new(0.15, 0)
	padding.PaddingLeft = UDim.new(0.03, 0)
	padding.PaddingRight = UDim.new(0.03, 0)
	padding.Parent = label
end

local function colorFor(kind: Kind): Color3
	if kind == "Secret" then
		return UiConfig.ANNOUNCE_SECRET_COLOR
	elseif kind == "event" then
		return UiConfig.ANNOUNCE_EVENT_COLOR
	end
	return UiConfig.ANNOUNCE_LEGENDARY_COLOR
end

local function display(announcement: Announcement)
	-- Une révélation Légendaire ou Secret passe devant l'annonce : on attend qu'elle soit terminée.
	RevealGate.waitUntilFree()
	label.Text = announcement.text
	banner.BackgroundColor3 = colorFor(announcement.kind)
	gradient.Enabled = announcement.kind == "Secret"
	banner.BackgroundTransparency = 0.05
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.2
	banner.Visible = true
	sound:Play()
	-- Si une révélation commence pendant l'annonce, celle-ci se met en pause (masquée), puis reprend
	-- pour le temps qui lui restait.
	local remaining = UiConfig.ANNOUNCE_TIME
	while remaining > 0 do
		if RevealGate.isBusy() then
			banner.Visible = false
			RevealGate.waitUntilFree()
			banner.Visible = true
		end
		remaining -= task.wait()
	end
	local fade = TweenInfo.new(UiConfig.ANNOUNCE_FADE_TIME)
	TweenService:Create(banner, fade, { BackgroundTransparency = 1 }):Play()
	local textFade = TweenService:Create(label, fade, { TextTransparency = 1, TextStrokeTransparency = 1 })
	textFade:Play()
	textFade.Completed:Wait()
	banner.Visible = false
end

local function pump()
	if showing then
		return
	end
	showing = true
	task.spawn(function()
		while #queue > 0 do
			display(table.remove(queue, 1) :: Announcement)
		end
		showing = false
	end)
end

local function announce(text: string, kind: Kind)
	table.insert(queue, { text = text, kind = kind })
	while #queue > MAX_QUEUE do
		table.remove(queue, 1)
	end
	pump()
end

function AnnouncementController.init()
	buildUi()
	sound = Instance.new("Sound")
	sound.Name = "Announcement"
	sound.SoundId = UiConfig.SOUND_ANNOUNCE
	sound.Volume = UiConfig.VOLUME_ANNOUNCE
	sound.PlaybackSpeed = UiConfig.PITCH_ANNOUNCE
	sound.Parent = SoundService
end

function AnnouncementController.start()
	Remotes.get(Remotes.Names.ItemAnnounced).OnClientEvent
		:Connect(function(_finderUserId: unknown, finderName: unknown, itemId: unknown, rarity: unknown)
			if typeof(finderName) ~= "string" or typeof(itemId) ~= "string" or Items.byId[itemId] == nil then
				return
			end
			if rarity ~= "Legendary" and rarity ~= "Secret" then
				return
			end
			-- Chez le joueur qui a trouvé l'objet, sa carte arrive juste avant : l'annonce l'attend (RevealGate).
			announce(Locale.t("announce." .. rarity, finderName, Locale.item(itemId)), rarity :: Kind)
		end)
	-- Événement chance (semaine 4), harmonisé avec les annonces de trouvailles.
	Remotes.get(Remotes.Names.LuckEventStarted).OnClientEvent:Connect(function(buyerName: unknown)
		if typeof(buyerName) == "string" then
			announce(Locale.t("hud.luckEvent", buyerName), "event")
		end
	end)
	-- Dégradé arc-en-ciel qui défile, seulement pendant une annonce Secret.
	RunService.RenderStepped:Connect(function(deltaTime: number)
		if banner.Visible and gradient.Enabled then
			gradient.Rotation = (gradient.Rotation + deltaTime * UiConfig.RAINBOW_SPIN_SPEED / 4) % 360
		end
	end)
end

return AnnouncementController
