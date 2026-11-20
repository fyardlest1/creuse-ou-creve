# Creuse ou Crève : textes des produits et badges (FR / EN)

Nov 19, 2026 · @Yardley Estiverne

## Comment utiliser ce document

1. Sur le Creator Hub, crée chaque produit avec le **nom** et la **description en français** (la langue source du jeu).
2. Ajoute ensuite l'anglais dans **Localization** (page du jeu, Audience, puis Localization) : Roblox affichera automatiquement la version anglaise aux joueurs anglophones.
3. Les prix sont ceux du plan de la semaine 4. Ne change pas un effet ici sans le changer aussi dans le plan.

Règles suivies pour tous les textes : l'effet exact en première phrase, aucune promesse que le jeu ne tient pas, et aucune mention de "garantie" de trouver un objet rare.

## Guide : créer les produits sur le Creator Hub

**Avant de commencer :** prépare une icône par produit, en .png ou .jpg, de 512 x 512 pixels maximum. Roblox la recadre en cercle : garde le dessin et le texte au centre. Une icône simple (fond de couleur et un symbole) suffit pour l'instant, on fera les vraies au polish.

### A. Les 5 game passes

1. Va sur create.roblox.com, puis **Creations**, et clique sur "Creuse ou Crève".
2. Dans le menu de gauche : **Monetization**, puis **Passes**, puis **Create pass**.
3. Envoie l'icône, puis colle le **nom** et la **description en français** de ce document.
4. Choisis une catégorie (elle sert à ranger le pass dans la boutique du jeu), puis clique sur **Create pass**.
5. Ouvre le pass que tu viens de créer, va dans ses réglages de vente, active la vente et entre le prix en Robux de ce document. Enregistre.
6. Pour l'identifiant : retourne dans **Monetization**, puis **Passes**, survole l'image du pass, clique sur **⋯** puis **Copy Asset ID**. Colle-le dans le tableau à la fin de ce guide.
7. Recommence pour les 4 autres passes.

### B. Les 8 developer products

1. Toujours dans le jeu : **Monetization**, puis **Developer Products**, puis **Create developer product**.
2. Envoie l'icône, puis colle le nom et la description en français.
3. Choisis une catégorie et entre le **prix en Robux** directement dans ce formulaire.
4. Clique sur **Save Changes**.
5. Pour l'identifiant : **Developer Products**, survole l'image, **⋯**, puis **Copy Asset ID**.
6. Recommence pour les 7 autres. Les 4 packs de Pièces sont 4 produits séparés.

### C. Les 7 badges

**Attention au coût :** chaque jeu a droit à **5 badges gratuits par période de 24 heures** (heure GMT), et chaque badge supplémentaire coûte 100 Robux. Crée donc les 5 premiers aujourd'hui, et les 2 derniers (Explorateur de la Roche, Archéologue de la Terre) demain.

1. Sur le tableau de bord (Creations), survole la vignette de "Creuse ou Crève", clique sur **⋯** puis **Create Badge**.
2. Envoie une icône de 512 x 512 pixels, avec le dessin au centre.
3. Colle le nom et la description en français, et laisse **Badge is Enabled** activé.
4. Clique sur **Create Badge**.
5. Pour l'identifiant : dans le jeu, **Engagement**, puis **Badges**, survole l'image, **⋯**, puis **Copy Asset ID**.

### D. Les traductions anglaises

Une fois tout créé : dans le jeu, **Audience**, puis **Localization**. Ajoute l'anglais comme langue, puis entre les noms et descriptions anglaises de ce document pour chaque produit et badge.

### E. Tableau des identifiants à envoyer à Claude Code

| Produit | Type | Identifiant |
| --- | --- | --- |
| Coffre agrandi | Game pass |  |
| Chance x2 | Game pass |  |
| Creusage auto | Game pass |  |
| VIP | Game pass |  |
| Garde du corps | Game pass |  |
| Potion de chance | Developer product |  |
| Bouclier anti-vol | Developer product |  |
| Bourse de Pièces | Developer product |  |
| Sac de Pièces | Developer product |  |
| Coffret de Pièces | Developer product |  |
| Trésor de Pièces | Developer product |  |
| Événement chance | Developer product |  |
| Revanche | Developer product |  |
| Premier coup de pelle | Badge |  |
| Premier Secret | Badge |  |
| Voleur de l'ombre | Badge |  |
| Gardien du coffre | Badge |  |
| Explorateur de l'Argile | Badge |  |
| Explorateur de la Roche | Badge (demain) |  |
| Archéologue de la Terre | Badge (demain) |  |
| Groupe Konbit Games | Groupe (si créé) |  |

Quand le tableau est rempli, copie-le et envoie-le à Claude Code en lui disant de brancher ces identifiants dans MonetizationConfig.luau et RetentionConfig.luau (tâche 10 de la semaine 4).

## Game passes

### Coffre agrandi / Bigger Chest (149 Robux)

**FR :** Double la taille de ton coffre : 60 places au lieu de 30. Moins d'allers-retours au Marchand, plus de temps à creuser.

**EN:** Doubles your chest size: 60 slots instead of 30. Fewer trips to the Merchant, more time digging.

### Chance x2 / 2x Luck (299 Robux)

**FR :** Double pour toujours tes chances de déterrer des objets Rares, Épiques, Légendaires et Secrets. Se cumule avec ta pelle et tes potions (bonus total limité à x10).

**EN:** Permanently doubles your chances of digging up Rare, Epic, Legendary and Secret items. Stacks with your shovel and potions (total bonus capped at 10x).

### Creusage auto / Auto Dig (449 Robux)

**FR :** Ta pelle creuse toute seule ta parcelle pendant que tu vends, défends ton coffre ou discutes. Active-le ou coupe-le quand tu veux depuis l'écran. S'arrête quand ton coffre est plein.

**EN:** Your shovel digs your plot on its own while you sell, guard your chest or chat. Turn it on or off anytime from the screen. Stops when your chest is full.

### VIP (399 Robux)

**FR :** +10 % de Pièces sur toutes tes ventes, une étiquette VIP dorée au-dessus de ton personnage et dans le chat. Tout le monde saura qui est le patron du chantier.

**EN:** +10% Coins on every sale, plus a golden VIP tag above your character and in chat. Everyone will know who runs the dig site.

### Garde du corps / Bodyguard (349 Robux)

**FR :** Un garde se poste près de ton coffre. Les voleurs mettent 8 secondes à le crocheter au lieu de 5 : largement le temps de les attraper.

**EN:** A guard stands watch by your chest. Thieves need 8 seconds to pick it instead of 5: plenty of time to catch them.

## Developer products

### Potion de chance / Luck Potion (39 Robux)

**FR :** Tes chances de trouver des objets Rares et mieux sont multipliées par 3 pendant 10 minutes. Si une potion est déjà active, le temps s'ajoute.

**EN:** Triples your chances of finding Rare or better items for 10 minutes. If a potion is already active, the time adds up.

### Bouclier anti-vol / Anti-Theft Shield (49 Robux)

**FR :** Personne ne peut crocheter ton coffre pendant une nuit entière : la nuit en cours si tu l'achètes la nuit, sinon la prochaine. Dors tranquille.

**EN:** Nobody can pick your chest for one full night: the current night if you buy it at night, otherwise the next one. Sleep easy.

### Bourse de Pièces / Coin Pouch (99 Robux)

**FR :** 5 000 Pièces, ajoutées tout de suite.

**EN:** 5,000 Coins, added instantly.

### Sac de Pièces / Coin Bag (249 Robux)

**FR :** 15 000 Pièces, ajoutées tout de suite.

**EN:** 15,000 Coins, added instantly.

### Coffret de Pièces / Coin Chest (499 Robux)

**FR :** 35 000 Pièces, ajoutées tout de suite. De quoi t'offrir la Pelle en acier.

**EN:** 35,000 Coins, added instantly. Enough for the Steel Shovel.

### Trésor de Pièces / Coin Vault (999 Robux)

**FR :** 80 000 Pièces, ajoutées tout de suite. Le meilleur rapport Pièces par Robux.

**EN:** 80,000 Coins, added instantly. The best Coins per Robux.

### Événement chance / Server Luck Event (249 Robux)

**FR :** Double les chances de TOUT le serveur pendant 5 minutes, avec ton nom affiché en grand chez chaque joueur. Un seul événement à la fois.

**EN:** Doubles luck for the WHOLE server for 5 minutes, with your name shown big on every player's screen. One event at a time.

### Revanche / Revenge (29 Robux)

**FR :** La nuit seulement : téléporte-toi devant le coffre de ton dernier voleur pour lui rendre la pareille. Les règles normales du vol s'appliquent. Si ton voleur n'est plus disponible, tu reçois une Potion de chance à la place.

**EN:** Night only: teleport to your last thief's chest and pay them back. Normal stealing rules apply. If your thief is no longer available, you get a Luck Potion instead.

## Badges

### Premier coup de pelle / First Dig

**FR :** Tu as donné ton premier coup de pelle. Le trésor t'attend.

**EN:** You swung your shovel for the first time. Treasure awaits.

### Premier Secret / First Secret

**FR :** Tu as déterré un objet Secret, l'objet le plus rare du jeu. Une chance sur mille !

**EN:** You dug up a Secret item, the rarest item in the game. A one in a thousand find!

### Voleur de l'ombre / Shadow Thief

**FR :** Tu as réussi ton premier vol. Personne ne t'a vu venir.

**EN:** You pulled off your first steal. Nobody saw you coming.

### Gardien du coffre / Chest Guardian

**FR :** Tu as éjecté un voleur en plein crochetage. Pas touche à ton trésor !

**EN:** You kicked out a thief mid-lockpick. Hands off your treasure!

### Explorateur de l'Argile / Clay Explorer

**FR :** Tu as atteint l'Argile, à 10 mètres de profondeur.

**EN:** You reached the Clay layer, 10 meters down.

### Explorateur de la Roche / Rock Explorer

**FR :** Tu as atteint la Roche, à 50 mètres de profondeur. Les vrais trésors commencent ici.

**EN:** You reached the Rock layer, 50 meters down. The real treasure starts here.

### Archéologue de la Terre / Dirt Archaeologist

**FR :** Tu as complété l'Index de la Terre : tous ses objets sont dans ta collection.

**EN:** You completed the Dirt Index: every item from the layer is in your collection.
