--!strict
-- Fenêtre Réglages, ouverte par le bouton « Réglages » du HUD : deux grands interrupteurs, un pour la
-- musique et un pour les effets sonores (plan semaine 5, section 8), puis la case « Codes »
-- (section 10, PromoCodeController). Le choix du son est appliqué tout de suite et enregistré par le
-- serveur (AudioKit, SettingsService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiConfig = require(Shared.Config.UiConfig)
local Locale = require(Shared.Locale)
local UiKit = require(script.Parent.Parent.UiKit)
local AudioKit = require(script.Parent.Parent.AudioKit)
local PromoCodeController = require(script.Parent.PromoCodeController)

local SoundSettingsController = {}

type Toggle = { button: TextButton, kind: AudioKit.Kind, onKey: string, offKey: string }

local window: UiKit.Window? = nil
local toggles: { Toggle } = {}

local function refresh()
	for _, toggle in toggles do
		local muted = AudioKit.isMuted(toggle.kind)
		toggle.button.Text = Locale.t(if muted then toggle.offKey else toggle.onKey)
		toggle.button.BackgroundColor3 = if muted then UiKit.DISABLED_COLOR else UiKit.ACTION_COLOR
	end
end

local function build(): UiKit.Window
	local built = UiKit.window(
		"SoundSettingsGui",
		Locale.t("sound.title"),
		UiConfig.SOUND_SETTINGS_SIZE,
		UiConfig.SOUND_SETTINGS_SCALE
	)
	-- Les deux interrupteurs côte à côte : toute la fenêtre tient sans défiler sur un téléphone en paysage.
	local row = Instance.new("Frame")
	row.Name = "SoundRow"
	row.LayoutOrder = 1
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -UiConfig.CHEST_CARD_PADDING, 0, UiConfig.SOUND_SETTINGS_ROW_HEIGHT)
	row.Parent = built.content
	for index, spec in
		{
			{ kind = "music" :: AudioKit.Kind, onKey = "sound.musicOn", offKey = "sound.musicOff" },
			{ kind = "effects" :: AudioKit.Kind, onKey = "sound.effectsOn", offKey = "sound.effectsOff" },
		}
	do
		local button = UiKit.button("Toggle_" .. spec.kind, "", UiKit.ACTION_COLOR, row)
		button.Position = UDim2.new((index - 1) * 0.5, if index == 1 then 0 else 4, 0, 0)
		button.Size = UDim2.new(0.5, -4, 1, 0)
		local toggle: Toggle = { button = button, kind = spec.kind, onKey = spec.onKey, offKey = spec.offKey }
		button.Activated:Connect(function()
			AudioKit.setMuted(toggle.kind, not AudioKit.isMuted(toggle.kind))
			refresh()
		end)
		table.insert(toggles, toggle)
	end
	PromoCodeController.build(built.content, 2)
	return built
end

function SoundSettingsController.toggle()
	if window == nil then
		window = build()
	end
	local current = window :: UiKit.Window
	current.gui.Enabled = not current.gui.Enabled
	if current.gui.Enabled then
		refresh()
	end
end

function SoundSettingsController.init() end

function SoundSettingsController.start()
	-- Réponse du serveur (ou valeur chargée à l'arrivée) : les interrupteurs suivent.
	local player = game:GetService("Players").LocalPlayer
	for _, name in { "MusicMuted", "EffectsMuted" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
end

return SoundSettingsController
