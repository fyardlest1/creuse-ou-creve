--!strict
-- Textes d'interface en français (langue source). Mêmes clés que `en.luau`, mêmes marqueurs de formatage
-- (%s, %d...) dans le même ordre : le test LocaleRules le vérifie.
-- Les noms des objets, couches, pelles et produits sont dans les configs (voir Locale/init.luau).

return table.freeze({
	-- Jeu et formats
	["game.title"] = "Creuse ou Crève",
	["game.subtitle"] = "",
	["format.thousands"] = " ",
	["common.coins"] = "%s Pièces",

	-- HUD
	["hud.shop"] = "🛒\nBoutique",
	["hud.chest"] = "🧰\nCoffre",
	["hud.quests"] = "📜\nQuêtes",
	["hud.index"] = "📖\nIndex",
	["hud.reserve"] = "🎒\nRéserve",
	["hud.autoOff"] = "Auto\nOFF",
	["hud.autoOn"] = "Auto\nON",
	["hud.autoPaused"] = "Auto\nen pause",
	["hud.protected"] = "Protégé : %d min",
	["hud.shieldActive"] = "🛡 Actif",
	["hud.shieldReady"] = "🛡 Prêt",
	["hud.depth"] = "Profondeur : %d m",
	["hud.chestCount"] = "Coffre : %d/%d",
	["hud.chestFull"] = "Coffre plein : vends tes objets au Marchand",
	["hud.newStratum"] = "Nouvelle couche : %s ! (%d m)",
	["hud.deeper"] = "Tu descends à %d m",
	["hud.stratumBlocked"] = "Il te faut la %s pour creuser %s",
	["hud.shovelEquipped"] = "%s équipée !",
	["hud.merchantArrow"] = "Marchand",
	["hud.luckEvent"] = "Chance x2 offerte par %s !",
	["hud.revengeCompensated"] = "Ta Revanche n'était plus possible : une Potion de chance t'attend dans ta réserve",

	-- Classement (liste des joueurs)
	["leaderstat.coins"] = "Pièces",
	["leaderstat.depth"] = "Profondeur",

	-- Cycle jour et nuit
	["daynight.untilNight"] = "Nuit dans %d:%02d",
	["daynight.untilDay"] = "Jour dans %d:%02d",
	["daynight.nightfall"] = "La nuit tombe : protège ton coffre !",
	["daynight.daybreak"] = "Le jour se lève",

	-- Indice de premier lancement
	["dighint.pc"] = "Clique sur une case pour creuser",
	["dighint.mobile"] = "Touche une case pour creuser",

	-- Coffre et Marchand
	["chest.title"] = "Coffre",
	["chest.titleSell"] = "Marchand",
	["chest.sellOne"] = "Vendre",
	["chest.sellAll"] = "Tout vendre (%s Pièces)",
	["chest.empty"] = "Ton coffre est vide. Va creuser !",
	["chest.stolenFrom"] = "Volé à %s",

	-- Révélation et annonces à tout le serveur
	["reveal.value"] = "Valeur : %s",
	["announce.Legendary"] = "%s a trouvé un LÉGENDAIRE : %s !",
	["announce.Secret"] = "%s a trouvé un SECRET : %s !",

	-- Forge
	["forge.title"] = "Forge",
	["forge.free"] = "Gratuite",
	["forge.stats"] = "%d coups par case  •  Chance +%d %%  •  Jusqu'à : %s",
	["forge.equipped"] = "Équipée",
	["forge.owned"] = "Possédée",
	["forge.buy"] = "Acheter (%s)",
	["forge.missing"] = "Il manque %s Pièces",
	["forge.locked"] = "Bloquée : %s requise",
	["forge.coins"] = "Tes Pièces : %s",

	-- Boutique
	["shop.title"] = "Boutique",
	["shop.tabPasses"] = "Passes",
	["shop.tabBonus"] = "Bonus",
	["shop.buy"] = "Acheter",
	["shop.owned"] = "Possédé",
	["shop.unavailable"] = "Bientôt disponible",
	["shop.restricted"] = "Indisponible dans ton pays",
	["shop.shieldAlready"] = "Ton coffre est déjà protégé pour cette nuit",
	["shop.eventRunning"] = "Un événement est déjà en cours",
	["shop.revengeDay"] = "Disponible la nuit",
	["shop.revengeNoThief"] = "Personne ne t'a volé",
	["shop.revengeBlocked"] = "Ton voleur ne peut pas être visé",

	-- Probabilités de rareté
	["odds.title"] = "Chances de trouver chaque rareté",
	["odds.header"] = "Sans bonus  •  Avec tes bonus (x%s)",
	["odds.row"] = "%s : %s %%  •  %s %%",

	-- Rétention : Aujourd'hui, Index, Réserve
	["retention.todayTitle"] = "Aujourd'hui",
	["retention.dailySection"] = "Récompense du jour",
	["retention.day"] = "Jour %d",
	["retention.claim"] = "Récupérer",
	["retention.comeBack"] = "Reviens demain !",
	["retention.questsSection"] = "Quêtes du jour",
	["retention.questReward"] = "+%s Pièces",
	["retention.questDone"] = "Réussie !",
	["retention.bonus"] = "Fais les 3 quêtes : +1 Potion de chance",
	["retention.bonusDone"] = "Les 3 quêtes sont faites : Potion de chance gagnée !",
	["retention.indexTitle"] = "Index",
	["retention.indexProgress"] = "%s : %d/%d objets trouvés (%d %%)",
	["retention.tier"] = "%d %% : %s",
	["retention.reserveTitle"] = "Réserve",
	["retention.reserveHint"] = "Les bonus gagnés (calendrier, quêtes, Index) arrivent ici. Active-les quand tu veux.",
	["retention.potionRow"] = "Potion de chance x%d",
	["retention.potionDescription"] = "Chances x%d pendant %d minutes.",
	["retention.shieldRow"] = "Bouclier anti-vol x%d",
	["retention.shieldDescription"] = "Personne ne peut crocheter ton coffre pendant une nuit.",
	["retention.activate"] = "Activer",
	["retention.empty"] = "Vide",
	["retention.shieldPlanned"] = "Déjà prévu",
	["retention.rewardPotion"] = "Potion",
	["retention.rewardShield"] = "Bouclier",
	["retention.rewardTitle"] = "Titre",

	-- Quêtes (%s = objectif)
	["quest.FindRare"] = "Trouve %s objets Rares ou mieux",
	["quest.DigCells"] = "Creuse %s cases",
	["quest.SellCoins"] = "Vends pour %s Pièces",
	["quest.Steal"] = "Réussis %s vol",
	["quest.Eject"] = "Éjecte %s voleur",
	["quest.FindMutation"] = "Trouve %s objet muté",
	["quest.NewDepth"] = "Descends %s fois de 10 m",

	-- Annonces du serveur
	["notice.indexTier"] = "Index de %s : %d %% trouvés !",
	["notice.titleEarned"] = "Nouveau titre : %s",
	["notice.questDone"] = "Quête réussie : %s",
	["notice.allQuests"] = "Les 3 quêtes du jour sont faites : +1 Potion de chance",

	-- Titre affiché sous le nom à 100 % d'une couche (%s = couche avec article)
	["title.index"] = "Archéologue de %s",

	-- Vol
	["steal.alert"] = "Un voleur ouvre ton coffre !",
	["steal.arrowChest"] = "Ton coffre",
	["steal.victimSafe"] = "Le voleur est reparti les mains vides",
	["steal.thiefEjected"] = "Voleur éjecté !",
	["steal.ejectAction"] = "Éjecter",
	["steal.ejected"] = "Éjecté par %s ! Étourdi %d s",
	["steal.thiefCancelled"] = "Crochetage annulé : %s",
	["steal.stolenByMe"] = "Tu as volé :",
	["steal.stolenFromMe"] = "On t'a volé :",
	["steal.stolenFromMeBy"] = "par %s",
	["steal.stolenByMeFrom"] = "à %s",
	["steal.cancel.abort"] = "tu as abandonné",
	["steal.cancel.tooEarly"] = "crochetage trop rapide",
	["steal.cancel.timeout"] = "trop long",
	["steal.cancel.refused"] = "refusé",
	["lockpick.title"] = "Coffre de %s",
	["lockpick.hint"] = "Touche quand le curseur est dans le vert (%d de suite)",
	["lockpick.miss"] = "Raté ! La série recommence",
	["lockpick.unlocking"] = "Déverrouillage…",
	["lockpick.abort"] = "Abandonner",
	["steal.cancel.ejected"] = "tu as été éjecté",
	["steal.cancel.tooFar"] = "tu t'es trop éloigné",
	["steal.cancel.day"] = "le jour se lève",
	["steal.cancel.left"] = "le joueur est parti",
	["steal.cancel.shield"] = "le coffre est protégé par un Bouclier",
	["steal.selfProtected"] = "Tu es protégé (%d min)",
	["steal.victimProtected"] = "Protégé (%d min)",
	["steal.robbed"] = "Déjà pillé cette nuit",
	["steal.thiefLimit"] = "Tu as déjà volé %d fois cette nuit",
	["steal.chestFull"] = "Ton coffre est plein",
	["steal.banned"] = "Tu as été éjecté de ce coffre",
	["steal.nothing"] = "Rien à voler",
	["steal.shielded"] = "Protégé par un Bouclier",

	-- Monde (panneaux et prompts posés par le serveur)
	["world.merchant"] = "💰 Marchand",
	["world.sell"] = "Vendre",
	["world.forge"] = "⚒️ Forge",
	["world.buyShovel"] = "Acheter une pelle",
	["world.chest"] = "Coffre",
	["world.openChest"] = "Ouvrir le coffre",
	["world.pick"] = "Crocheter",
	["world.bodyguard"] = "Garde du corps",
	["plot.free"] = "Parcelle libre",
	["plot.owned"] = "Parcelle de %s",

	-- VIP
	["vip.tag"] = "VIP",

	-- Messages d'expulsion (données)
	["kick.loadFailed"] = "Impossible de charger tes données. Reviens dans un instant !",
	["kick.sessionEnded"] = "Ta partie a été ouverte sur un autre serveur. Reconnecte-toi !",
}) :: { [string]: string }
