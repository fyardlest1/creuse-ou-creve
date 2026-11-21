--!strict
-- Réglages de test (plan semaine 3, section 10) : protection débutant à 0 et jour à 1 minute,
-- pour tester le vol à plusieurs dans Studio sans attendre.
--
-- Pour l'activer : mettre ENABLED à true, tester, puis le remettre à false.
-- Sécurité : les valeurs de test ne s'appliquent que si RunService:IsStudio() est vrai.
-- Sur un serveur en ligne, IsStudio() est faux : ce mode est ignoré même si ENABLED reste à true.

local RunService = game:GetService("RunService")

local ENABLED = false

local StudioTestMode = {
	-- Vrai seulement dans Studio, avec ENABLED à true.
	ACTIVE = ENABLED and RunService:IsStudio(),

	-- Valeurs remplacées quand le mode est actif.
	DAY_DURATION = 60, -- secondes (au lieu de 8 minutes)
	PROTECTION_SECONDS = 0, -- au lieu de 20 minutes

	-- Langue forcée dans Studio ("fr" ou "en"), indépendante du mode ci-dessus ; nil = langue du compte.
	-- Ignorée en ligne (Locale vérifie RunService:IsStudio()).
	FORCED_LANGUAGE = nil :: string?,
}

return table.freeze(StudioTestMode)
