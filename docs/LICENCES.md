# Licences des assets

Registre de tous les assets que nous n'avons pas créés nous-mêmes : sons, musiques, modèles 3D, textures, icônes, polices.

## Règles

1. **Un asset est noté ici avant d'être intégré au jeu.** Pas de ligne, pas d'intégration : ni dans `src/`, ni dans la carte sur Roblox.
2. **La licence doit autoriser l'usage commercial dans un jeu Roblox monétisé**, avec des passes et des produits, et l'envoi de l'asset sur Roblox (sons, images, maillages). Si la licence est floue, on demande à l'auteur, et on garde sa réponse écrite.
3. **On garde la preuve d'achat** (reçu itch.io) et une copie du texte de la licence telle qu'elle était le jour de l'achat.
4. **Crédit exigé** : si l'auteur demande à être crédité, on note la formule exacte. Ces crédits seront affichés dans le jeu ou sur la page du jeu.
5. **Propriété intellectuelle** : la règle de la section 2 du plan de la semaine 5 s'applique aussi aux assets achetés. Rien qui rappelle une licence existante (personnage, objet, logo, musique connue).
6. **Remplacement ou retrait** : on garde la ligne, et on note dans « Où il est utilisé dans le jeu » que l'asset a été retiré, avec la date.

Pour la colonne « Où il est utilisé dans le jeu » : le réglage dans `src/shared/Config/` (par exemple `UiConfig.SOUND_SELL`), ou l'endroit de la carte, et l'identifiant Roblox une fois l'asset envoyé (`rbxassetid://…`).

## Registre

| Asset | Auteur | Source | Date d'achat | Licence | Crédit exigé | Où il est utilisé dans le jeu |
| ----- | ------ | ------ | ------------ | ------- | ------------ | ----------------------------- |
|       |        |        |              |         |              |                               |

## Sons temporaires (pas à enregistrer)

Le jeu utilise pour l'instant des sons intégrés au moteur Roblox (`rbxasset://sounds/…`, livrés avec Roblox), pas des assets de tiers. Ils seront remplacés à la tâche 6 (sons et musique). Les remplaçants achetés devront être notés dans le registre ci-dessus.

| Son intégré | Réglages qui l'utilisent |
| ----------- | ------------------------ |
| `electronicpingshort.wav` | `UiConfig.SOUND_REVEAL`, `SOUND_SELL`, `SOUND_STEAL_ALARM`, `SOUND_ANNOUNCE`, `DayNightConfig.SOUND_PHASE_BELL` |
| `snap.wav` | `UiConfig.SOUND_DIG_HIT`, `SOUND_REVEAL_IMPACT` |
| `victory.wav` | `UiConfig.SOUND_REVEAL_SPECTACULAR` (révélation Secret, achat à la Forge) |
| `button.wav` | `UiConfig.SOUND_INVENTORY_FULL` |
