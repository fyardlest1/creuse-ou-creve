# Licences des assets

Registre de tous les assets que nous n'avons pas créés nous-mêmes : sons, musiques, modèles 3D, textures, icônes, polices.

## Sources autorisées

Seulement ces trois sources (décision du 23 novembre 2026). Tout le reste est refusé, y compris le Creator Store de Roblox, sauf nouvelle décision notée ici.

| Source | Licence | Ce qu'elle permet | Crédit | Points à vérifier à chaque asset |
| ------ | ------- | ----------------- | ------ | -------------------------------- |
| [Kenney.nl](https://kenney.nl) | CC0 1.0 (domaine public) | Tout usage, commercial compris, modification et envoi sur Roblox | Non exigé (on le crédite quand même dans le jeu) | Télécharger depuis kenney.nl, pas depuis un site de reprise. Garder le `License.txt` du pack. |
| [Quaternius](https://quaternius.com) | CC0 1.0 (domaine public) | Tout usage, commercial compris, modification et envoi sur Roblox | Non exigé (on le crédite quand même dans le jeu) | Télécharger depuis quaternius.com (ou sa page officielle). Garder le fichier de licence du pack. |
| [Fab](https://www.fab.com) | Licence Standard de Fab | Usage dans un jeu, commercial compris, selon les conditions de la licence | Selon la page de l'asset | **Refuser les assets marqués « UE-Only »** (réservés à Unreal Engine). Vérifier sur la page que la licence est bien la Standard, et garder une copie de la page et du reçu. Le jeu ne doit jamais permettre de récupérer l'asset brut. |

## Règles

1. **Un asset externe est noté ici avant d'entrer dans le jeu** (règle 7 de `CLAUDE.md`). Pas de ligne, pas d'intégration : ni dans `src/`, ni dans la carte sur Roblox.
2. **Les packs bruts restent dans `C:\dev\creuse-ou-creve-assets`**, jamais dans le dépôt Git. La colonne « Fichier » donne le chemin dans ce dossier.
3. **Aucun modèle ne doit contenir de script** (règle 8 de `CLAUDE.md`) : aucun `Script`, `LocalScript` ou `ModuleScript` dans ses descendants. Un modèle qui en contient est refusé et signalé.
4. **Preuve de licence** : on garde le fichier de licence du pack (Kenney, Quaternius) ou une copie de la page et du reçu (Fab), à côté du pack brut.
5. **Propriété intellectuelle** : la règle de la section 2 du plan de la semaine 5 s'applique aussi aux assets. Rien qui rappelle une licence existante (personnage, objet, logo, musique connue).
6. **Remplacement ou retrait** : on garde la ligne, et on note dans « Usage dans le jeu » que l'asset a été retiré, avec la date.

Pour la colonne « Usage dans le jeu » : le réglage dans `src/shared/Config/` (par exemple `UiConfig.SOUND_SELL`) ou l'endroit de la carte, puis l'identifiant Roblox une fois l'asset envoyé (`rbxassetid://…`).

## Registre

| Asset | Source | Auteur | Licence | Fichier | Date d'obtention | Crédit | Usage dans le jeu |
| ----- | ------ | ------ | ------- | ------- | ---------------- | ------ | ----------------- |
|       |        |        |         |         |                  |        |                   |

## Sons temporaires (pas à enregistrer)

Le jeu utilise pour l'instant des sons intégrés au moteur Roblox (`rbxasset://sounds/…`, livrés avec Roblox), pas des assets externes. Ils seront remplacés à la tâche 6 (sons et musique). Les remplaçants devront être notés dans le registre ci-dessus.

| Son intégré | Réglages qui l'utilisent |
| ----------- | ------------------------ |
| `electronicpingshort.wav` | `UiConfig.SOUND_REVEAL`, `SOUND_SELL`, `SOUND_STEAL_ALARM`, `SOUND_ANNOUNCE`, `DayNightConfig.SOUND_PHASE_BELL` |
| `snap.wav` | `UiConfig.SOUND_DIG_HIT`, `SOUND_REVEAL_IMPACT`, `SOUND_LOCKPICK_HIT` |
| `victory.wav` | `UiConfig.SOUND_REVEAL_SPECTACULAR` (révélation Secret, achat à la Forge) |
| `button.wav` | `UiConfig.SOUND_INVENTORY_FULL`, `SOUND_LOCKPICK_MISS` |
