--!strict
-- Règle du niveau d'effets (plan semaine 5, section 12), sans état caché : testable côté serveur.
-- Niveau 1 = effets complets ; plus le niveau est haut, moins il y a d'effets (UiConfig.EFFECTS_LEVELS).
-- On descend d'un niveau après EFFECTS_DOWNGRADE_SAMPLES mesures de suite sous EFFECTS_LOW_FPS, et on
-- remonte d'un niveau après EFFECTS_UPGRADE_SAMPLES mesures de suite au-dessus d'EFFECTS_HIGH_FPS.

local UiConfig = require(script.Parent.Config.UiConfig)

export type State = { level: number, lowStreak: number, highStreak: number }

local EffectsQuality = {}

function EffectsQuality.newState(): State
	return { level = 1, lowStreak = 0, highStreak = 0 }
end

-- Part des effets gardée à ce niveau.
function EffectsQuality.scaleFor(level: number): number
	return UiConfig.EFFECTS_LEVELS[math.clamp(level, 1, #UiConfig.EFFECTS_LEVELS)]
end

-- Applique une mesure d'images par seconde ; met l'état à jour et renvoie le niveau.
function EffectsQuality.step(state: State, fps: number): number
	state.lowStreak = if fps < UiConfig.EFFECTS_LOW_FPS then state.lowStreak + 1 else 0
	state.highStreak = if fps >= UiConfig.EFFECTS_HIGH_FPS then state.highStreak + 1 else 0
	if state.lowStreak >= UiConfig.EFFECTS_DOWNGRADE_SAMPLES then
		state.lowStreak = 0
		state.level = math.min(state.level + 1, #UiConfig.EFFECTS_LEVELS)
	elseif state.highStreak >= UiConfig.EFFECTS_UPGRADE_SAMPLES then
		state.highStreak = 0
		state.level = math.max(state.level - 1, 1)
	end
	return state.level
end

-- Nombre d'éléments à créer pour un effet prévu avec `full` éléments (au moins 1 si full > 0).
function EffectsQuality.count(full: number, scale: number): number
	if full <= 0 then
		return 0
	end
	return math.max(1, math.round(full * scale))
end

return EffectsQuality
