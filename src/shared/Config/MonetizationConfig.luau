--!strict
-- Game passes, developer products et paramètres de leurs effets (plan semaine 4, sections 3 et 4).
-- Identifiants réels du Creator Hub (branchés le 2026-11-20). Un produit remis à 0 est simulé dans Studio
-- (même traitement que les vrais reçus) ; en ligne, il est simplement indisponible.
-- Noms et descriptions en français (langue source) ; l'anglais est dans src/shared/Locale/en.luau.

export type PassKey = "BiggerChest" | "LuckX2" | "AutoDig" | "VIP" | "Bodyguard"
export type ProductKey =
	"LuckPotion"
	| "Shield"
	| "CoinPouch"
	| "CoinBag"
	| "CoinChest"
	| "CoinVault"
	| "ServerLuckEvent"
	| "Revenge"

export type PassDef = {
	key: PassKey,
	id: number,
	price: number,
	name: string,
	description: string,
	isLuck: boolean, -- masqué si les objets aléatoires payants sont restreints dans le pays du joueur
}

export type ProductDef = {
	key: ProductKey,
	id: number,
	price: number,
	name: string,
	description: string,
	isLuck: boolean,
	coins: number?, -- packs de Pièces
}

local passes: { PassDef } = {
	{
		key = "BiggerChest",
		id = 2096676808,
		price = 149,
		name = "Coffre agrandi",
		description = "Double la taille de ton coffre : 60 places au lieu de 30.",
		isLuck = false,
	},
	{
		key = "LuckX2",
		id = 2091838874,
		price = 299,
		name = "Chance x2",
		description = "Double pour toujours tes chances de déterrer des objets Rares, Épiques, Légendaires et Secrets.",
		isLuck = true,
	},
	{
		key = "AutoDig",
		id = 2092438864,
		price = 449,
		name = "Creusage auto",
		description = "Ta pelle creuse toute seule ta parcelle. Active-le ou coupe-le quand tu veux.",
		isLuck = false,
	},
	{
		key = "VIP",
		id = 2092612906,
		price = 399,
		name = "VIP",
		description = "+10 % de Pièces sur toutes tes ventes et une étiquette VIP dorée.",
		isLuck = false,
	},
	{
		key = "Bodyguard",
		id = 2094190831,
		price = 349,
		name = "Garde du corps",
		description = "Un garde protège ton coffre : les voleurs mettent 8 secondes à le crocheter au lieu de 5.",
		isLuck = false,
	},
}

local products: { ProductDef } = {
	{
		key = "LuckPotion",
		id = 3733963259,
		price = 39,
		name = "Potion de chance",
		description = "Chances x3 pendant 10 minutes. Le temps s'ajoute si une potion est déjà active.",
		isLuck = true,
	},
	{
		key = "Shield",
		id = 3733963471,
		price = 49,
		name = "Bouclier anti-vol",
		description = "Personne ne peut crocheter ton coffre pendant une nuit entière.",
		isLuck = false,
	},
	{
		key = "CoinPouch",
		id = 3733963581,
		price = 99,
		name = "Bourse de Pièces",
		description = "5 000 Pièces, ajoutées tout de suite.",
		isLuck = false,
		coins = 5000,
	},
	{
		key = "CoinBag",
		id = 3733963810,
		price = 249,
		name = "Sac de Pièces",
		description = "15 000 Pièces, ajoutées tout de suite.",
		isLuck = false,
		coins = 15000,
	},
	{
		key = "CoinChest",
		id = 3733963957,
		price = 499,
		name = "Coffret de Pièces",
		description = "35 000 Pièces, ajoutées tout de suite. De quoi t'offrir la Pelle en acier.",
		isLuck = false,
		coins = 35000,
	},
	{
		key = "CoinVault",
		id = 3733964120,
		price = 999,
		name = "Trésor de Pièces",
		description = "80 000 Pièces, ajoutées tout de suite. Le meilleur rapport Pièces par Robux.",
		isLuck = false,
		coins = 80000,
	},
	{
		key = "ServerLuckEvent",
		id = 3733964347,
		price = 249,
		name = "Événement chance",
		description = "Chances x2 pour tout le serveur pendant 5 minutes, avec ton nom affiché chez chaque joueur.",
		isLuck = true,
	},
	{
		key = "Revenge",
		id = 3733964544,
		price = 29,
		name = "Revanche",
		description = "La nuit : téléporte-toi devant le coffre de ton dernier voleur. Les règles du vol s'appliquent.",
		isLuck = false,
	},
}

local passByKey: { [string]: PassDef } = {}
local productByKey: { [string]: ProductDef } = {}
local productKeyById: { [number]: ProductKey } = {}
local passKeyById: { [number]: PassKey } = {}
for _, pass in passes do
	passByKey[pass.key] = table.freeze(pass)
	if pass.id ~= 0 then
		passKeyById[pass.id] = pass.key
	end
end
for _, product in products do
	productByKey[product.key] = table.freeze(product)
	if product.id ~= 0 then
		productKeyById[product.id] = product.key
	end
end

local MonetizationConfig = {
	passes = table.freeze(passes),
	products = table.freeze(products),
	passByKey = table.freeze(passByKey),
	productByKey = table.freeze(productByKey),
	productKeyById = table.freeze(productKeyById),
	passKeyById = table.freeze(passKeyById),

	-- Effets des game passes
	BIGGER_CHEST_LIMIT = 60, -- places du coffre avec Coffre agrandi
	LUCK_PASS_MULTIPLIER = 2,
	AUTO_DIG_INTERVAL = 0.8, -- secondes entre deux coups automatiques (le creusage à la main reste à 0,2 s)
	VIP_SELL_BONUS = 0.10, -- +10 % de Pièces à la vente
	VIP_TAG_COLOR = Color3.fromRGB(255, 200, 40),
	VIP_TAG_COLOR_HEX = "#FFC828", -- même couleur, pour la balise du chat
	VIP_TAG_SIZE = Vector2.new(90, 34), -- pixels
	VIP_TAG_HEIGHT = 2.6, -- studs au-dessus de la tête
	VIP_TAG_MAX_DISTANCE = 80, -- studs
	BODYGUARD_PICK_DURATION = 8, -- secondes de crochetage au lieu de 5

	-- Effets des developer products
	POTION_MULTIPLIER = 3,
	POTION_DURATION = 10 * 60, -- secondes, s'additionnent
	SERVER_EVENT_MULTIPLIER = 2,
	SERVER_EVENT_DURATION = 5 * 60, -- secondes

	-- Formule unique de la chance (section 4)
	GROUP_ID = 0, -- groupe Konbit Games ; 0 = bonus désactivé
	GROUP_MULTIPLIER = 1.05,
	LUCK_CAP = 10, -- protège la valeur des Secrets

	-- Traitement des achats
	PROCESSED_PURCHASES_KEPT = 100, -- derniers PurchaseId gardés dans le profil (idempotence)
	PASS_CHECK_RETRIES = 3, -- essais de UserOwnsGamePassAsync au chargement
	PASS_CHECK_RETRY_DELAY = 2, -- secondes entre deux essais
	PURCHASE_REQUEST_COOLDOWN = 1, -- secondes minimum entre deux demandes d'achat d'un joueur
	ANALYTICS_PURCHASE_EVENT = "purchase",
	ANALYTICS_TRANSACTION_TYPE = "IAP", -- Enum.AnalyticsEconomyTransactionType.IAP.Name
}

return table.freeze(MonetizationConfig)
