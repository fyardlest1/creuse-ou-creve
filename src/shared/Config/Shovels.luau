--!strict
-- Pelles, dans l'ordre d'achat : on ne peut acheter une pelle que si on possède la précédente.
-- Chaque pelle a son apparence en main, pour que la progression se voie.

local Types = require(script.Parent.Parent.Types)

local HANDLE_WOOD = Color3.fromRGB(190, 140, 90) -- brun clair

local list: { Types.ShovelDef } = {
	{
		id = "Wood",
		name = "Pelle en bois",
		price = 0,
		hitsPerCell = 3,
		luckBonus = 0,
		maxStratum = "Dirt",
		appearance = {
			handleColor = HANDLE_WOOD,
			handleMaterial = Enum.Material.Wood,
			bladeColor = Color3.fromRGB(205, 160, 105), -- brun clair
			bladeMaterial = Enum.Material.Wood,
			bladeReflectance = 0,
		},
	},
	{
		id = "Iron",
		name = "Pelle en fer",
		price = 500,
		hitsPerCell = 2,
		luckBonus = 5,
		maxStratum = "Clay",
		appearance = {
			handleColor = HANDLE_WOOD,
			handleMaterial = Enum.Material.Wood,
			bladeColor = Color3.fromRGB(75, 75, 82), -- gris foncé
			bladeMaterial = Enum.Material.Metal,
			bladeReflectance = 0,
		},
	},
	{
		id = "Steel",
		name = "Pelle en acier",
		price = 25000,
		hitsPerCell = 2,
		luckBonus = 15,
		maxStratum = "Rock",
		appearance = {
			handleColor = HANDLE_WOOD,
			handleMaterial = Enum.Material.Wood,
			bladeColor = Color3.fromRGB(140, 150, 163), -- gris acier bleuté, plus clair que le fer
			bladeMaterial = Enum.Material.Metal,
			bladeReflectance = 0.35, -- reflet métallique
		},
	},
}

-- Géométrie commune de la pelle en main (studs). Le manche part de la main vers l'avant.
local MODEL = table.freeze({
	MODEL_NAME = "HeldShovel",
	HANDLE_SIZE = Vector3.new(0.25, 0.25, 4),
	BLADE_SIZE = Vector3.new(1.2, 0.12, 1.4),
	-- Position du centre du manche par rapport à la main : la main tient le tiers arrière.
	GRIP = CFrame.new(0, -0.15, -1.1) * CFrame.Angles(math.rad(-20), 0, 0),
	BLADE_TILT = math.rad(-15), -- la lame plonge un peu vers le sol

	-- Pelles 3D (plan semaine 5, section 5) : modèles importés par Yardley dans
	-- ServerStorage.ShovelModels, nommés MESH_PREFIX .. id ("CoC_Shovel_Wood"), avec deux MeshParts
	-- « Handle » (manche) et « Blade » (lame et ferrures). Le jeu les colore avec `appearance`.
	-- Modèle absent ou refusé : les Parts ci-dessus servent de repli.
	MESH_FOLDER = "ShovelModels",
	MESH_PREFIX = "CoC_Shovel_",
	MESH_LENGTH = 4.5, -- studs, du haut de la poignée en D au bout de la lame
	-- La main tient la barre de la poignée en D : distance (studs) entre le haut du modèle et la main.
	MESH_HAND_FROM_TOP = 0.15,
	-- Prise par rapport à la main (décalage dans la paume, pente vers le sol) ; le modèle est ensuite
	-- avancé pour que la poignée soit dans la main.
	MESH_GRIP = CFrame.new(0, -0.15, 0) * CFrame.Angles(math.rad(-20), 0, 0),
	-- Le modèle importé est debout (lame en bas, -Y) : on le couche vers l'avant (-Z), lame à plat.
	MESH_ROTATION = CFrame.Angles(math.rad(90), 0, 0),
})

local byId: { [string]: Types.ShovelDef } = {}
local orderById: { [string]: number } = {}
for index, shovel in list do
	table.freeze(shovel.appearance)
	byId[shovel.id] = table.freeze(shovel)
	orderById[shovel.id] = index
end

-- Pelle à posséder avant de pouvoir acheter celle-ci (nil pour la première).
local function getPrevious(shovelId: string): Types.ShovelDef?
	local order = orderById[shovelId]
	if order == nil or order <= 1 then
		return nil
	end
	return list[order - 1]
end

return table.freeze({
	DEFAULT_ID = "Wood" :: Types.ShovelId,
	MODEL = MODEL,
	list = table.freeze(list),
	byId = table.freeze(byId),
	orderById = table.freeze(orderById),
	getPrevious = getPrevious,
})
