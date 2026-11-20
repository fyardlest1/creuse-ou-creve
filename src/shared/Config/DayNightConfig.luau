--!strict
-- Cycle jour et nuit, commun à tout le serveur : 8 minutes de jour, 2 minutes de nuit.

local StudioTestMode = require(script.Parent.StudioTestMode)

local DayNightConfig = {
	DAY_DURATION = if StudioTestMode.ACTIVE then StudioTestMode.DAY_DURATION else 8 * 60, -- secondes
	NIGHT_DURATION = 2 * 60, -- secondes
	FIRST_PHASE = "Day",

	-- Attributs publiés sur ReplicatedStorage pour les clients
	ATTRIBUTE_PHASE = "Phase", -- "Day" ou "Night"
	ATTRIBUTE_PHASE_ENDS_AT = "PhaseEndsAt", -- workspace:GetServerTimeNow() de fin de phase

	-- Ambiance (Lighting). La nuit doit rester lisible sur un téléphone en plein soleil.
	TRANSITION_TIME = 10, -- secondes
	DAY_LIGHTING = table.freeze({
		ClockTime = 14,
		Brightness = 2,
		Ambient = Color3.fromRGB(140, 140, 140),
		OutdoorAmbient = Color3.fromRGB(128, 128, 128),
	}),
	NIGHT_LIGHTING = table.freeze({
		ClockTime = 0,
		Brightness = 1,
		Ambient = Color3.fromRGB(90, 100, 150), -- sombre et bleuté, jamais noir
		OutdoorAmbient = Color3.fromRGB(80, 95, 150),
	}),

	-- Lanterne près de chaque coffre, allumée la nuit
	LANTERN_POST_SIZE = Vector3.new(0.4, 5, 0.4),
	LANTERN_SIZE = Vector3.new(1, 1.2, 1),
	LANTERN_OFFSET = Vector3.new(3.5, 0, 0), -- depuis le coffre, studs
	LANTERN_COLOR_ON = Color3.fromRGB(255, 200, 110),
	LANTERN_COLOR_OFF = Color3.fromRGB(90, 80, 60),
	LANTERN_LIGHT_RANGE = 16,
	LANTERN_LIGHT_BRIGHTNESS = 2,

	-- Sons (intégrés à Roblox, à remplacer par de vrais assets plus tard)
	SOUND_PHASE_BELL = "rbxasset://sounds/electronicpingshort.wav",
	VOLUME_PHASE_BELL = 0.8,
	PITCH_PHASE_BELL = 0.6,
}

return table.freeze(DayNightConfig)
