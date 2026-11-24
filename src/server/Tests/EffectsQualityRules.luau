--!strict
-- Tests de la réduction automatique des effets (plan semaine 5, section 12).
-- Lancement dans Studio (côté serveur, pendant un playtest) :
--   require(game.ServerScriptService.Server.Tests.EffectsQualityRules).run()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiConfig = require(Shared.Config.UiConfig)
local EffectsQuality = require(Shared.EffectsQuality)

local EffectsQualityRules = {}

local results: { string } = {}
local passed = 0
local failed = 0

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		table.insert(results, "  OK    " .. name)
	else
		failed += 1
		table.insert(results, "  ÉCHEC " .. name .. (if detail then " (" .. detail .. ")" else ""))
	end
end

local LOW = UiConfig.EFFECTS_LOW_FPS - 5
local MID = (UiConfig.EFFECTS_LOW_FPS + UiConfig.EFFECTS_HIGH_FPS) / 2
local HIGH = UiConfig.EFFECTS_HIGH_FPS + 5
local LAST = #UiConfig.EFFECTS_LEVELS

local function feed(state: EffectsQuality.State, fps: number, count: number): number
	local level = state.level
	for _ = 1, count do
		level = EffectsQuality.step(state, fps)
	end
	return level
end

local function testLevels()
	check("niveau 1 : effets complets", EffectsQuality.scaleFor(1) == 1)
	local decreasing = true
	for index = 2, LAST do
		decreasing = decreasing and UiConfig.EFFECTS_LEVELS[index] < UiConfig.EFFECTS_LEVELS[index - 1]
	end
	check("chaque niveau garde moins d'effets que le précédent", decreasing)
	check("le dernier niveau garde encore des effets", EffectsQuality.scaleFor(LAST) > 0)
	check("seuil bas sous le seuil haut", UiConfig.EFFECTS_LOW_FPS < UiConfig.EFFECTS_HIGH_FPS)
	check("seuil bas au niveau de la cible du plan (30 img/s)", UiConfig.EFFECTS_LOW_FPS >= 30)
end

local function testDowngrade()
	local state = EffectsQuality.newState()
	check("départ au niveau complet", state.level == 1)
	feed(state, LOW, UiConfig.EFFECTS_DOWNGRADE_SAMPLES - 1)
	check("une baisse trop courte ne change rien", state.level == 1)
	feed(state, LOW, 1)
	check("baisse soutenue : un niveau de moins", state.level == 2)
	feed(state, LOW, UiConfig.EFFECTS_DOWNGRADE_SAMPLES * LAST * 2)
	check("jamais plus bas que le dernier niveau", state.level == LAST)

	local spiky = EffectsQuality.newState()
	for _ = 1, 20 do
		EffectsQuality.step(spiky, LOW)
		EffectsQuality.step(spiky, MID)
	end
	check("une image lente sur deux ne fait pas descendre", spiky.level == 1)
end

local function testUpgrade()
	local state = EffectsQuality.newState()
	feed(state, LOW, UiConfig.EFFECTS_DOWNGRADE_SAMPLES)
	feed(state, HIGH, UiConfig.EFFECTS_UPGRADE_SAMPLES - 1)
	check("on ne remonte pas trop vite", state.level == 2)
	feed(state, HIGH, 1)
	check("aisance soutenue : un niveau de plus", state.level == 1)
	feed(state, HIGH, UiConfig.EFFECTS_UPGRADE_SAMPLES * 3)
	check("jamais au-dessus des effets complets", state.level == 1)

	local steady = EffectsQuality.newState()
	feed(steady, LOW, UiConfig.EFFECTS_DOWNGRADE_SAMPLES)
	feed(steady, MID, 50)
	check("entre les deux seuils : le niveau ne bouge pas", steady.level == 2)
	check(
		"remonter demande plus de mesures que descendre",
		UiConfig.EFFECTS_UPGRADE_SAMPLES > UiConfig.EFFECTS_DOWNGRADE_SAMPLES
	)
end

local function testCount()
	check("complet : nombre inchangé", EffectsQuality.count(18, 1) == 18)
	check("réduit : moitié", EffectsQuality.count(18, 0.5) == 9)
	check("au moins 1 élément", EffectsQuality.count(6, 0.01) == 1)
	check("0 prévu : 0", EffectsQuality.count(0, 1) == 0)
	check("météorites à la fois, niveau minimal", EffectsQuality.count(8, EffectsQuality.scaleFor(LAST)) == 2)
end

function EffectsQualityRules.run(): (string, number, number)
	results = {}
	passed = 0
	failed = 0
	testLevels()
	testDowngrade()
	testUpgrade()
	testCount()
	local report =
		string.format("[EffectsQualityRules] %d OK, %d échec(s)\n%s", passed, failed, table.concat(results, "\n"))
	print(report)
	return report, passed, failed
end

return EffectsQualityRules
