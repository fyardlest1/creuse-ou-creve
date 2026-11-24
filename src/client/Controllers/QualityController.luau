--!strict
-- Qualité des effets (plan semaine 5, section 12). Mesure les images par seconde une fois par
-- seconde et choisit un niveau d'effets (règle dans Shared.EffectsQuality) : complet, réduit ou minimal.
-- Les contrôleurs d'effets lisent QualityController.scale() ou count() au moment de créer un effet,
-- et onChanged() pour ajuster les effets permanents (auras de collectionneur).
-- Le niveau et la dernière mesure sont publiés dans les attributs « Level » et « Fps » de ce module ;
-- dans Studio seulement, l'attribut « ForcedLevel » (1, 2 ou 3) fixe le niveau pour les tests.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiConfig = require(Shared.Config.UiConfig)
local EffectsQuality = require(Shared.EffectsQuality)

local LEVEL_ATTRIBUTE = "Level"
local FPS_ATTRIBUTE = "Fps"
local FORCED_ATTRIBUTE = "ForcedLevel"

local QualityController = {}

local state = EffectsQuality.newState()
local level = state.level
local listeners: { (scale: number) -> () } = {}
local frames = 0

local function applyLevel(newLevel: number)
	if newLevel == level then
		return
	end
	level = newLevel
	script:SetAttribute(LEVEL_ATTRIBUTE, level)
	local scale = EffectsQuality.scaleFor(level)
	print(string.format("[QualityController] Effets : niveau %d (%d %%)", level, math.round(scale * 100)))
	for _, listener in listeners do
		task.spawn(listener, scale)
	end
end

-- Part des effets gardée : 1 (complet), puis moins quand les images par seconde baissent.
function QualityController.scale(): number
	return EffectsQuality.scaleFor(level)
end

-- Nombre d'éléments à créer pour un effet prévu avec `full` éléments (au moins 1 si full > 0).
function QualityController.count(full: number): number
	return EffectsQuality.count(full, QualityController.scale())
end

-- Appelé à chaque changement de niveau, avec la nouvelle part des effets.
function QualityController.onChanged(listener: (scale: number) -> ())
	table.insert(listeners, listener)
end

function QualityController.init()
	script:SetAttribute(LEVEL_ATTRIBUTE, level)
end

function QualityController.start()
	-- Seule connexion à chaque image : un compteur des images affichées, rien d'autre.
	RunService.RenderStepped:Connect(function()
		frames += 1
	end)
	task.spawn(function()
		while true do
			frames = 0
			local started = os.clock()
			task.wait(UiConfig.EFFECTS_SAMPLE_TIME)
			local fps = frames / (os.clock() - started)
			script:SetAttribute(FPS_ATTRIBUTE, math.round(fps))
			local forced = script:GetAttribute(FORCED_ATTRIBUTE)
			if RunService:IsStudio() and typeof(forced) == "number" then
				applyLevel(math.clamp(math.round(forced), 1, #UiConfig.EFFECTS_LEVELS))
			else
				state.level = level
				applyLevel(EffectsQuality.step(state, fps))
			end
		end
	end)
end

return QualityController
