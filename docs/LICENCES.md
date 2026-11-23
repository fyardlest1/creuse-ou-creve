# Licences des assets

Registre de tous les assets que nous n'avons pas créés nous-mêmes : sons, musiques, modèles 3D, textures, icônes, polices.

## Sources autorisées

Seulement ces trois sources (décision du 23 novembre 2026). Tout le reste est refusé, y compris le Creator Store de Roblox, sauf nouvelle décision notée ici.

| Source | Licence | Ce qu'elle permet | Crédit | Points à vérifier à chaque asset |
| ------ | ------- | ----------------- | ------ | -------------------------------- |
| [Kenney.nl](https://kenney.nl) | CC0 1.0 (domaine public) | Tout usage, commercial compris, modification et envoi sur Roblox | Non exigé (on le crédite quand même dans le jeu) | Télécharger depuis kenney.nl, pas depuis un site de reprise. Garder le `License.txt` du pack. |
| [Quaternius](https://quaternius.com) | CC0 1.0 (domaine public) | Tout usage, commercial compris, modification et envoi sur Roblox | Non exigé (on le crédite quand même dans le jeu) | Télécharger depuis quaternius.com (ou sa page officielle). Garder le fichier de licence du pack. |
| [Fab](https://www.fab.com) | Licence Standard de Fab | Usage dans un jeu, commercial compris, selon les conditions de la licence | Selon la page de l'asset | **Refuser les assets marqués « UE-Only »** (réservés à Unreal Engine). Vérifier sur la page que la licence est bien la Standard, et garder une copie de la page et du reçu. Le jeu ne doit jamais permettre de récupérer l'asset brut. Voir les **obligations Fab** plus bas. |

## Règles

1. **Un asset externe est noté ici avant d'entrer dans le jeu** (règle 7 de `CLAUDE.md`). Pas de ligne, pas d'intégration : ni dans `src/`, ni dans la carte sur Roblox.
2. **Les packs bruts restent dans `C:\dev\creuse-ou-creve-assets`**, jamais dans le dépôt Git. La colonne « Fichier » donne le chemin dans ce dossier.
3. **Aucun modèle ne doit contenir de script** (règle 8 de `CLAUDE.md`) : aucun `Script`, `LocalScript` ou `ModuleScript` dans ses descendants. Un modèle qui en contient est refusé et signalé.
4. **Preuve de licence** : on garde le fichier de licence du pack (Kenney, Quaternius) ou une copie de la page et du reçu (Fab), à côté du pack brut.
5. **Propriété intellectuelle** : la règle de la section 2 du plan de la semaine 5 s'applique aussi aux assets. Rien qui rappelle une licence existante (personnage, objet, logo, musique connue).
6. **Remplacement ou retrait** : on garde la ligne, et on note dans « Usage dans le jeu » que l'asset a été retiré, avec la date.

## Obligations de la licence Fab Standard

Texte de référence : le contrat de licence Fab (« Fab End User License Agreement », version du 1er octobre 2024), copié dans `fab.com-purchase.txt` à côté du pack. Ces obligations valent pour **chaque** asset Fab, tant qu'il est dans le jeu.

**Ce que la licence autorise :**

- **Palier Personal** (article 2a) : réservé à qui, entreprises liées comprises, n'a pas dépassé 100 000 $ US de revenus bruts dans le contenu numérique sur les 12 derniers mois. Au-delà, les **nouveaux** achats doivent se faire au palier Professional.
- **Mettre l'asset dans un jeu distribué au public** (article 4c), à condition que les joueurs ne puissent s'en servir que dans le jeu.
- **Le partager en privé avec les collaborateurs du projet** (article 5a), Claude Code compris. Un collaborateur ne le redistribue pas et l'efface quand il n'en a plus besoin. Un asset marqué « NoAI » sur sa fiche est refusé.

**Les quatre interdits sur Roblox :**

1. **Ne jamais rendre public les modèles Fab importés sur Roblox, ni les mettre en vente dans le Creator Store.** Les meshes, textures et modèles envoyés restent privés. On ne coche jamais « Distribuer sur le Creator Store ». *Articles 4c et 6(ii).*
2. **Ne jamais rendre la place copiable.** Le réglage « Autoriser la copie » de la place reste désactivé, pour toujours. *Article 4c : empêcher les joueurs d'extraire l'asset.*
3. **Ne jamais en faire un objet d'avatar à vendre** (accessoire, outil de l'avatar, UGC dans la boutique Roblox). L'asset reste une partie du jeu, pas un produit vendu seul. *Article 6(ii).*
4. **Ne jamais l'intégrer à un outil de construction partagé** : kit, modèle ou plugin publié, place modèle, éditeur de niveaux qui permet d'exporter. Personne d'autre ne doit pouvoir s'en servir dans ses propres créations. *Article 6(iii).*

Autres limites :

- Pas de combinaison avec du contenu sous licence GPL, LGPL ou CC BY-SA (article 6a). Le CC0 de Kenney et de Quaternius est compatible.
- Ne pas retirer de mentions de propriété présentes dans l'asset (article 6(vi)).

Pour la colonne « Usage dans le jeu » : le réglage dans `src/shared/Config/` (par exemple `UiConfig.SOUND_SELL`) ou l'endroit de la carte, puis l'identifiant Roblox une fois l'asset envoyé (`rbxassetid://…`).

## Registre

| Asset | Source | Auteur | Licence | Fichier | Date d'obtention | Crédit | Usage dans le jeu |
| ----- | ------ | ------ | ------- | ------- | ---------------- | ------ | ----------------- |
| Kenney Game Assets All-in-1 3.4.0 (pack complet, source) | Kenney.nl (achat) | Kenney Vleugels | CC0 1.0 (un `License.txt` par sous-pack) | `kenney/` | à compléter (reçu PDF dans `kenney/`) | Non exigé ; « Kenney (www.kenney.nl) » dans les crédits du jeu | Les 22 sons ci-dessous. |
| CoC_dig_hit_1 | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Impact Sounds/Audio/impactMining_000.ogg` | voir le pack | Non exigé | Coup de pelle (variante 1) — `AudioConfig.DIG_HITS`, `rbxassetid://71845224765541` |
| CoC_dig_hit_2 | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Impact Sounds/Audio/impactMining_002.ogg` | voir le pack | Non exigé | Coup de pelle (variante 2) — `AudioConfig.DIG_HITS`, `rbxassetid://85059165910638` |
| CoC_dig_hit_3 | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Impact Sounds/Audio/impactMining_004.ogg` | voir le pack | Non exigé | Coup de pelle (variante 3) — `AudioConfig.DIG_HITS`, `rbxassetid://82191501804971` |
| CoC_reveal | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Interface Sounds/Audio/confirmation_002.ogg` | voir le pack | Non exigé | Révélation Commun à Rare — `AudioConfig.REVEAL`, `rbxassetid://102008875800532` |
| CoC_reveal_epic | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Music Jingles/Audio (Steeldrum)/jingles-steel_03.ogg` | voir le pack | Non exigé | Révélation Épique — `AudioConfig.REVEAL_EPIC`, `rbxassetid://76698623998150` |
| CoC_reveal_impact | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Sci-Fi Sounds/Audio/lowFrequency_explosion_001.ogg` | voir le pack | Non exigé | Impact Légendaire et Secret — `AudioConfig.REVEAL_IMPACT`, `rbxassetid://103762663679765` |
| CoC_reveal_secret_victory | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Music Jingles/Audio (Saxophone)/jingles-saxophone_02.ogg` | voir le pack | Non exigé | Victoire Secret — `AudioConfig.REVEAL_SECRET_VICTORY`, `rbxassetid://123677676815531` |
| CoC_sell | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/RPG Audio/Audio/handleCoins.ogg` | voir le pack | Non exigé | Vente au Marchand — `AudioConfig.SELL`, `rbxassetid://81882312193102` |
| CoC_shovel_buy | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Digital Audio/Audio/powerUp3.ogg` | voir le pack | Non exigé | Achat de pelle à la Forge — `AudioConfig.SHOVEL_BUY`, `rbxassetid://80587804377145` |
| CoC_inventory_full | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Interface Sounds/Audio/error_006.ogg` | voir le pack | Non exigé | Coffre plein — `AudioConfig.INVENTORY_FULL`, `rbxassetid://103027199143841` |
| CoC_announce | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Digital Audio/Audio/threeTone2.ogg` | voir le pack | Non exigé | Annonce serveur — `AudioConfig.ANNOUNCE`, `rbxassetid://95038942153664` |
| CoC_phase_bell | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Impact Sounds/Audio/impactBell_heavy_001.ogg` | voir le pack | Non exigé | Cloche jour et nuit — `AudioConfig.PHASE_BELL`, `rbxassetid://127399780766865` |
| CoC_steal_alarm | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Sci-Fi Sounds/Audio/forceField_000.ogg` | voir le pack | Non exigé | Alarme de vol (boucle) — `AudioConfig.STEAL_ALARM`, `rbxassetid://112850018021477` |
| CoC_eject_punch | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Impact Sounds/Audio/impactPunch_heavy_000.ogg` | voir le pack | Non exigé | Éjection (coup) — `AudioConfig.EJECT_PUNCH`, `rbxassetid://139729931229893` |
| CoC_eject_woosh | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Foley Sounds/Audio/Woosh/woosh3.ogg (rééchantillonné de 96 à 48 kHz)` | voir le pack | Non exigé | Éjection (souffle) — `AudioConfig.EJECT_WOOSH`, `rbxassetid://133499672690812` |
| CoC_lockpick_hit | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/RPG Audio/Audio/metalClick.ogg` | voir le pack | Non exigé | Crochetage : touche réussie — `AudioConfig.LOCKPICK_HIT`, `rbxassetid://134052168889977` |
| CoC_lockpick_miss | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Interface Sounds/Audio/error_001.ogg` | voir le pack | Non exigé | Crochetage : raté — `AudioConfig.LOCKPICK_MISS`, `rbxassetid://78021126935770` |
| CoC_lockpick_done | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/RPG Audio/Audio/metalLatch.ogg` | voir le pack | Non exigé | Crochetage : serrure ouverte — `AudioConfig.LOCKPICK_DONE`, `rbxassetid://79172070940555` |
| CoC_meteor_impact | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Sci-Fi Sounds/Audio/explosionCrunch_000.ogg` | voir le pack | Non exigé | Impact de météorite (son 3D) — `AudioConfig.METEOR_IMPACT`, `rbxassetid://98050743779257` |
| CoC_blood_night | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Impact Sounds/Audio/impactBell_heavy_000.ogg` | voir le pack | Non exigé | Arrivée de la Nuit de sang (cloche grave) — `AudioConfig.BLOOD_NIGHT`, `rbxassetid://77927147262256` |
| CoC_music_day | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Music Loops/Loops/Flowing Rocks.ogg` | voir le pack | Non exigé | Musique de fond le jour — `AudioConfig.MUSIC_DAY`, `rbxassetid://75054087770832` |
| CoC_night_ambience | Kenney.nl (pack All-in-1) | Kenney Vleugels | CC0 1.0 | `kenney/Audio/Music Loops/Retro/Retro Mystic.ogg` | voir le pack | Non exigé | Musique de nuit — `AudioConfig.MUSIC_NIGHT`, `rbxassetid://113958371532738` |
| Stylized Miner Hand Tools Kit (pack, source) | Fab (achat) | à compléter (vendeur indiqué sur la fiche Fab) | Fab Standard, palier Personal ; fiche : « Allows usage with AI : Yes » | `C:\Dev\FAB\` (à déplacer dans `fab/stylized_miner_hand_tools_kit/`) : `.fbx`, `.blend`, `.obj` + 14 textures | à compléter (reçu à garder à côté du pack) | à vérifier sur la fiche Fab | **Pas encore intégré.** Prévu pour les pelles 3D (tâche 9). Soumis aux obligations Fab ci-dessus. |

Notes sur le pack Kenney :

- Le dossier contient aussi l'installateur `Kenney Game Assets All-in-1 3.4.0.exe` : il n'est pas un asset du jeu, et on ne le lance pas depuis les outils du projet.
- Musique « Mission Plausible » (`Audio/Music Loops/Loops/`) : son titre parodie une licence connue. Elle est écartée par précaution (règle de la section 2).

## Anciens sons temporaires

Jusqu'à la tâche 6, le jeu utilisait des sons intégrés au moteur Roblox (`rbxasset://sounds/…`, livrés avec Roblox). Ils sont tous remplacés par les sons Kenney du registre (23 novembre 2026) ; le tableau ci-dessous est gardé pour l'historique.

| Son intégré | Réglages qui l'utilisent |
| ----------- | ------------------------ |
| `electronicpingshort.wav` | `UiConfig.SOUND_REVEAL`, `SOUND_SELL`, `SOUND_STEAL_ALARM`, `SOUND_ANNOUNCE`, `DayNightConfig.SOUND_PHASE_BELL` |
| `snap.wav` | `UiConfig.SOUND_DIG_HIT`, `SOUND_REVEAL_IMPACT`, `SOUND_LOCKPICK_HIT` |
| `victory.wav` | `UiConfig.SOUND_REVEAL_SPECTACULAR` (révélation Secret, achat à la Forge) |
| `button.wav` | `UiConfig.SOUND_INVENTORY_FULL`, `SOUND_LOCKPICK_MISS` |
