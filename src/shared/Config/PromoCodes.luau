--!strict
-- Codes promo (plan semaine 5, section 10). Chaque code donne sa récompense une seule fois par joueur
-- (liste redeemedCodes du profil). Les codes s'écrivent ici en MAJUSCULES ; la saisie du joueur est
-- comparée sans tenir compte des majuscules ni des espaces autour.
-- expiresAt : facultatif, fin de validité en temps UTC (utiliser utc(année, mois, jour) : le code reste
-- valable jusqu'à la fin de ce jour). Récompense : même forme que les récompenses de RetentionConfig.

export type Reward = { coins: number?, luckPotion: number?, shield: number? }
export type CodeDef = { code: string, reward: Reward, expiresAt: number? }

-- Fin du jour donné, en secondes UTC (inclus).
local function utc(year: number, month: number, day: number): number
	return DateTime.fromUniversalTime(year, month, day, 23, 59, 59).UnixTimestamp
end

local list: { CodeDef } = {
	{ code = "CREUSE", reward = { luckPotion = 1 } },
	{ code = "TRESOR", reward = { coins = 2000 } },
	{ code = "DISCORD", reward = { shield = 1 } },
}

local byCode: { [string]: CodeDef } = {}
for _, def in list do
	assert(def.code == string.upper(def.code), "Code à écrire en majuscules : " .. def.code)
	assert(byCode[def.code] == nil, "Code en double : " .. def.code)
	byCode[def.code] = def
end

return table.freeze({
	list = list,
	byCode = byCode,
	utc = utc,
	MAX_LENGTH = 20, -- caractères saisis au plus
	COOLDOWN = 2, -- secondes entre deux essais (anti-spam)
})
