# Creuse ou Crève : Game Design Document

Nov 19, 2026 · @Yardley Estiverne

## 1. Le concept en une phrase

Chaque joueur possède une parcelle de terre. Il creuse pour déterrer des objets de rareté variable, les vend pour améliorer sa pelle et creuser plus profond, et doit protéger son coffre parce que, la nuit, les autres joueurs peuvent venir le voler.

**Genre :** simulateur de collection + pillage de base (inspiré des boucles de Fish It et Steal a Brainrot).

**Plateforme :** Roblox (mobile en priorité, puis PC et console).

## 2. Public cible et piliers

**Public :** joueurs de 9 à 16 ans, majoritairement sur mobile, qui regardent du contenu Roblox sur TikTok et YouTube Shorts.

**Les 4 piliers (toute décision doit en respecter au moins un) :**

1. **Compris en 5 secondes.** On clique, on creuse, on trouve quelque chose. Aucun tutoriel textuel.
2. **Le frisson de la trouvaille.** Chaque coup de pelle peut donner un objet Secret.
3. **La tension sociale.** Ce que tu possèdes peut être volé, ce qui donne envie de se protéger et de se venger.
4. **Filmable.** Chaque moment fort (trouvaille rare, vol réussi) a une animation et un son qu'on a envie d'enregistrer.

## 3. La boucle de jeu

**Boucle courte (30 secondes) :**

1. Creuser une case de sa parcelle.
2. Révéler l'objet (animation de rareté avec couleur et son).
3. Ranger l'objet dans son coffre ou le vendre au marchand.

**Boucle moyenne (10 minutes) :**

1. Vendre ses objets pour des Pièces.
2. Acheter une meilleure pelle (plus de chance, plus de profondeur).
3. Atteindre une nouvelle couche de terrain avec de nouveaux objets.
4. Survivre à la phase de nuit (défendre ou aller voler).

**Boucle longue (jours et semaines) :**

1. Compléter l'Index de collection (tous les objets, toutes les mutations).
2. Obtenir les objets des événements limités de la semaine.
3. Grimper dans le classement des coffres les plus riches du serveur.

## 4. Les systèmes de jeu

### 4.1 Creusage et couches de terrain

La parcelle est une grille de 8 x 8 cases. Chaque case se creuse en plusieurs coups selon la pelle. Quand toute la couche est creusée, la parcelle descend d'un niveau.

| Couche | Profondeur | Pelle minimum | Thème des objets |
| --- | --- | --- | --- |
| 1. Terre | 0 à 10 m | Pelle en bois | Déchets drôles, pièces anciennes |
| 2. Argile | 10 à 50 m | Pelle en fer | Fossiles, jouets perdus |
| 3. Roche | 50 à 200 m | Pelle en acier | Cristaux, trésors de pirates |
| 4. Lave | 200 à 1 000 m | Pelle en diamant | Reliques de feu, créatures |
| 5. Noyau | 1 000 m et plus | Pelle cosmique | Objets extraterrestres, Secrets |

Les couches 4 et 5 sont prévues pour les mises à jour après le lancement. Le MVP sort avec les couches 1 à 3.

### 4.2 Table de rareté

| Rareté | Chance de base | Couleur | Valeur de vente (Pièces) |
| --- | --- | --- | --- |
| Commun | 60 % | Gris | 10 |
| Peu commun | 25 % | Vert | 40 |
| Rare | 10 % | Bleu | 150 |
| Épique | 4 % | Violet | 600 |
| Légendaire | 0,9 % | Or | 3 000 |
| Secret | 0,1 % | Arc-en-ciel animé | 25 000 |

La pelle et les boosts de chance déplacent ces probabilités vers le haut. Un objet Secret déclenche une annonce visible par tout le serveur ("Yardley a trouvé un SECRET !"). C'est volontaire : c'est le moment que les joueurs vont filmer.

### 4.3 Mutations

Chaque objet trouvé a une petite chance de porter une mutation qui multiplie sa valeur.

| Mutation | Chance | Multiplicateur | Effet visuel |
| --- | --- | --- | --- |
| Doré | 2 % | x3 | Brillance dorée |
| Diamant | 0,5 % | x6 | Reflets bleus |
| Arc-en-ciel | 0,1 % | x15 | Couleurs animées |
| Maudit | 1 % (la nuit seulement) | x5 | Fumée noire, mais il attire les voleurs |

Un objet Secret + Arc-en-ciel est la trouvaille ultime. Elle doit être quasi impossible, mais documentée dans l'Index pour faire rêver.

### 4.4 Progression des pelles

| Pelle | Prix (Pièces) | Coups par case | Bonus de chance |
| --- | --- | --- | --- |
| Bois | Gratuite | 3 | 0 % |
| Fer | 500 | 2 | +5 % |
| Acier | 25 000 | 2 | +15 % |
| Diamant | 50 000 | 1 | +30 % |
| Cosmique | 500 000 | 1 | +60 % |

Prix de la Pelle en acier recalibré à 25 000 après la simulation d'équilibrage de la semaine 2 (5 000 la faisait arriver en 4 minutes). Les prix des pelles Diamant et Cosmique seront fixés par la même simulation quand elles seront développées.

### 4.5 Le vol (cycle jour et nuit)

- Un cycle dure 10 minutes : 8 minutes de jour, 2 minutes de nuit.
- **Le jour**, les parcelles sont protégées. On creuse en paix.
- **La nuit**, chaque joueur peut entrer sur une parcelle voisine et tenter d'ouvrir le coffre (mini-jeu de crochetage de 5 secondes). S'il réussit, il repart avec UN objet au hasard du coffre.
- Le propriétaire peut toucher le voleur pour l'éjecter et lui faire perdre l'objet.
- **Garde-fous anti-frustration** (décision ferme, c'est ce qui garde les joueurs) : un joueur ne peut perdre qu'un seul objet par nuit ; les objets Secrets ne peuvent pas être volés, seulement exposés ; les nouveaux joueurs sont protégés pendant leurs 20 premières minutes ; les joueurs hors ligne ne perdent rien.
- Chaque vol réussi rapporte aussi des Points de Voleur qui débloquent des cosmétiques (masques, sacs).

### 4.6 Événements de serveur

- **Pluie de météorites** (toutes les 30 minutes) : chance de Rare et plus doublée pendant 3 minutes.
- **Nuit de sang** (aléatoire) : la nuit dure 4 minutes et les mutations Maudites tombent trois fois plus.
- **Événement chance acheté** : un joueur paie pour booster tout le serveur (voir Monétisation). Son nom s'affiche en grand.

## 5. Monétisation

**Principe directeur :** on vend du temps, de la chance, de la protection et du statut. On ne vend jamais un objet Secret directement, sinon la collection perd sa valeur.

### 5.1 Game passes (achat unique)

| Game pass | Prix (Robux) | Ce qu'il fait |
| --- | --- | --- |
| Coffre agrandi | 149 | Double la capacité du coffre |
| Chance x2 | 299 | Double en permanence les chances de Rare et plus |
| Creusage auto | 449 | La pelle creuse seule pendant que le joueur fait autre chose |
| VIP | 399 | Badge doré, salon VIP, +10 % de Pièces à la vente |
| Garde du corps | 349 | Un garde PNJ ralentit les voleurs sur ta parcelle |

### 5.2 Developer products (achats répétables)

| Produit | Prix (Robux) | Ce qu'il fait |
| --- | --- | --- |
| Potion de chance (10 min) | 39 | Chance x3 pendant 10 minutes |
| Bouclier anti-vol (1 nuit) | 49 | Ton coffre est impossible à ouvrir pour la prochaine nuit |
| Pack de Pièces | 99 à 999 | Pièces instantanées (paliers) |
| Événement chance (serveur) | 249 | Chance x2 pour TOUT le serveur pendant 5 minutes, avec ton nom affiché |
| Revanche | 29 | Téléporte sur la parcelle de ton dernier voleur pendant la nuit suivante |

Le Bouclier, la Revanche et l'Événement chance sont les trois produits clés : ils sont émotionnels et se rachètent sans fin.

### 5.3 Ce que ça peut rapporter (hypothèses à valider)

Taux de conversion standard du Developer Exchange : 0,0038 $ US par Robux gagné. Minimum pour encaisser : 30 000 Robux.

Le tableau ci-dessous repose sur une hypothèse prudente de 1 Robux gagné par joueur actif par jour. Ce chiffre n'est pas une promesse : il servira de point de comparaison dès qu'on aura les vraies données du jeu.

| Joueurs actifs par jour | Robux gagnés par mois | Revenu mensuel estimé (USD) |
| --- | --- | --- |
| 5 000 | 150 000 | 570 $ |
| 20 000 | 600 000 | 2 280 $ |
| 100 000 | 3 000 000 | 11 400 $ |
| 500 000 | 15 000 000 | 57 000 $ |

Un jeu qui passe dans les tendances peut dépasser largement ces chiffres. Le vrai levier n'est pas le prix des objets, c'est le nombre de joueurs et leur rétention.

## 6. Rétention

- **Récompense quotidienne** sur 7 jours, avec une potion de chance gratuite au jour 7.
- **Index de collection** : récompenses à 25 %, 50 %, 75 % et 100 % de chaque couche.
- **3 quêtes par jour** ("Trouve 2 objets Rares", "Réussis un vol").
- **Mise à jour chaque semaine** (nouvel objet limité, nouvel événement). C'est non négociable : les jeux du sommet fonctionnent comme des jeux à service continu.
- **Bonus de groupe Roblox** : +5 % de chance pour les membres du groupe Konbit Games. Ça construit une audience qu'on garde pour les prochains jeux.

## 7. Viralité et plan de lancement

**Avant le lancement (2 semaines) :**

1. Créer un compte TikTok et YouTube Shorts dédié au jeu.
2. Publier 1 à 2 courtes vidéos par jour du développement (trouvailles rares, vols ratés).
3. Ouvrir un serveur Discord avec des codes promo exclusifs au lancement.

**Semaine du lancement :**

1. Lancement un vendredi après-midi (heure de l'Est), quand les joueurs sont en congé.
2. Codes promo publiés uniquement sur TikTok et Discord.
3. Petit budget de publicités sponsorisées sur Roblox pour obtenir les premiers joueurs et alimenter l'algorithme.
4. Tester 3 icônes et 3 miniatures différentes, garder celles qui ont le meilleur taux de clic.
5. Contacter 10 à 20 petits créateurs Roblox (5 000 à 50 000 abonnés) avec un code créateur et un objet exclusif à leur nom.

**Après le lancement :** chaque vendredi, une mise à jour et une vidéo qui l'annonce.

## 8. Feuille de route du MVP (6 semaines)

| Semaine | Objectif | Livrable |
| --- | --- | --- |
| 1 | Creusage de base | Parcelle 8 x 8, pelle, révélation d'objet, sauvegarde DataStore |
| 2 | Économie | Rareté, mutations, coffre, marchand, pelles 1 à 3 |
| 3 | Social | Cycle jour et nuit, vol, éjection, garde-fous |
| 4 | Monétisation et rétention | Game passes, developer products, quêtes, récompenses quotidiennes, Index |
| 5 | Polish et viralité | Animations de rareté, sons, annonces serveur, événement météorites, interface mobile |
| 6 | Test et lancement | Test fermé avec 20 à 50 joueurs, corrections, icônes, publication |

## 9. Indicateurs à surveiller

Ces cibles sont des objectifs internes, pas des moyennes de l'industrie. Elles servent à décider vite si on continue, on corrige ou on change de jeu.

| Indicateur | Cible | Si on rate la cible |
| --- | --- | --- |
| Rétention jour 1 | 25 % ou plus | Revoir les 5 premières minutes de jeu |
| Rétention jour 7 | 8 % ou plus | Ajouter des objectifs à moyen terme |
| Durée moyenne de session | 15 minutes ou plus | Rendre la boucle courte plus gratifiante |
| Taux de joueurs payeurs | 2 % ou plus | Revoir les prix et l'emplacement des offres |
| Taux de clic de l'icône | À comparer entre les variantes | Changer l'icône et la miniature |

**Règle de décision :** si après 30 jours et 3 mises à jour la rétention jour 1 reste sous 15 %, on arrête et on passe au plan B (Le Dernier Phare) en réutilisant le code de sauvegarde, de monétisation et d'interface.

## 10. Risques et parades

| Risque | Parade |
| --- | --- |
| Le vol frustre et fait fuir les joueurs | Garde-fous de la section 4.5 et protection des nouveaux joueurs |
| Exploits et triche (duplication d'objets) | Toute la logique de rareté, de vol et d'achat côté serveur, jamais côté client |
| Perte de données | Sauvegarde automatique toutes les 60 secondes et à la déconnexion |
| Le jeu ne décolle pas | Règle de décision de la section 9 et plan B prêt |
| Un jeu similaire sort avant nous | Lancer le MVP vite (6 semaines) et se démarquer par les mutations et les événements |

## 11. Décisions prises

- Jeu choisi : **Creuse ou Crève**, publié sous le studio Konbit Games.
- Mobile en priorité.
- MVP en 6 semaines avec 3 couches de terrain.
- On ne vend jamais d'objet Secret directement.
- Un seul objet volable par nuit, Secrets protégés.
- Mise à jour chaque vendredi après le lancement.
- Plan B : Le Dernier Phare.
