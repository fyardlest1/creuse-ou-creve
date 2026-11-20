# Plan technique : semaine 3 (la nuit et le vol)

**Objectif de la semaine :** donner au jeu son identité. Toutes les 10 minutes, la nuit tombe pendant 2 minutes. Les joueurs peuvent alors tenter de crocheter le coffre d'un voisin pour lui voler un objet, pendant que le propriétaire est alerté et peut éjecter le voleur. Le tout doit créer de la tension et de l'envie de revanche, sans jamais devenir assez frustrant pour faire quitter le jeu.

**Prérequis :** la semaine 2 est bouclée, y compris la pelle visible, la prise en main (surbrillance, maintenir pour creuser, indice) et le test téléphone.

## 1. Ce qui est dans la semaine 3, et ce qui n'y est pas

**Inclus :**

- Cycle jour et nuit commun à tout le serveur, avec ambiance et minuteur.
- Vol : crochetage du coffre d'un autre joueur la nuit.
- Alerte du propriétaire et éjection du voleur.
- Garde-fous anti-frustration du GDD.
- Mutation Maudite (nuit seulement), qui attire les voleurs.
- Points de Voleur (comptés, pas encore dépensables).
- Mémorisation du dernier voleur (préparation du produit "Revanche" de la semaine 4).
- Analytique du vol.

**Exclu (semaines suivantes) :** game passes et developer products (dont Bouclier, Revanche, Garde du corps), cosmétiques de voleur, Nuit de sang et pluie de météorites, quêtes, récompenses quotidiennes, Index.

## 2. Décisions de design

| Sujet                             | Décision                                                                                                                                                                                                                                                        |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cycle                             | 10 minutes : **8 min de jour, 2 min de nuit**, identique pour tout le serveur. Durées dans la config.                                                                                                                                                           |
| Le jour                           | On peut marcher partout, y compris sur les parcelles des autres (c'est social), mais aucun coffre ne peut être crocheté.                                                                                                                                        |
| La nuit                           | On peut crocheter le coffre de n'importe quel autre joueur présent dans le serveur. On peut aussi continuer à creuser chez soi, ce qui force un choix : creuser, défendre ou attaquer.                                                                          |
| Crochetage                        | Un `ProximityPrompt` "Crocheter" sur le coffre, à maintenir **5 secondes** (`HoldDuration`). Ça marche pareil au doigt et à la souris. Un vrai mini-jeu de crochetage viendra en semaine 5.                                                                     |
| Si le voleur relâche ou s'éloigne | Le crochetage est annulé, aucun objet n'est volé.                                                                                                                                                                                                               |
| Alerte                            | Dès que le crochetage commence : son d'alarme et bandeau rouge "Un voleur ouvre ton coffre !" chez le propriétaire, avec une flèche vers son coffre. Le coffre clignote en rouge pour tout le monde.                                                            |
| Éjection                          | Le propriétaire voit un `ProximityPrompt` "Éjecter" au-dessus du voleur (visible par lui seul), instantané, à moins de 12 studs. Le voleur est repoussé au centre de la carte, étourdi 3 secondes, et ne peut plus viser ce coffre pendant le reste de la nuit. |
| Butin                             | **Un seul objet**, tiré au hasard dans le coffre de la victime. Les objets **Secrets ne peuvent jamais être volés**. Les favoris, eux, peuvent l'être : ils protègent de la vente, pas du vol. C'est ce qui rend la défense d'un Légendaire excitante.          |
| L'objet volé                      | Il garde son `uid`, et reçoit le champ `stolenFrom` (nom de la victime), affiché sur la carte de l'objet : "Volé à Yardley". C'est un trophée, donc du contenu à filmer.                                                                                        |
| Coffre du voleur plein            | Le prompt "Crocheter" est désactivé, avec le message "Ton coffre est plein".                                                                                                                                                                                    |

## 3. Garde-fous anti-frustration (non négociables)

1. **Une victime perd au maximum 1 objet par nuit.** Après un vol réussi, son coffre est verrouillé jusqu'au lever du jour, et son prompt affiche "Déjà pillé cette nuit".
2. **Un voleur réussit au maximum 2 vols par nuit**, sur deux victimes différentes. Ça évite qu'un seul joueur pille tout le serveur.
3. **Les Secrets ne sont jamais volables.**
4. **Protection débutant : 20 minutes de jeu cumulées.** Un joueur protégé ne peut **ni être volé, ni voler**. La protection est symétrique, pour qu'on ne puisse pas en abuser. Son coffre affiche "Protégé (12 min)", et son HUD lui rappelle le temps restant.
5. **Les joueurs hors ligne ne perdent rien.** C'est déjà vrai : un joueur qui part libère sa parcelle et son coffre disparaît du monde.
6. **Le vol ne peut jamais faire disparaître un objet.** Le transfert retire l'objet de la victime et l'ajoute au voleur dans la même opération, sans `yield`. Si l'ajout échoue, rien n'est retiré.

## 4. Mutation Maudite

- Chance de 1 %, **uniquement pour les objets trouvés la nuit**, multiplicateur x5 (valeurs du GDD, à mettre dans `Mutations.luau`).
- Tant qu'un objet Maudit est dans un coffre, ce coffre dégage une fumée noire visible par tous **la nuit**. C'est une cible évidente pour les voleurs : le joueur doit choisir entre le vendre vite et le défendre.
- Les objets Maudits ne sont pas mis en favori automatiquement.

## 5. Ambiance

- Transition jour vers nuit en 10 secondes (`Lighting.ClockTime`, `Ambient`, `Brightness`). La nuit doit rester **jouable sur un téléphone en plein soleil** : sombre et bleutée, jamais noire.
- Une lanterne près de chaque coffre, qui s'allume la nuit.
- Minuteur dans le HUD : "Nuit dans 1:20" le jour, "Jour dans 0:45" la nuit, en rouge pendant la nuit.
- Bandeau à la tombée de la nuit : "La nuit tombe : protège ton coffre !"
- Sons : une cloche au changement de phase, et une ambiance nocturne discrète.

## 6. Données du joueur (migration vers la version 3)

Ajouts au schéma :

```
playTime = 0,          -- secondes de jeu cumulées, pour la protection débutant
thiefPoints = 0,
stats.stealsSucceeded = 0,
stats.stealsAttempted = 0,
stats.timesRobbed = 0,
stats.ejections = 0,
```

- `ItemInstance` gagne le champ optionnel `stolenFrom: string?`.
- Le dernier voleur de chaque victime est gardé **en mémoire serveur seulement** (`lastThiefUserId`), pas dans le profil : la Revanche n'a de sens que dans le même serveur.
- Migration v2 vers v3 dans `PlayerDataService`. Les joueurs existants partent avec `playTime = 0`, donc protégés 20 minutes : c'est voulu.
- `playTime` est incrémenté par le serveur pendant que le joueur est connecté, et sauvegardé avec le profil.

## 7. Contrat réseau (ajouts)

L'état du cycle est publié en attributs sur `ReplicatedStorage` (`Phase` = "Day" ou "Night", `PhaseEndsAt` = horodatage serveur via `workspace:GetServerTimeNow()`), pour que chaque client calcule son minuteur sans Remote toutes les secondes.

| RemoteEvent      | Sens                                 | Contenu                                             |
| ---------------- | ------------------------------------ | --------------------------------------------------- |
| `PhaseChanged`   | Serveur vers tous                    | `phase`, `endsAt`                                   |
| `StealStarted`   | Serveur vers la victime              | `thiefName`                                         |
| `StealCancelled` | Serveur vers la victime et le voleur | `reason` ("relâché", "éjecté", "trop loin", "jour") |
| `StealSucceeded` | Serveur vers la victime et le voleur | `itemName`, `rarity`, `thiefName`, `victimName`     |
| `EjectRequest`   | Client vers serveur                  | `thiefUserId: number`                               |
| `Ejected`        | Serveur vers le voleur               | `ownerName`, `stunSeconds`                          |

Les événements `PromptButtonHoldBegan`, `PromptButtonHoldEnded` et `Triggered` des `ProximityPrompt` sont écoutés **côté serveur**. Le serveur revalide tout au déclenchement : c'est la nuit, le coffre n'est pas le sien, distance de 10 studs au plus, ni voleur ni victime protégés, victime pas déjà pillée cette nuit, voleur sous sa limite de 2 vols, coffre du voleur pas plein, voleur pas banni de ce coffre pour la nuit, et 5 secondes réellement écoulées depuis le début du maintien (horloge serveur).

`EjectRequest` : seul le propriétaire du coffre en cours de crochetage peut éjecter, à 12 studs au plus du voleur, et seulement pendant un crochetage actif.

## 8. Modules

**Nouveaux fichiers :**

```
src/shared/Config/DayNightConfig.luau
src/shared/Config/StealConfig.luau      -- durée de crochetage, limites, protection, étourdissement, distances
src/server/Services/DayNightService.luau
src/server/Services/StealService.luau
src/server/Services/ProtectionService.luau
src/server/Tests/StealRules.luau        -- tests des règles sans vrais joueurs
src/client/Controllers/DayNightController.luau
src/client/Controllers/StealController.luau
```

**DayNightService :** horloge du serveur, publication des attributs, `isNight()`, signal `onPhaseChanged`. Au lever du jour : annule tous les crochetages en cours et remet à zéro les compteurs de la nuit.

**ProtectionService :** compte `playTime`, expose `isProtected(player)` et `remainingProtection(player)`, publie un attribut `ProtectedUntil` pour le HUD.

**StealService :** toute la logique de vol de la section 7, compteurs par nuit, bannissements de coffre par nuit, transfert atomique, Points de Voleur, `lastThiefUserId`, et événements d'analytique (`AnalyticsService:LogCustomEvent` : tentative, réussite, éjection, annulation).

**WorldService (modifications) :** chaque coffre reçoit un **second** `ProximityPrompt` "Crocheter", distinct du prompt "Ouvrir le coffre" existant. Le client affiche "Ouvrir le coffre" uniquement sur son propre coffre (comportement actuel, inchangé), et "Crocheter" uniquement sur les coffres des autres et seulement la nuit. Cet affichage n'est qu'un confort : le serveur revalide tout (section 7). Le coffre visé est `data.inventory` de la victime, favoris compris (section 2). Ajouter aussi les lanternes, la fumée des objets Maudits et le clignotement rouge.

**LootService (modifications) :** mutation Maudite la nuit seulement.

**DayNightController :** éclairage, minuteur, bandeaux, sons.

**StealController :** alerte de la victime avec flèche, prompt "Éjecter" visible par la victime seule, effets d'étourdissement chez le voleur, carte "Tu as volé : ..." ou "On t'a volé : ...", affichage de "Volé à ..." sur les cartes du coffre.

## 9. Ordre des tâches pour Claude Code

1. Config : `DayNightConfig`, `StealConfig`, mutation Maudite.
2. Migration v2 vers v3. Test : ton profil de test charge sans perte.
3. `DayNightService` et `DayNightController`. Pour les tests, une commande Studio seulement qui force le jour ou la nuit.
4. `ProtectionService` et l'affichage de la protection.
5. `StealService` (règles, transfert atomique), puis `StealRules.luau` : chaque garde-fou de la section 3 a son test.
6. Prompts de crochetage, alerte, annulation.
7. Éjection et étourdissement.
8. Mutation Maudite, fumée, objets "Volé à ...".
9. Analytique, StyLua, commit et push.
10. Tests multijoueurs par Yardley (section 10).

## 10. Tests à 2 joueurs (à faire par Yardley)

Avant le test, réduis la protection débutant à 0 et la durée du jour à 1 minute **dans la config Studio seulement**, puis remets les vraies valeurs.

1. Player1 crochète le coffre de Player2 la nuit, jusqu'au bout : un objet passe de Player2 à Player1, avec "Volé à Player2".
2. Player1 relâche avant 5 secondes : rien n'est volé.
3. Player2 éjecte Player1 pendant le crochetage : Player1 est repoussé, étourdi, et ne peut plus viser ce coffre cette nuit.
4. Après un vol réussi, Player1 ne peut pas voler Player2 une deuxième fois la même nuit.
5. Le jour, le prompt "Crocheter" n'apparaît pas.
6. Un objet Secret n'est jamais volé (mettre un Secret dans le coffre de Player2 avec le pont de test).
7. Avec la protection réactivée, un joueur protégé ne peut ni voler ni être volé.

## 11. Critères de réussite de la semaine

- [ ] Le cycle tourne pendant 30 minutes sans dérive ni erreur, et le minuteur est juste chez tous les clients.
- [ ] Les 6 garde-fous de la section 3 sont couverts par `StealRules.luau` et vérifiés en test réel.
- [ ] Aucun objet perdu ni dupliqué pendant un vol, même si le voleur ou la victime quitte le jeu en plein crochetage.
- [ ] Un client modifié ne peut pas voler le jour, de loin, sans maintenir 5 secondes, ni éjecter quelqu'un qui ne vole pas son coffre.
- [ ] La nuit reste lisible en émulation téléphone.
- [ ] Les 7 tests de la section 10 passent.

## 12. Message à donner à Claude Code

> Lis `CLAUDE.md` puis `docs/plan-semaine-3.md`. Implémente la semaine 3 en suivant l'ordre des tâches de la section 9, une tâche à la fois, avec un playtest par MCP et un commit après chaque tâche. Les garde-fous de la section 3 sont non négociables : écris leurs tests avant le prompt de crochetage. Prépare les réglages de test de la section 10 (protection à 0, jour à 1 minute) dans un mode Studio seulement, impossible à activer en ligne. Arrête-toi et demande-moi avant toute décision qui contredit le plan.
