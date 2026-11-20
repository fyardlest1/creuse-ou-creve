# Plan technique : semaine 2 (économie)

**Objectif de la semaine :** la boucle moyenne du GDD fonctionne de bout en bout. Le joueur creuse, range ses objets dans son coffre, les vend au Marchand contre des Pièces, achète une meilleure pelle à la Forge, et descend vers l'Argile puis la Roche, où il trouve de nouveaux objets qui valent plus cher.

**Prérequis :** la semaine 1 est bouclée, y compris la correction "inventaire plein = creusage refusé sans perdre d'objet" et les deux tests restants de la section 8.

## 1. Ce qui est dans la semaine 2, et ce qui n'y est pas

**Inclus :**

- Pièces : monnaie sauvegardée, affichée dans le HUD et le classement du serveur.
- Couches de terrain 1 à 3 (Terre, Argile, Roche), avec leurs objets propres.
- Coffre physique sur chaque parcelle, et son interface.
- Objets favoris (protégés de la vente).
- Marchand : vente à l'unité ou de tout le coffre.
- Forge : pelles en bois, fer et acier.
- Événements d'économie pour l'analytique.
- Un test d'équilibrage automatique.

**Exclu (semaines suivantes) :** vol, cycle jour et nuit, game passes, developer products, quêtes, récompenses quotidiennes, Index de collection, pelle en diamant et couches 4 et 5.

## 2. Décisions de design

| Sujet | Décision |
|---|---|
| Inventaire et coffre | **C'est la même chose.** L'inventaire de la semaine 1 devient le coffre : 30 places, que le game pass "Coffre agrandi" doublera plus tard. C'est ce coffre que les voleurs viseront en semaine 3. |
| Où on vend | Uniquement au Marchand, au centre de la carte. Ça force un aller-retour, qui crée de la circulation entre les parcelles (utile pour le vol plus tard). |
| Vente rapide | Bouton "Tout vendre" qui vend tout **sauf les favoris**, plus vente à l'unité dans la liste. |
| Favoris | Une étoile sur chaque objet du coffre. Un favori ne peut pas être vendu par erreur. Les objets Légendaires et Secrets sont mis en favori automatiquement à la découverte. |
| Pelles | Achat dans l'ordre (bois, puis fer, puis acier). La pelle achetée s'équipe automatiquement. Une pelle achetée l'est pour toujours. |
| Profondeur et couches | La profondeur augmente de 10 m à chaque parcelle entièrement creusée (comme en semaine 1). La **couche de terrain se déduit de la profondeur** : Terre de 0 à 10 m, Argile de 10 à 50 m, Roche de 50 à 200 m. Au-delà de 200 m, on reste en Roche jusqu'aux mises à jour suivantes. |
| Pelle requise | Pour entrer dans une nouvelle couche, il faut la pelle minimum du GDD (fer pour l'Argile, acier pour la Roche). Sans elle, la parcelle se régénère dans la couche actuelle, la profondeur ne bouge pas, et le jeu affiche "Il te faut la Pelle en fer pour creuser l'Argile". C'est l'objectif d'achat le plus clair qu'on puisse donner au joueur. |
| Valeur des objets | Valeur de rareté x multiplicateur de mutation x **multiplicateur de couche** (Terre x1, Argile x2, Roche x4). Creuser plus profond doit rapporter plus. |
| Message "Inventaire plein" | Devient "Coffre plein : vends tes objets au Marchand", avec une flèche qui pointe vers le Marchand. |

## 3. Données de configuration

**Pelles (`Shovels.luau`) :**

| Pelle | Prix | Coups par case | Bonus de chance | Couche max |
|---|---|---|---|---|
| Bois | Gratuite | 3 | 0 % | Terre |
| Fer | 500 | 2 | +5 % | Argile |
| Acier | 25 000 (ajusté, voir section 7) | 2 | +15 % | Roche |

**Couches (`Strata.luau`, nouveau fichier) :** `id`, nom français, profondeur min et max, pelle requise, multiplicateur de valeur, couleur des cases (Terre brun clair, Argile orange brique, Roche gris).

**Objets (`Items.luau`) :** ajouter environ 12 objets pour l'Argile (thème fossiles et jouets perdus) et 12 pour la Roche (cristaux et trésors de pirates), avec au moins 2 objets par rareté dans chaque couche. Noms français drôles, dans l'esprit de la couche 1. Supprimer le repli de la semaine 1 qui réutilisait les objets de la couche 1.

## 4. Données du joueur (migration vers la version 2)

Nouveau schéma :

```
{
  version = 2,
  coins = 0,
  inventory = { ItemInstance },     -- ItemInstance gagne le champ favorite: boolean
  depth = 0,
  ownedShovels = { "Wood" },
  equippedShovel = "Wood",
  stats = { totalDigs, foundByRarity, totalCoinsEarned = 0, itemsSold = 0 },
}
```

- Le champ `layer` disparaît : la couche se calcule toujours depuis `depth`, pour ne jamais avoir deux valeurs contradictoires.
- Écrire une fonction de migration v1 vers v2 dans `PlayerDataService`, appliquée au chargement. Les objets existants reçoivent `favorite = false` et une valeur recalculée avec le multiplicateur de couche 1.
- Ne jamais supprimer un objet pendant une migration.

## 5. Contrat réseau (ajouts)

| RemoteEvent | Sens | Contenu | Validation serveur |
|---|---|---|---|
| `InventoryUpdated` | Serveur vers client | liste complète des objets du coffre | |
| `SellRequest` | Client vers serveur | `{ uids: { string } }` ou `{ all: true }` | Joueur à moins de 15 studs du Marchand, chaque uid existe dans son coffre, favoris refusés à l'unité comme en "Tout vendre", cadence de 0,5 s minimum |
| `SellResult` | Serveur vers client | `count`, `coinsEarned`, `newBalance` | |
| `ToggleFavorite` | Client vers serveur | `uid: string` | L'uid appartient au joueur, cadence de 0,1 s |
| `BuyShovel` | Client vers serveur | `shovelId: string` | Joueur à moins de 15 studs de la Forge, pelle existante, pas déjà possédée, pelle précédente possédée, Pièces suffisantes |
| `ShovelChanged` | Serveur vers client | `shovelId` | |
| `StratumBlocked` | Serveur vers client | `requiredShovel` | |

Les Pièces, la profondeur, la couche et la pelle équipée sont aussi écrites en attributs sur le joueur (comme en semaine 1) pour que le HUD ait l'état de départ.

**Règle de sécurité pour la vente :** retirer les objets du coffre et créditer les Pièces dans la même opération, sans `yield` entre les deux. Un objet ne doit jamais pouvoir être vendu deux fois.

## 6. Modules

**Nouveaux fichiers :**

```
src/shared/Config/Strata.luau
src/shared/Config/EconomyConfig.luau     -- distances, cadences, multiplicateurs
src/server/Services/EconomyService.luau  -- Pièces, vente, analytique
src/server/Services/ShopService.luau     -- Forge et pelles
src/server/Services/WorldService.luau    -- génère le Marchand, la Forge et les coffres
src/server/Tests/EconomySimulation.luau  -- test d'équilibrage
src/client/Controllers/ChestController.luau
src/client/Controllers/MerchantController.luau
src/client/Controllers/ForgeController.luau
```

**WorldService :** génère au centre de la carte, entre les deux rangées de parcelles, un stand Marchand et un stand Forge (formes simples et panneau lisible), chacun avec un `ProximityPrompt`. Génère aussi un coffre au bord de chaque parcelle, avec un `ProximityPrompt` "Ouvrir le coffre". Les `ProximityPrompt` sont la bonne interaction sur mobile.

**EconomyService :** `getCoins`, `addCoins(player, amount, reason)`, `trySpend(player, amount, reason): boolean`, la vente, et les classements du serveur (`leaderstats` : Pièces et Profondeur). Chaque gain ou dépense passe par `AnalyticsService:LogEconomyEvent`, avec une source (vente) ou une destination (pelle). Ce sont ces données qui permettront plus tard de mesurer l'économie réelle.

**ShopService :** achat et équipement des pelles. Après un achat, `DigService` doit utiliser immédiatement le nouveau nombre de coups et le nouveau bonus de chance.

**DigService (modifications) :** coups par case et bonus de chance lus depuis la pelle équipée. Au passage de couche : vérifier la pelle requise, sinon régénérer la parcelle dans la couche actuelle et envoyer `StratumBlocked`. Couleur des cases selon la couche.

**LootService (modifications) :** tirer l'objet dans la couche actuelle, appliquer le multiplicateur de couche, et mettre en favori automatiquement les Légendaires et Secrets.

**ChestController :** grille de cartes (couleur de rareté, badge de mutation, valeur, étoile de favori), triée par valeur décroissante, compteur `18/30`. Ouverte par le `ProximityPrompt` du coffre et par un bouton du HUD.

**MerchantController :** au `ProximityPrompt`, ouvre le coffre en mode vente : bouton "Tout vendre (X Pièces)" bien visible, plus "Vendre" sur chaque carte. Après une vente, animation de Pièces et son de caisse.

**ForgeController :** liste des 3 pelles avec prix, coups par case, bonus de chance et couche accessible. État : Possédée, Équipée, Acheter (grisé si pas assez de Pièces, avec le montant manquant), Bloquée (pelle précédente requise).

**HudController (modifications) :** Pièces en haut à droite, nom de la couche à côté de la profondeur, bouton Coffre, messages "Coffre plein" et "Il te faut la Pelle en ...".

## 7. Test d'équilibrage (`EconomySimulation.luau`)

Lancé à la main en Studio, il simule un joueur qui creuse au rythme de **2 secondes par objet**, plus **20 secondes** par aller-retour au Marchand quand le coffre est plein, et qui achète chaque pelle dès qu'il peut. Il affiche :

- Pièces gagnées par minute en Terre, en Argile et en Roche.
- Temps pour acheter la Pelle en fer, puis la Pelle en acier.
- Temps pour atteindre 50 m (entrée en Roche).

Moyenne sur 1 000 simulations. **Cibles :** Pelle en fer avant 3 minutes de jeu, Pelle en acier entre 8 et 15 minutes, entrée en Roche avant 30 minutes. Si les résultats sortent des cibles, ajuster les prix et les multiplicateurs dans la config (pas les probabilités de rareté du GDD) et noter les nouvelles valeurs dans ce fichier.

La simulation tourne en deux variantes. **A (référence)** : le joueur n'utilise que "Tout vendre", les favoris automatiques (Légendaires et Secrets) restent dans le coffre. **B** : le joueur vend tout, favoris compris.

### Résultats et ajustement (semaine 2)

**Premier passage, valeurs du plan** (Fer 500, Acier 5 000, multiplicateurs Terre x1, Argile x2, Roche x4) :

| | A | B |
|---|---|---|
| Pièces/min Terre / Argile / Roche | 1 380 / 2 868 / 5 155 | 2 726 / 5 848 / 11 274 |
| Pelle en fer (moyenne) | 1 min 20 s | 1 min 20 s |
| Pelle en acier (moyenne) | 4 min 10 s | 3 min 23 s |
| Entrée en Roche (moyenne) | 14 min 15 s | 14 min 00 s |

L'acier arrivait 2 à 3 fois trop tôt. Le temps de la Pelle en fer ne dépend pas de son prix (premier coffre plein : 30 x 2 s + 20 s = 80 s) et l'entrée en Roche ne dépend que du creusage (5 parcelles).

**Décision : Pelle en acier à 25 000 Pièces.** Rien d'autre ne change (Fer 500, multiplicateurs inchangés).

**Second passage, Acier à 25 000** (1 000 simulations de 60 min par variante) :

| | A (référence) | B |
|---|---|---|
| Pièces/min Terre / Argile / Roche | 1 378 / 2 756 / 5 164 | 2 676 / 5 690 / 11 251 |
| Pelle en fer (moyenne) | 1 min 20 s | 1 min 20 s |
| Pelle en acier : moyenne | **11 min 39 s** | **7 min 57 s** |
| Pelle en acier : médiane / 10 % / 90 % | 11 min 42 s / 9 min 20 s / 13 min 44 s | 8 min 00 s / 5 min 20 s / 10 min 40 s |
| Pelle en acier : au plus tôt | 6 min 22 s | 1 min 20 s |
| Parties avec l'acier avant 5 min | 0 / 1 000 | 84 / 1 000 |
| Entrée en Roche (moyenne) | **14 min 22 s** | 14 min 00 s |

Critères d'acceptation :

- [x] A : acier en moyenne entre 8 et 15 min (11 min 39 s).
- [x] A : entrée en Roche sous 30 min (14 min 22 s).
- [x] B : acier pas avant 5 min **en moyenne** (7 min 57 s). C'est la lecture retenue pour ce critère.

**Décision sur les parties précoces de B (8,4 % achètent l'acier avant 5 min) : on ne touche à rien.** Ce sont des joueurs qui ont trouvé un Secret dans leurs premières minutes (25 000 Pièces en Terre, 50 000 en Argile) et qui ont choisi de le vendre plutôt que de le garder. C'est le jackpot, le moment qu'on veut voir filmé et partagé : le pilier 2 du GDD, « le frisson de la trouvaille ».

## 8. Ordre des tâches pour Claude Code

1. Config : `Strata.luau`, `EconomyConfig.luau`, mise à jour de `Shovels.luau` et `Items.luau` (objets des couches 2 et 3).
2. Migration v1 vers v2 dans `PlayerDataService`. Test : le profil de test (6 objets) charge en v2 sans perte.
3. `EconomyService` avec `leaderstats` et analytique.
4. `WorldService` : Marchand, Forge, coffres.
5. Vente (`SellRequest`) et `MerchantController`. Test : vente à l'unité, "Tout vendre" qui épargne les favoris, double vente impossible.
6. Favoris et `ChestController`.
7. `ShopService` et `ForgeController`. Test : achat refusé sans assez de Pièces, achat dans l'ordre, nouvelle pelle effective tout de suite.
8. `DigService` et `LootService` : pelle équipée, couches, blocage sans la bonne pelle, couleurs.
9. `EconomySimulation`, puis ajustement de la config si besoin.
10. HUD, test en émulation téléphone, test à 2 joueurs, StyLua, commit et push.

## 9. Critères de réussite de la semaine

- [ ] Un nouveau joueur achète la Pelle en fer en moins de 3 minutes sans aide.
- [ ] Aucun objet perdu : ni à la vente, ni à la migration, ni quand le coffre est plein.
- [ ] "Tout vendre" ne vend jamais un favori.
- [ ] Un client modifié ne peut pas vendre deux fois le même objet, vendre loin du Marchand, acheter une pelle sans Pièces ou sauter une pelle.
- [ ] Sans Pelle en fer, impossible d'entrer dans l'Argile, et le message l'explique.
- [ ] Les objets de l'Argile et de la Roche apparaissent dans leur couche, avec la bonne valeur.
- [ ] Les Pièces, la pelle et la profondeur survivent à une déconnexion.
- [ ] La simulation d'équilibrage respecte les cibles de la section 7.
- [ ] Tout fonctionne en émulation téléphone et à 2 joueurs, sans erreur rouge.

## 10. Message à donner à Claude Code

> Lis `CLAUDE.md` puis `docs/plan-semaine-2.md`. Implémente la semaine 2 en suivant l'ordre des tâches de la section 8, une tâche à la fois. Après chaque tâche, lance un playtest dans Studio par MCP, lis l'Output, corrige les erreurs, puis fais un commit Git. Pour la tâche 9, donne-moi les résultats bruts de la simulation avant d'ajuster quoi que ce soit. Arrête-toi et demande-moi avant toute décision qui contredit le plan.

## 11. Ajout en cours de semaine : la pelle visible

Oubli du plan initial : aucune pelle n'était visible dans la main du personnage. Or le pilier 4 du GDD, « filmable », repose sur cette image : un joueur qui creuse sans pelle visible ne donne pas envie d'être filmé.

| Sujet | Décision |
|---|---|
| Modèle | Une pelle construite en Parts simples (manche et lame), soudée à la main droite (`RightHand`, ou `Right Arm` en R6). Créée par le serveur (`ShovelVisualService`), donc visible par tous les joueurs. |
| Pas de Tool | On n'utilise pas de Tool Roblox : sur mobile, il ajoute une barre d'inventaire inutile, et le joueur pourrait ranger sa pelle par erreur. Le Backpack est désactivé côté client (`StarterGui:SetCoreGuiEnabled`). |
| Apparence par pelle | Dans `Shovels.luau` (`appearance`) : bois (manche et lame brun clair), fer (lame gris foncé), acier (lame argentée qui brille légèrement). La pelle change tout de suite dans la main à l'achat, et revient après une réapparition. |
| Geste de creusage | Animation procédurale côté client : à chaque coup, l'épaule droite lève la pelle puis frappe (réglages dans `UiConfig.luau`, `SWING_*`). La terre, la secousse et le son partent à l'impact de la lame. Le serveur envoie `DigSwing` à tous les clients à chaque coup validé, pour que les autres joueurs voient le geste. |
| Semaine 5 (polish) | On remplacera la pelle en Parts par un vrai modèle 3D, et le geste par une animation faite dans l'éditeur d'animation. |

Note technique : les avatars utilisent les nouvelles articulations (`AnimationConstraint`, pas `Motor6D`). Le geste s'applique donc en ajoutant une rotation au `Transform` de l'épaule à chaque image, après l'Animator (`RunService.PreSimulation`). Cela fonctionne avec les deux types d'articulation et se combine aux animations de marche.

## 12. Ajout en cours de semaine : la prise en main du creusage

| Sujet | Décision |
|---|---|
| Surbrillance | La case visée est mise en surbrillance (`SelectionBox` locale, visible seulement par le joueur), uniquement sur sa propre parcelle et pour les cases encore intactes. Elle ne s'affiche que pour une case à portée de creusage, pour qu'un clic sur une case en surbrillance creuse toujours. Sur PC, elle suit la souris ; sur mobile, elle suit le doigt pendant l'appui. |
| Appui maintenu | Maintenir le bouton de la souris ou le doigt sur une case enchaîne les coups au rythme de la cadence serveur (0,2 s), plus une petite marge (`DIG_HOLD_MARGIN`, 0,03 s) pour que la gigue réseau ne fasse pas refuser un coup sur deux. Si le curseur passe sur une autre case pendant l'appui, on continue sur la nouvelle case. Coffre plein : un seul essai par appui, pour ne pas répéter le bandeau. |
| Indice de premier lancement | « Clique sur une case pour creuser » sur PC, « Touche une case pour creuser » sur mobile, avec une main animée qui pointe une case intacte près du centre de la parcelle (le bord avant est caché par le panneau de la parcelle). Il disparaît après les 3 premiers objets trouvés (`PlayerConfig.DIG_HINT_ITEM_COUNT`) et ne revient plus : champ `digHintDone` du profil. Les profils existants qui ont déjà trouvé 3 objets ou plus sont marqués au chargement. |

Note technique : la main de l'indice est dessinée dans l'interface 2D et replacée à chaque image au-dessus de la case (projection à l'écran), car les `BillboardGui` avec `AlwaysOnTop` ne s'affichaient pas dans la place.
