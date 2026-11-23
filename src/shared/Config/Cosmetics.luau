--!strict
-- Cosmétiques de voleur (plan semaine 5, section 9) : 3 masques et 2 sacs à dos, achetés en Points de
-- Voleur, jamais en Robux. Purement visuels, portés seulement la nuit, aucun avantage de jeu.
-- Les noms affichés sont dans Locale (clés "cosmetic.<id>").
--
-- Chaque cosmétique est fait de Parts soudées à une pièce du personnage (la tête pour un masque, le
-- torse pour un sac). Tailles et décalages sont des multiples de la taille de cette pièce : le
-- cosmétique suit la taille de l'avatar. L'avant du personnage est -Z, le dos +Z.

export type Slot = "mask" | "bag"

export type PartSpec = {
	name: string,
	size: Vector3, -- multiple de la taille de la pièce d'ancrage (Ball : seul X compte)
	offset: Vector3, -- multiple de la taille de la pièce d'ancrage, depuis son centre
	rotation: Vector3?, -- degrés
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?,
	reflectance: number?,
}

export type CosmeticDef = {
	id: string,
	slot: Slot,
	price: number, -- Points de Voleur
	color: Color3, -- couleur de la vignette dans la boutique
	parts: { PartSpec },
}

local BLACK = Color3.fromRGB(20, 20, 24)
local GOLD = Color3.fromRGB(230, 180, 50)

local list: { CosmeticDef } = {
	{
		-- Bandeau noir sur les yeux : le cambrioleur de dessin animé.
		id = "burglar_mask",
		slot = "mask",
		price = 3,
		color = Color3.fromRGB(40, 40, 48),
		parts = {
			{
				name = "Band",
				size = Vector3.new(1.08, 0.24, 1.08),
				offset = Vector3.new(0, 0.1, 0),
				color = BLACK,
				material = Enum.Material.Fabric,
			},
		},
	},
	{
		-- Cagoule sombre, fente noire et deux yeux qui brillent dans la nuit.
		id = "shadow_hood",
		slot = "mask",
		price = 5,
		color = Color3.fromRGB(55, 55, 70),
		parts = {
			{
				name = "Hood",
				size = Vector3.new(1.1, 1.1, 1.1),
				offset = Vector3.new(0, 0.02, 0),
				color = Color3.fromRGB(45, 45, 55),
				material = Enum.Material.Fabric,
			},
			{
				name = "Slit",
				size = Vector3.new(0.75, 0.18, 0.04),
				offset = Vector3.new(0, 0.1, -0.56),
				color = BLACK,
				material = Enum.Material.SmoothPlastic,
			},
			{
				name = "EyeLeft",
				size = Vector3.new(0.14, 0.08, 0.03),
				offset = Vector3.new(-0.18, 0.1, -0.58),
				color = Color3.fromRGB(235, 240, 255),
				material = Enum.Material.Neon,
			},
			{
				name = "EyeRight",
				size = Vector3.new(0.14, 0.08, 0.03),
				offset = Vector3.new(0.18, 0.1, -0.58),
				color = Color3.fromRGB(235, 240, 255),
				material = Enum.Material.Neon,
			},
		},
	},
	{
		-- Demi-masque doré de carnaval, deux plumes violettes sur le côté.
		id = "venetian_mask",
		slot = "mask",
		price = 10,
		color = GOLD,
		parts = {
			{
				name = "Plate",
				size = Vector3.new(0.95, 0.34, 0.08),
				offset = Vector3.new(0, 0.12, -0.53),
				color = GOLD,
				material = Enum.Material.Metal,
				reflectance = 0.2,
			},
			{
				name = "EyeLeft",
				size = Vector3.new(0.2, 0.12, 0.03),
				offset = Vector3.new(-0.2, 0.12, -0.58),
				color = BLACK,
				material = Enum.Material.SmoothPlastic,
			},
			{
				name = "EyeRight",
				size = Vector3.new(0.2, 0.12, 0.03),
				offset = Vector3.new(0.2, 0.12, -0.58),
				color = BLACK,
				material = Enum.Material.SmoothPlastic,
			},
			{
				name = "Feather",
				size = Vector3.new(0.08, 0.6, 0.05),
				offset = Vector3.new(0.42, 0.42, -0.5),
				rotation = Vector3.new(0, 0, -20),
				color = Color3.fromRGB(130, 60, 170),
				material = Enum.Material.Fabric,
			},
			{
				name = "Feather2",
				size = Vector3.new(0.08, 0.5, 0.05),
				offset = Vector3.new(0.52, 0.34, -0.48),
				rotation = Vector3.new(0, 0, -38),
				color = Color3.fromRGB(90, 40, 140),
				material = Enum.Material.Fabric,
			},
		},
	},
	{
		-- Gros sac de toile noué, porté dans le dos.
		id = "loot_sack",
		slot = "bag",
		price = 4,
		color = Color3.fromRGB(170, 130, 80),
		parts = {
			{
				name = "Sack",
				size = Vector3.new(0.75, 0.75, 0.75),
				offset = Vector3.new(0, -0.05, 1.15),
				color = Color3.fromRGB(170, 130, 80),
				material = Enum.Material.Fabric,
				shape = Enum.PartType.Ball,
			},
			{
				name = "Knot",
				size = Vector3.new(0.18, 0.2, 0.25),
				offset = Vector3.new(0, 0.42, 1.1),
				color = Color3.fromRGB(120, 85, 50),
				material = Enum.Material.Fabric,
			},
		},
	},
	{
		-- Sacoche de cuir à rabat, deux crochets qui dépassent.
		id = "lockpick_satchel",
		slot = "bag",
		price = 8,
		color = Color3.fromRGB(95, 60, 40),
		parts = {
			{
				name = "Body",
				size = Vector3.new(0.7, 0.8, 0.45),
				offset = Vector3.new(0, -0.02, 0.72),
				color = Color3.fromRGB(95, 60, 40),
				material = Enum.Material.Leather,
			},
			{
				name = "Flap",
				size = Vector3.new(0.72, 0.28, 0.48),
				offset = Vector3.new(0, 0.28, 0.74),
				color = Color3.fromRGB(70, 42, 28),
				material = Enum.Material.Leather,
			},
			{
				name = "Buckle",
				size = Vector3.new(0.12, 0.1, 0.05),
				offset = Vector3.new(0, 0.18, 0.98),
				color = GOLD,
				material = Enum.Material.Metal,
			},
			{
				name = "PickLeft",
				size = Vector3.new(0.04, 0.3, 0.04),
				offset = Vector3.new(-0.2, 0.5, 0.72),
				color = Color3.fromRGB(200, 200, 210),
				material = Enum.Material.Metal,
			},
			{
				name = "PickRight",
				size = Vector3.new(0.04, 0.24, 0.04),
				offset = Vector3.new(0.2, 0.47, 0.72),
				rotation = Vector3.new(0, 0, 12),
				color = Color3.fromRGB(200, 200, 210),
				material = Enum.Material.Metal,
			},
		},
	},
}

local byId: { [string]: CosmeticDef } = {}
for _, def in list do
	assert(byId[def.id] == nil, "Cosmétique en double : " .. def.id)
	assert(def.price > 0 and def.price % 1 == 0, "Prix invalide : " .. def.id)
	byId[def.id] = def
end

return table.freeze({
	list = list,
	byId = byId,
	SLOTS = table.freeze({ "mask", "bag" }) :: { Slot },
	-- Pièce du personnage qui porte chaque emplacement (R15, puis R6).
	ANCHORS = table.freeze({
		mask = { "Head" },
		bag = { "UpperTorso", "Torso" },
	}) :: { [Slot]: { string } },
	MODEL_NAME = "ThiefCosmetics", -- modèle rangé dans le personnage
	ID_MAX_LENGTH = 40,
	ACTION_COOLDOWN = 0.3, -- secondes entre deux achats ou changements
	SHOP_MAX_DISTANCE = 15, -- studs entre le joueur et le Repaire des Voleurs (achat)
})
