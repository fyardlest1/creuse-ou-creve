# Plan technique : semaine 1 (creusage de base)

**Objectif de la semaine :** un joueur rejoint le jeu, reçoit sa parcelle 8 x 8, creuse les cases au clic ou au toucher, voit une révélation animée de l'objet trouvé selon sa rareté, et retrouve son inventaire après s'être déconnecté et reconnecté.

## 1. Ce qui est dans la semaine 1, et ce qui n'y est pas

**Inclus :**

- Génération de 8 parcelles par serveur et attribution d'une parcelle par joueur.
- Creusage des cases (3 coups par case avec la pelle en bois).
- Tirage de rareté, de mutation et d'objet, entièrement côté serveur.
- Révélation de l'objet chez le client (couleur de rareté, petite animation, son temporaire).
- Inventaire limité à 30 objets.
- Passage à la couche suivante quand toute la parcelle est creusée.
- Sauvegarde et chargement des données du joueur.

**Exclu (semaines suivantes) :** vente, Pièces, achat de pelles, coffre visible, vol, cycle jour et nuit, monétisation, quêtes, Index de collection.

## 2. Décisions techniques

| Sujet                    | Décision                                                                                                                                                                                                                     |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Joueurs par serveur      | 8 maximum (Game Settings ou Creator Hub). Donc 8 parcelles.                                                                                                                                                                  |
| Taille d'une case        | 4 x 4 studs. Parcelle = 32 x 32 studs, espacement de 12 studs entre parcelles.                                                                                                                                               |
| Génération des parcelles | Par le serveur au démarrage, dans `Workspace.Plots`. Rien n'est construit à la main pour la semaine 1.                                                                                                                       |
| Saisie du clic           | Raycast depuis la caméra sur clic souris ou toucher (`UserInputService`), pas de ClickDetector (mal adapté au mobile).                                                                                                       |
| Persistance des données  | **ProfileStore** (module de loleris), copié dans `src/server/Vendor/ProfileStore.luau` depuis son dépôt GitHub officiel. Il gère le verrouillage de session, ce qui empêchera la duplication d'objets quand le vol arrivera. |
| État de la parcelle      | Seuls la couche et la profondeur sont sauvegardées. Les cases se régénèrent à chaque connexion.                                                                                                                              |
| Aléatoire                | Une instance `Random.new()` par service, jamais `math.random`.                                                                                                                                                               |
| Réseau                   | Des RemoteEvents créés par le serveur dans `ReplicatedStorage.Remotes`, noms centralisés dans `src/shared/Remotes.luau`.                                                                                                     |

## 3. Arborescence à créer

```
src/
  shared/
    Config/
      PlotConfig.luau       -- taille de grille, taille des cases, coups par case, espacement
      Rarities.luau         -- 6 raretés : chance, couleur, valeur de vente
      Mutations.luau        -- Doré, Diamant, Arc-en-ciel (Maudit attendra la nuit)
      Items.luau            -- objets de la couche 1 (Terre), environ 12
      Shovels.luau          -- pelle en bois seulement, structure prête pour les suivantes
    Types.luau              -- types partagés : ItemInstance, PlayerData, RevealPayload
    Remotes.luau            -- noms des RemoteEvents
  server/
    Main.server.luau        -- point d'entrée : init() puis start() de chaque service
    Vendor/
      ProfileStore.luau
    Services/
      PlayerDataService.luau
      PlotService.luau
      LootService.luau
      DigService.luau
  client/
    Main.client.luau        -- point d'entrée client
    Controllers/
      DigController.luau
      RevealController.luau
      HudController.luau
```

Supprimer les scripts de test `Hello.server.luau` et `Hello.client.luau` une fois `Main` en place.

## 4. Données de configuration (valeurs de départ, tirées du GDD)

**Raretés :** Commun 60 % (gris, 10), Peu commun 25 % (vert, 40), Rare 10 % (bleu, 150), Épique 4 % (violet, 600), Légendaire 0,9 % (or, 3 000), Secret 0,1 % (arc-en-ciel, 25 000).

**Mutations :** Doré 2 % (x3), Diamant 0,5 % (x6), Arc-en-ciel 0,1 % (x15). Une seule mutation par objet, tirée après la rareté.

**Bonus de chance :** un pourcentage (pelle, plus tard potions) qui multiplie le poids de Rare et au-dessus, puis on renormalise. Exemple : +30 % multiplie les poids de Rare, Épique, Légendaire et Secret par 1,3.

**Objets de la couche 1 :** au moins 2 objets par rareté, avec un nom français drôle (exemples : Chaussette Perdue, Canette Rouillée, Dent de Dinosaure, Pièce de Pirate, Montre en Or, Os de Dragon, Œuf Cosmique). Chaque objet a `id`, `name`, `rarity`, `layer`.

## 5. Contrat réseau

| RemoteEvent     | Sens                | Contenu                                                                              | Validation serveur                                                                                                                                |
| --------------- | ------------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PlotAssigned`  | Serveur vers client | `plotIndex: number`, `origin: CFrame`                                                |                                                                                                                                                   |
| `DigRequest`    | Client vers serveur | `cellIndex: number` (1 à 64)                                                         | Entier entre 1 et 64, la case est sur la parcelle du joueur, pas encore creusée, joueur à 30 studs max, cadence de 0,2 s minimum entre deux coups |
| `CellHit`       | Serveur vers client | `cellIndex`, `hitsLeft`                                                              |                                                                                                                                                   |
| `ItemRevealed`  | Serveur vers client | `RevealPayload` : `itemId`, `name`, `rarity`, `mutation?`, `value`, `inventoryCount` |                                                                                                                                                   |
| `InventoryFull` | Serveur vers client | aucun                                                                                |                                                                                                                                                   |
| `LayerCleared`  | Serveur vers client | `layer`, `depth`                                                                     |                                                                                                                                                   |

Une requête invalide est ignorée sans erreur, et loggée en mode Studio seulement.

## 6. Rôle de chaque module

**PlayerDataService**

- Charge le profil à l'arrivée (`ProfileStore`, store `PlayerData_v1`), le libère au départ.
- Expulse proprement le joueur si le profil ne charge pas, avec un message clair.
- Schéma par défaut : `{ version = 1, inventory = {}, layer = 1, depth = 0, stats = { totalDigs = 0, foundByRarity = {} } }`.
- Expose `getData(player)`, `addItem(player, item): boolean` (refuse au-delà de 30), `onLoaded(callback)`.

**PlotService**

- Génère 8 parcelles au démarrage dans `Workspace.Plots`, chaque case est une `Part` ancrée nommée par son index, avec un attribut `HitsLeft`.
- Attribue la première parcelle libre au joueur chargé, libère la parcelle au départ et la remet à neuf.
- Téléporte le joueur au bord de sa parcelle à l'apparition.
- Expose `getPlot(player)`, `getCell(player, cellIndex)`, `resetLayer(player)`.

**LootService**

- `rollRarity(luckBonus): string`, `rollMutation(): string?`, `pickItem(layer, rarity): ItemDef`.
- `roll(player): ItemInstance` assemble le tout, calcule la valeur finale (valeur de rareté x multiplicateur de mutation) et génère un `uid` unique (`HttpService:GenerateGUID(false)`).
- Fonctions pures, testables sans joueur.

**DigService**

- Écoute `DigRequest`, applique toutes les validations du tableau de la section 5.
- Inventaire plein : refuse le `DigRequest` sans consommer de coup, la case reste intacte, et envoie `InventoryFull`. Un joueur ne perd jamais un objet.
- Sinon décrémente `HitsLeft`. À 0 : `LootService.roll`, `PlayerDataService.addItem`, la case disparaît, puis `ItemRevealed`.
- Quand les 64 cases sont creusées : couche +1, profondeur +10 m, `PlotService.resetLayer`, puis `LayerCleared`.
- Incrémente les statistiques du joueur.

**DigController (client)**

- Clic ou toucher : raycast caméra, si la cible est une case de **sa** parcelle, envoie `DigRequest`.
- Retour immédiat local (petite secousse de la case, particules de terre) sans attendre le serveur.

**RevealController (client)**

- Sur `ItemRevealed` : carte au centre de l'écran avec le nom, la couleur de rareté et la mutation, apparition en 0,3 s puis disparition après 1,5 s.
- Pour Légendaire et Secret : carte plus grande, flash et son plus fort. C'est le moment que les joueurs vont filmer, il doit être spectaculaire même avec des effets simples.

**HudController (client)**

- Affiche en haut : profondeur, couche, compteur d'inventaire (`12/30`).
- Bandeau "Inventaire plein" sur `InventoryFull` (semaine 2 : "Vends tes objets au marchand").

## 7. Ordre des tâches pour Claude Code

1. Créer `Types.luau`, `Remotes.luau` et tous les fichiers de `Config/`.
2. Ajouter ProfileStore dans `Vendor/`, écrire `PlayerDataService` et `Main.server.luau`. Test : rejoindre, vérifier dans l'Output que le profil charge et se libère.
3. Écrire `PlotService`. Test : 8 parcelles visibles, le joueur apparaît sur la sienne.
4. Écrire `LootService`. Test : une fonction de vérification lancée en Studio fait 100 000 tirages et affiche la répartition par rareté, qui doit correspondre aux pourcentages à ±0,5 point.
5. Écrire `DigService`. Test : creuser une case en 3 coups, l'objet est ajouté à l'inventaire.
6. Écrire `Main.client.luau`, `DigController`, `RevealController`, `HudController`. Test au clic et en émulation mobile (Studio, onglet Test, Device).
7. Test de sauvegarde : creuser 5 objets, quitter, revenir, l'inventaire est intact.
8. Supprimer les scripts Hello, formater avec StyLua, commit et push.

## 8. Critères de réussite de la semaine

- [ ] Aucune erreur rouge dans l'Output pendant 5 minutes de jeu.
- [ ] Creuser fonctionne à la souris et en émulation téléphone.
- [ ] La répartition des raretés sur 100 000 tirages correspond aux pourcentages.
- [ ] L'inventaire survit à une déconnexion et une reconnexion.
- [ ] Un client modifié qui envoie `DigRequest` en boucle ou avec un index invalide n'obtient rien de plus.
- [ ] Deux joueurs (Test, Local Server, 2 joueurs) ont chacun leur parcelle et ne peuvent pas creuser celle de l'autre.

## 9. Message à donner à Claude Code

> Lis `CLAUDE.md` puis `docs/plan-semaine-1.md`. Implémente la semaine 1 en suivant l'ordre des tâches de la section 7, une tâche à la fois. Après chaque tâche, lance un playtest dans Studio par MCP, lis l'Output, corrige les erreurs, puis fais un commit Git. Arrête-toi et demande-moi avant toute décision qui contredit le plan.
