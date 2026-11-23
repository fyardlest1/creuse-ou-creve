# Creuse ou Crève (Konbit Games)

Jeu Roblox de collection et de pillage : chaque joueur creuse sa parcelle, déterre des objets de rareté variable, les vend pour améliorer sa pelle, et protège son coffre contre les voleurs la nuit.

Le game design complet est dans le document "Creuse ou Crève : Game Design Document". Le plan de la semaine en cours est dans `docs/`.

## Stack

- Luau, synchronisé dans Roblox Studio avec **Rojo** (`default.project.json`).
- Outils gérés par **Rokit** (`rokit.toml`) : Rojo, StyLua.
- Git + GitHub (dépôt privé). Le code vit dans Git, la carte vit sur Roblox.
- Roblox Studio est accessible par le serveur MCP `Roblox_Studio` pour inspecter la place et lancer des tests.

## Structure

```
src/
  server/   -> ServerScriptService.Server       (Scripts et modules serveur)
  client/   -> StarterPlayerScripts.Client      (LocalScripts et modules client)
  shared/   -> ReplicatedStorage.Shared         (config, types, utilitaires partagés)
docs/       -> plans de semaine et notes techniques
```

Nommage Rojo : `.server.luau` = Script, `.client.luau` = LocalScript, `.luau` = ModuleScript.

## Règles non négociables

1. **Le code vit uniquement dans `src/`.** Ne jamais créer ni modifier un script directement dans Studio par MCP : Rojo l'écraserait ou il serait perdu. MCP sert à inspecter la place, lire l'Output et lancer des playtests.
2. **Le serveur fait autorité.** Toute logique de rareté, de butin, d'inventaire, d'argent, de vol et d'achat s'exécute côté serveur. Le client envoie des intentions ("je creuse la case 12"), jamais des résultats ("j'ai trouvé un objet Secret").
3. **Valider chaque RemoteEvent côté serveur** : type des arguments, propriété de la parcelle, distance, cadence (anti-spam).
4. **`--!strict` en tête de chaque fichier**, types explicites pour les données et les payloads réseau.
5. **Aucune valeur magique dans la logique** : probabilités, prix, tailles et délais vont dans `src/shared/Config/`.
6. **Mobile en priorité** : toute interaction doit marcher au toucher, et l'interface doit rester lisible sur un écran de téléphone.
7. **Assets externes** : seulement Kenney.nl et Quaternius (CC0) et Fab (licence Standard). Aucun asset externe n'entre dans le jeu sans sa ligne dans `docs/LICENCES.md` (source, licence, fichier, usage). Les packs bruts restent dans `C:\dev\creuse-ou-creve-assets`, jamais dans le dépôt.
8. **Aucun modèle ne doit contenir de script.** Avant d'intégrer un modèle, vérifier qu'il n'a aucun descendant `Script`, `LocalScript` ou `ModuleScript` ; s'il en a, le refuser (ne pas se contenter de supprimer les scripts sans le signaler).

## Conventions

- Identifiants de code en anglais (`DigService`, `rollRarity`), textes affichés aux joueurs en français.
- Un module = une responsabilité. Services serveur dans `src/server/Services/`, contrôleurs client dans `src/client/Controllers/`.
- Chaque service expose `init()` (préparation) et `start()` (connexions). Un seul point d'entrée par côté : `src/server/Main.server.luau` et `src/client/Main.client.luau`.
- Formatage StyLua avant chaque commit.
- Pas de `wait()` ni de `spawn()` : utiliser `task.wait`, `task.spawn`, `task.delay`.
- Messages de log préfixés : `[DigService]`, `[PlayerData]`, etc.

## Workflow

1. Lire le plan de la semaine dans `docs/` avant de coder.
2. Implémenter une tâche à la fois, dans l'ordre du plan.
3. Après chaque tâche : vérifier que Rojo synchronise, lancer un playtest par MCP, lire l'Output, corriger les erreurs.
4. Commit Git par tâche terminée, message en français et clair (`Ajout du DigService avec validation serveur`).
