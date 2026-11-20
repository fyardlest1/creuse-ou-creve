# Plan technique : semaine 4 (monétisation et rétention)

**Objectif de la semaine :** le jeu peut gagner de l'argent et donne des raisons de revenir chaque jour. On branche les game passes et les developer products du GDD, de façon fiable (un achat n'est jamais perdu ni accordé deux fois), et on ajoute les récompenses quotidiennes, les quêtes, l'Index de collection et les badges.

**Prérequis :** la semaine 3 est bouclée (nuit, vol, éjection, garde-fous, mutation Maudite), y compris les 7 tests à 2 joueurs.

## 1. Ce qui est dans la semaine 4, et ce qui n'y est pas

**Inclus :**

- 5 game passes et 5 developer products (section 3).
- Traitement des achats fiable et idempotent.
- Réserve de bonus (potions, boucliers) et effets actifs.
- Boutique dans le jeu, adaptée au mobile.
- Récompenses quotidiennes, 3 quêtes par jour, Index de collection, badges.
- Bonus du groupe Konbit Games.
- Entonnoir d'accueil (onboarding funnel) pour mesurer la rétention.

**Exclu (semaine 5) :** salon VIP physique, cosmétiques de voleur, Nuit de sang, pluie de météorites, vrai mini-jeu de crochetage, modèles et animations finales, codes promo.

## 2. Principes de monétisation (non négociables)

1. **On ne vend jamais un objet directement**, et surtout pas un Secret. On vend du temps, de la chance, de la protection et du statut.
2. **Un achat n'est jamais perdu ni accordé deux fois.** Chaque reçu est traité une seule fois, même si Roblox le renvoie (section 5).
3. **On ne fait jamais payer quelque chose qui ne peut pas s'appliquer.** Les conditions sont vérifiées avant d'afficher l'achat, puis de nouveau à la réception du paiement. Si elles ne sont plus remplies entre-temps, le joueur reçoit une compensation de valeur égale ou supérieure.
4. **Transparence sur la chance.** Les probabilités de rareté, avec et sans bonus, sont affichées dans la boutique et dans l'Index. Les produits de chance sont masqués pour les joueurs dont le pays restreint les objets aléatoires payants (`PolicyService:GetPolicyInfoForPlayerAsync`, champ `ArePaidRandomItemsRestricted`).
5. **Le jeu reste complet sans payer.** Tout ce qui s'achète en Robux s'obtient aussi, plus lentement, en jouant (potions et boucliers via les récompenses quotidiennes et les quêtes), sauf les game passes de confort.

## 3. Catalogue

**Game passes (achat unique) :**

| Pass | Prix (Robux) | Effet exact |
|---|---|---|
| Coffre agrandi | 149 | Coffre de 60 places au lieu de 30. |
| Chance x2 | 299 | Multiplicateur de chance x2 permanent (section 4). |
| Creusage auto | 449 | Bouton dans le HUD pour activer ou couper le creusage automatique : le serveur donne 1 coup toutes les 0,8 s sur une case intacte de ta parcelle, où que tu sois, tant que ton coffre n'est pas plein. Plus lent que le creusage à la main (0,2 s), pour que jouer reste plus rentable. |
| VIP | 399 | +10 % de Pièces à la vente, étiquette VIP dorée au-dessus du personnage et dans le chat (`TextChatService`). Le salon VIP physique viendra en semaine 5. |
| Garde du corps | 349 | Un garde PNJ se tient près de ton coffre. Le crochetage de ton coffre dure 8 s au lieu de 5. |

**Developer products (achats répétables) :**

| Produit | Prix (Robux) | Effet exact |
|---|---|---|
| Potion de chance | 39 | Active tout de suite un multiplicateur x3 pendant 10 min. Si une potion est déjà active, la durée s'additionne. |
| Bouclier anti-vol | 49 | Ton coffre ne peut pas être crocheté pendant la nuit en cours si tu l'achètes la nuit, sinon pendant la prochaine nuit. Les crochetages en cours sont annulés. |
| Pack de Pièces | 99 / 249 / 499 / 999 | 5 000 / 15 000 / 35 000 / 80 000 Pièces (4 produits). |
| Événement chance | 249 | Multiplicateur x2 pour **tout le serveur** pendant 5 min, avec un bandeau "Chance x2 offerte par Yardley !" chez tous les joueurs. Un seul événement actif à la fois : le produit est grisé pendant qu'un autre tourne. |
| Revanche | 29 | Disponible seulement la nuit, si ton dernier voleur est encore dans le serveur et peut être visé. Te téléporte devant son coffre. Les règles normales du vol s'appliquent (protection, déjà pillé, limite de 2 vols). Si les conditions ne sont plus remplies à la réception du paiement, tu reçois une Potion de chance à la place. |

Tous les prix et identifiants vont dans `src/shared/Config/MonetizationConfig.luau`.

## 4. La chance, une seule formule

```
multiplicateur = (1 + bonus de la pelle)
               x (2 si Chance x2)
               x (3 si potion active)
               x (2 si événement serveur actif)
               x (1,05 si membre du groupe Konbit Games)
plafonné à x10
```

Le multiplicateur s'applique aux poids de Rare, Épique, Légendaire et Secret, puis on renormalise, comme en semaine 2. Le **plafond à x10** protège la valeur des Secrets : sans lui, pass + potion + événement + pelle en acier donneraient x13,8. `LootService` est le seul endroit où cette formule existe. Ajouter un test qui vérifie le plafond.

## 5. Traitement des achats (le point le plus important de la semaine)

- **Un seul `MarketplaceService.ProcessReceipt`**, dans un nouveau `PurchaseService`. Une table associe chaque `ProductId` à une fonction qui accorde l'effet.
- **Idempotence :** le profil garde la liste des 100 derniers `PurchaseId` traités. Si le reçu est déjà dans la liste, on renvoie `PurchaseGranted` sans rien accorder de nouveau.
- **Ordre strict :** vérifier que le profil du joueur est chargé (sinon `NotProcessedYet`, et Roblox réessaiera), accorder l'effet, ajouter le `PurchaseId` à la liste, puis renvoyer `PurchaseGranted`. Une erreur pendant l'octroi renvoie `NotProcessedYet`.
- **Game passes :** propriété vérifiée au chargement du profil (`UserOwnsGamePassAsync`, avec réessais et cache), puis mise à jour en direct par `PromptGamePassPurchaseFinished`. Le serveur garde la vérité ; le client ne fait que demander l'affichage de l'achat.
- **Analytique :** chaque achat accordé passe par `AnalyticsService:LogEconomyEvent` (gain de Pièces pour les packs) et par un événement personnalisé "purchase" avec le produit.

## 6. Rétention

**Récompenses quotidiennes :** un calendrier de 7 jours qui avance d'une case à chaque nouveau jour de connexion (jour UTC). **Manquer un jour ne remet pas à zéro** : on reprend où on en était, et le calendrier recommence après le jour 7. Récompenses :

| Jour | Récompense |
|---|---|
| 1 | 300 Pièces |
| 2 | 600 Pièces |
| 3 | 1 Potion de chance |
| 4 | 1 500 Pièces |
| 5 | 3 000 Pièces |
| 6 | 1 Bouclier anti-vol |
| 7 | 1 Potion de chance + 7 500 Pièces |

Les potions et boucliers gagnés ainsi vont dans une **réserve**, et le joueur les active quand il veut depuis le HUD. Ceux achetés en Robux s'activent tout de suite.

**Quêtes :** 3 quêtes par jour UTC, tirées dans une liste (trouver X objets Rares ou mieux, creuser X cases, vendre pour X Pièces, réussir un vol, éjecter un voleur, trouver une mutation, atteindre une nouvelle profondeur). Les objectifs et les récompenses en Pièces s'adaptent à la couche actuelle du joueur. Récompense supplémentaire quand les 3 sont faites : 1 Potion de chance. Les quêtes de vol ne sont jamais tirées pour un joueur encore protégé.

**Index de collection :** une page par couche, une case par objet, avec les mutations trouvées pour chaque objet (objets non trouvés en silhouette, probabilités de rareté affichées). Paliers à 25, 50, 75 et 100 % de chaque couche : Pièces, puis Potion, puis Bouclier, puis un titre affiché sous le nom ("Archéologue de l'Argile").

**Badges Roblox (`BadgeService`) :** Premier coup de pelle, Premier Secret, Premier vol réussi, Première éjection, Entrée dans l'Argile, Entrée dans la Roche, Index de la Terre complet. Les badges apparaissent sur le profil Roblox des joueurs : c'est de la découverte gratuite pour le jeu.

**Groupe Konbit Games :** +5 % de chance (dans la formule de la section 4) pour les membres, vérifié avec `IsInGroupAsync`. Si l'identifiant du groupe vaut 0 dans la config, le bonus est désactivé.

## 7. Entonnoir d'accueil

Avec `AnalyticsService:LogOnboardingFunnelStepEvent`, une seule fois par joueur : 1. Arrivée, 2. Premier coup de pelle, 3. Premier objet, 4. Première vente, 5. Pelle en fer, 6. Première nuit vécue, 7. Entrée dans l'Argile, 8. Premier retour un autre jour. C'est ce qui dira où les joueurs décrochent, et donc ce qu'il faut corriger après le lancement.

## 8. Données du joueur (migration vers la version 4)

Ajouts au schéma :

```
boosts = { luckPotion = 0, shield = 0 },             -- réserve
effects = { luckUntil = 0, shieldNightId = 0 },      -- effets actifs
daily = { lastClaimDay = 0, calendarDay = 0 },
quests = { day = 0, list = {} },                     -- { id, target, progress, claimed }
index = {},                                          -- [itemId] = { mutations trouvées }
indexRewards = {},                                   -- paliers déjà réclamés
title = nil,
funnelSteps = {},
processedPurchases = {},                             -- 100 derniers PurchaseId
```

Migration v3 vers v4 : l'Index est **rempli à partir des objets déjà dans le coffre**, pour que les joueurs existants ne repartent pas de zéro.

## 9. Ce que Yardley doit faire sur le Creator Hub (avant la tâche 3)

1. Page du jeu, **Monetization**, puis **Passes** : créer les 5 game passes avec les prix de la section 3 et une icône provisoire.
2. **Monetization**, puis **Developer Products** : créer les 8 produits (Potion, Bouclier, 4 packs de Pièces, Événement chance, Revanche).
3. **Engagement**, puis **Badges** : créer les 7 badges.
4. Si le groupe Konbit Games existe, noter son identifiant.
5. Copier tous les identifiants dans un message pour Claude Code, qui les mettra dans `MonetizationConfig.luau`.

En attendant les vrais identifiants, Claude Code utilise des identifiants à 0 et un mode de test Studio qui simule les achats.

## 10. Modules

**Nouveaux fichiers :**

```
src/shared/Config/MonetizationConfig.luau
src/shared/Config/RetentionConfig.luau     -- calendrier, quêtes, paliers d'Index, badges, étapes de l'entonnoir
src/server/Services/PurchaseService.luau
src/server/Services/BoostService.luau      -- réserve, effets actifs, événement serveur, multiplicateur de chance
src/server/Services/AutoDigService.luau
src/server/Services/RetentionService.luau  -- quotidien, quêtes, Index, badges, entonnoir
src/server/Tests/PurchaseRules.luau
src/client/Controllers/ShopController.luau
src/client/Controllers/RetentionController.luau
```

**Modifications :** `LootService` (formule unique de la section 4), `PlayerDataService` (coffre de 60 places, migration v4), `EconomyService` (bonus VIP), `StealService` (Bouclier, Garde du corps, Revanche), `HudController` (boutons Boutique, Réserve, Quêtes, Index, indicateurs de bonus actifs avec leur minuteur).

**Boutique :** un bouton dans le HUD ouvre une boutique en deux onglets (Passes, Bonus). Chaque carte affiche l'effet en une phrase, le prix en Robux, et "Possédé" pour un pass déjà acheté. Les produits impossibles à utiliser maintenant sont grisés, avec la raison ("Disponible la nuit", "Un événement est déjà en cours"). Les zones tactiles font au moins 44 px.

## 11. Ordre des tâches pour Claude Code

1. Config : `MonetizationConfig` (identifiants à 0), `RetentionConfig`.
2. Migration v3 vers v4, avec l'Index rempli depuis le coffre.
3. `PurchaseService` et `PurchaseRules.luau` : idempotence, profil non chargé, erreur pendant l'octroi, compensation de la Revanche. Les tests avant tout le reste.
4. `BoostService` et la formule unique de chance, avec le test du plafond.
5. Les 5 game passes, un par un, chacun testé en achat simulé dans Studio.
6. Les developer products, un par un.
7. `ShopController`, test en émulation téléphone.
8. `RetentionService` : quotidien, quêtes, Index, badges, groupe, entonnoir.
9. `RetentionController` et HUD.
10. Branchement des vrais identifiants dès que Yardley les fournit, StyLua, commit et push.

## 12. Critères de réussite de la semaine

- [ ] Un reçu envoyé deux fois n'accorde l'effet qu'une seule fois (test).
- [ ] Un achat fait pendant que le profil charge est accordé dès que le profil est prêt (test).
- [ ] Le multiplicateur de chance ne dépasse jamais x10 (test).
- [ ] Chaque game pass et chaque developer product fonctionne en achat simulé dans Studio.
- [ ] Le Bouclier, le Garde du corps et la Revanche respectent toutes les règles du vol de la semaine 3.
- [ ] Les produits de chance sont masqués quand `ArePaidRandomItemsRestricted` est vrai.
- [ ] Les récompenses quotidiennes, les quêtes et l'Index survivent à une déconnexion, et le jour UTC change correctement.
- [ ] La boutique et l'Index sont utilisables en émulation téléphone.
- [ ] Test à 2 joueurs par Yardley : l'Événement chance s'affiche chez les deux joueurs, et le Bouclier empêche bien le vol.

## 13. Message à donner à Claude Code

> Lis `CLAUDE.md` puis `docs/plan-semaine-4.md`. Implémente la semaine 4 en suivant l'ordre des tâches de la section 11, une tâche à la fois, avec un playtest par MCP et un commit après chaque tâche. Les principes de la section 2 et le traitement des achats de la section 5 sont non négociables : écris `PurchaseRules.luau` avant de brancher le moindre produit. Utilise des identifiants à 0 et des achats simulés dans Studio tant que je ne t'ai pas donné les vrais identifiants. Arrête-toi et demande-moi avant toute décision qui contredit le plan.
