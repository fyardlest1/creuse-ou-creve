# Plan technique : semaine 5 (polish et viralité)

**Objectif de la semaine :** transformer un jeu qui fonctionne en un jeu qu'on a envie de filmer, de partager et de relancer. Tout ce qui se voit, s'entend et se ressent passe au niveau supérieur, le jeu devient jouable en anglais, et il tient la charge sur un téléphone d'entrée de gamme.

**Prérequis :** la semaine 4 est bouclée, y compris le test à 2 joueurs des achats.

**Règle de la semaine :** aucune nouvelle mécanique de base. On améliore, on n'ajoute pas de système qui change l'économie, le vol ou les achats. Les seules exceptions sont listées dans ce plan.

## 1. Ce qui est dans la semaine 5

1. Moments forts : révélations façon anime, annonces serveur, auras.
2. Objets originaux d'inspiration anime.
3. Vrais modèles de pelles et vraie animation de creusage.
4. Mini-jeu de crochetage.
5. Événements de serveur : pluie de météorites et Nuit de sang.
6. Sons et musique.
7. Salon VIP et cosmétiques de voleur.
8. Codes promo.
9. Version anglaise.
10. Performance mobile.
11. Icône du jeu, miniatures et icônes des produits.

**Exclu (semaine 6) :** test fermé, transfert au groupe, lancement, publicités.

## 2. Règle de propriété intellectuelle (non négociable)

Aucun nom, personnage, objet, logo, musique ou visuel reconnaissable d'une licence existante (One Piece, Naruto, Dragon Ball, Pokémon, etc.). On reprend les **codes** du genre anime (pirates, ninjas, auras, lignes de vitesse, dragons), jamais une œuvre précise. En cas de doute sur un nom ou un visuel, on le remplace. Un jeu retiré pour une licence perd tout : ses visites, son classement et ses revenus.

## 3. Moments forts

**Révélation des objets, selon la rareté :**

| Rareté                   | Effet                                                                                                                                                                  |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Commun, Peu commun, Rare | Carte actuelle, inchangée.                                                                                                                                             |
| Épique                   | Carte plus grande, halo violet, son plus fort.                                                                                                                         |
| Légendaire               | Écran qui se fige 0,3 s, lignes de vitesse façon anime, flash doré, gros son d'impact, petite secousse de caméra.                                                      |
| Secret                   | Tout ce qui précède en arc-en-ciel, plus une aura qui monte autour du personnage pendant 3 s, visible par tous les joueurs proches, et une musique courte de victoire. |

Les effets doivent rester lisibles en 1 seconde sur un écran de téléphone : c'est ce qui sera filmé.

**Annonces serveur :** Légendaire et Secret sont annoncés à tout le serveur ("Yardley a trouvé un SECRET : Œuf du Dragon Céleste !"), avec un son distinct. Les annonces existantes de la semaine 2 sont harmonisées avec ce style.

**Annonce et carte de révélation (retour du test sur téléphone Android) :** chez le joueur qui trouve un Légendaire ou un Secret, l'annonce serveur ne doit jamais s'afficher en même temps que sa carte de révélation, qui passe devant et coupe le texte. L'annonce attend la fin de la carte (disparition comprise). Si une révélation Légendaire ou Secret commence pendant qu'une annonce est affichée (celle d'un autre joueur), l'annonce se met en pause, puis reprend pour le temps qui lui restait.

**Icônes des objets (décision) :** chaque objet a une icône, affichée sur la carte de révélation et sur les cartes du coffre et du Marchand. Elle se déclare dans le champ `icon` de `Items.luau` (`"rbxassetid://<nombre>"`). Tant qu'une icône manque, ou si l'image ne se charge pas, le jeu affiche un repli propre : un carré arrondi à la couleur de la rareté, avec l'initiale du nom de l'objet dans la langue du joueur. Les icônes des Légendaires et des Secrets sont créées en premier. Elles respectent la règle de la section 2 : aucune ne doit rappeler un objet ou un personnage d'une licence existante.

**Aura de collectionneur :** tant qu'un joueur a au moins un Secret dans son coffre, une aura arc-en-ciel discrète l'entoure en permanence. C'est un statut visible de loin, et une cible évidente la nuit. Elle disparaît si le Secret est vendu.

## 4. Objets originaux d'inspiration anime

À ajouter dans `Items.luau`, avec la même structure que les objets existants :

| Objet                       | Anglais                | Rareté     | Couche |
| --------------------------- | ---------------------- | ---------- | ------ |
| Masque de Ninja Rouillé     | Rusty Ninja Mask       | Commun     | Terre  |
| Boussole du Capitaine Perdu | Lost Captain's Compass | Peu commun | Terre  |
| Carte de Pirate Délavée     | Faded Pirate Map       | Rare       | Argile |
| Katana Fantôme              | Ghost Katana           | Épique     | Argile |
| Masque d'Oni Fendu          | Cracked Oni Mask       | Épique     | Roche  |
| Ancre du Navire Englouti    | Sunken Ship's Anchor   | Légendaire | Roche  |
| Perle Céleste               | Celestial Pearl        | Légendaire | Roche  |
| Œuf du Dragon Céleste       | Celestial Dragon Egg   | Secret     | Roche  |

L'Index de collection les intègre automatiquement. Vérifier que la probabilité de chaque rareté ne change pas : on ajoute des objets dans chaque rareté, on ne change pas les poids.

**Décisions prises pendant l'implémentation (Yardley, 21 novembre 2026) :**

- **Carte de Pirate Délavée** remplace « Carte au Trésor Déchirée » : cet objet existait déjà (Rare, Roche). Le déplacer dans l'Argile aurait laissé la Roche avec un seul Rare, alors que chaque couche doit en avoir au moins 2.
- **Masque de Ninja Rouillé** remplace « Bandeau de Ninja Rouillé » (règle de la section 2) : le bandeau frontal à plaque de métal est le signe le plus reconnaissable de Naruto.
- **Perle Céleste** remplace « Orbe d'Énergie Céleste » (section 2) : un orbe d'énergie à côté d'un œuf de dragon pouvait rappeler Dragon Ball. La perle tenue par un dragon vient du folklore asiatique, pas d'une œuvre précise.
- **Renommage d'un objet existant :** « Crochet du Capitaine » (Épique, Roche) devient **Crochet de Pirate** (EN : Pirate's Hook), car il évoquait directement le Capitaine Crochet de Peter Pan, dont le visuel appartient à Disney. Seul le nom affiché change : l'identifiant `captain_hook` reste le même, donc les coffres des joueurs ne bougent pas.
- Les visuels de ces objets (icônes, miniatures) ne doivent pas non plus rappeler une œuvre : pas de plaque gravée sur le masque de ninja, pas de boules à étoiles près de la perle.

## 5. Pelles et creusage

- Remplacer les pelles en Parts par de vrais modèles 3D (bois, fer, acier), légers (moins de 2 000 triangles chacun), créés ou importés par Yardley, ou générés dans Studio. Garder les Parts actuelles comme solution de repli si un modèle manque.
- Remplacer le geste procédural par une vraie animation de creusage faite dans l'Animation Editor de Studio. L'animation doit être publiée par le **même propriétaire que le jeu** (le compte de Yardley maintenant, le groupe après le transfert de la semaine 6), sinon elle ne se jouera pas. Garder le geste procédural en repli si l'animation ne charge pas.

## 6. Mini-jeu de crochetage

Remplace le simple maintien de 5 s :

- Une barre avec une zone verte et un curseur qui va et vient. Le voleur doit toucher l'écran (ou cliquer) quand le curseur est dans la zone, **3 fois de suite**.
- Un échec fait recommencer la série, sans pénalité, sauf le temps perdu.
- La durée totale moyenne doit rester proche de 5 s (8 s avec le Garde du corps, dont la zone verte est plus petite).
- **Le serveur reste maître :** il vérifie la durée minimale réelle (au moins 4 s, 6,5 s avec le Garde du corps), la distance et toutes les règles de la semaine 3. Le client ne fait qu'envoyer "réussi". Un client modifié qui envoie "réussi" trop tôt n'obtient rien.
- Les zones tactiles font au moins 44 px.

## 7. Événements de serveur

**Pluie de météorites :** toutes les 30 minutes, pendant 3 minutes, des météorites tombent sur les parcelles. Pendant l'événement, les chances de Rare et mieux sont doublées pour tous, dans la formule unique de chance de la semaine 4, qui reste plafonnée à x10.

**Nuit de sang :** à chaque nuit, 15 % de chance qu'elle devienne une Nuit de sang : elle dure 4 minutes au lieu de 2, le ciel devient rouge sombre (toujours lisible), et les mutations Maudites tombent 3 fois plus souvent. Les garde-fous du vol de la semaine 3 restent identiques.

Les deux événements sont annoncés à tout le serveur 10 secondes avant leur début, avec un compte à rebours dans le HUD.

## 8. Sons et musique

- Uniquement des sons et musiques du Creator Store sous licence Roblox, ou créés par Yardley. Aucun son tiré d'un anime ou d'une chanson connue.
- À couvrir : coup de pelle (3 variantes pour éviter la répétition), révélation par rareté, vente (caisse), achat de pelle, cloche jour et nuit, ambiance de nuit (reportée de la semaine 3), alarme de vol, éjection, crochetage réussi et raté, météorites, Nuit de sang, musique de fond calme le jour.
- Un bouton dans les réglages pour couper la musique, et un autre pour couper les effets sonores.

## 9. Salon VIP et cosmétiques de voleur

**Salon VIP :** une petite zone près du Marchand, réservée aux propriétaires du pass VIP (porte qui ne laisse passer qu'eux), avec un Marchand VIP qui vend au même prix (le +10 % s'applique déjà partout). C'est du statut visible, pas un avantage de jeu.

**Cosmétiques de voleur :** les Points de Voleur de la semaine 3 deviennent dépensables dans une petite boutique de cosmétiques : 3 masques et 2 sacs à dos, purement visuels, portés la nuit. Prix en Points de Voleur, jamais en Robux. Aucun avantage de jeu.

## 10. Codes promo

- Une case "Codes" dans les réglages. Chaque code donne une récompense une seule fois par joueur (enregistré dans le profil).
- Codes de lancement prévus : `CREUSE` (1 Potion de chance), `TRESOR` (2 000 Pièces), `DISCORD` (1 Bouclier). Les codes et leurs récompenses sont dans la config, avec une date d'expiration optionnelle.
- Validation côté serveur, insensible aux majuscules, avec une cadence anti-spam.

## 11. Version anglaise

Le public de Roblox est majoritairement anglophone : sans anglais, on se prive de la plus grande partie des joueurs.

- Tous les textes affichés passent par un seul module de traduction (`src/shared/Locale/`), avec le français comme langue source et l'anglais comme traduction. Plus aucun texte écrit en dur dans les contrôleurs.
- La langue suit celle du joueur sur Roblox (`LocalizationService`). Par défaut, l'anglais pour toute langue autre que le français.
- Les noms des objets, des couches, des pelles et des produits sont traduits aussi (les textes des produits existent déjà dans le document des produits).
- Le nom du jeu reste "Creuse ou Crève" en français. En anglais, on affiche le sous-titre "Dig or Die".

## 12. Performance mobile

Cibles sur un téléphone Android d'entrée de gamme en émulation, avec 8 joueurs :

- Au moins 30 images par seconde en jeu normal, et pas de chute sous 20 pendant une révélation Secret ou une pluie de météorites.
- Moins de 600 Mo de mémoire côté client.
- Particules et effets limités en nombre, et réduits automatiquement si les images par seconde baissent.
- Pas de boucle qui tourne à chaque image sans raison côté client, et pas de `RemoteEvent` envoyé à chaque image.

## 13. Visuels de la page du jeu (Yardley, avec mon aide)

- **Icône du jeu** (512 x 512) : un personnage avec sa pelle qui brandit un objet arc-en-ciel, et le titre bien lisible.
- **3 miniatures** (1920 x 1080) : une révélation Secret, un vol de nuit, la Forge avec les pelles.
- **Icônes des 13 produits et des 7 badges**, dans un style unique.
- Description de la page du jeu en français et en anglais, que je rédigerai.

## 14. Ordre des tâches pour Claude Code

1. Module de traduction et passage de tous les textes existants dedans (français et anglais).
2. Objets d'inspiration anime, avec un test qui vérifie que les poids de rareté n'ont pas changé.
3. Révélations par rareté, annonces serveur, aura de collectionneur.
4. Mini-jeu de crochetage, avec ses tests côté serveur (durée minimale, client modifié).
5. Pluie de météorites et Nuit de sang.
6. Sons et musique, avec les boutons pour couper.
7. Salon VIP et boutique de cosmétiques de voleur.
8. Codes promo.
9. Pelles 3D et animation de creusage, dès que Yardley fournit les modèles et l'animation.
10. Passe de performance en émulation téléphone, StyLua, commit et push.

## 15. Critères de réussite de la semaine

- [ ] Une révélation Secret est spectaculaire et lisible en 1 seconde en émulation téléphone.
- [ ] Aucun nom ni visuel d'une licence existante dans le jeu.
- [ ] Le jeu est entièrement jouable en anglais, sans texte français oublié.
- [ ] Le mini-jeu de crochetage dure environ 5 s en moyenne, et un client modifié ne peut pas le raccourcir.
- [ ] Les événements de serveur respectent le plafond de chance x10 et les garde-fous du vol.
- [ ] Les codes promo ne fonctionnent qu'une fois par joueur.
- [ ] Au moins 30 images par seconde en émulation Android d'entrée de gamme, avec 8 joueurs.
- [ ] Tous les tests des semaines précédentes passent encore.
- [ ] Test à 2 joueurs par Yardley : aura visible chez l'autre joueur, annonce Secret chez les deux, mini-jeu de crochetage, Nuit de sang.

## 16. Message à donner à Claude Code

> Lis `CLAUDE.md` puis `docs/plan-semaine-5.md`. Implémente la semaine 5 en suivant l'ordre des tâches de la section 14, une tâche à la fois, avec un playtest par MCP et un commit après chaque tâche. La règle de propriété intellectuelle de la section 2 est non négociable : signale-moi tout nom ou visuel qui pourrait rappeler une licence existante. Ne change ni l'économie, ni les règles du vol, ni les achats. Fais tourner tous les tests des semaines précédentes après chaque tâche. Arrête-toi et demande-moi avant toute décision qui contredit le plan.
