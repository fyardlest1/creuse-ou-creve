# Creuse ou Crève : prompts des icônes (produits et badges)

Prompts pour créer les 20 icônes avec Nano Banana (ou tout autre générateur d'images). Les noms de fichiers correspondent à ceux de `assets/icons/`, où se trouvent déjà des icônes provisoires générées par script (`assets/icons/make_icons.py`).

## Réglages communs

| Réglage          | Valeur                                                                                                                                                                                                                |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Rapport d'aspect | **1:1** (carré)                                                                                                                                                                                                       |
| Taille finale    | **512 x 512 pixels** maximum (réduis l'image si le générateur sort plus grand)                                                                                                                                        |
| Format           | PNG (ou JPG)                                                                                                                                                                                                          |
| Zone utile       | Roblox recadre l'icône **en cercle** : sujet et texte au centre, dans les 70 % du milieu                                                                                                                              |
| Texte            | Seulement les libellés indiqués (chiffres ou mots courts, compris en français comme en anglais). Les générateurs écrivent parfois mal : vérifie l'orthographe, sinon régénère, ou ajoute le texte toi-même après coup |

### Bloc de style à coller au début de chaque prompt

Pour que les 20 icônes forment une famille cohérente, commence chaque prompt par ce bloc :

```text
Square 1:1 game icon for a cheerful Roblox digging game. Bold cartoon style, thick clean outlines, soft cel shading, bright saturated colors, smooth radial gradient background, single centered subject filling about 60% of the frame, everything important kept inside the central circle, no border, no watermark, no extra text.
```

Puis ajoute la ligne propre à l'icône (ci-dessous). Pour les **badges**, ajoute aussi :

```text
Medal style: a thick shiny golden ring around the circle.
```

## Game passes (5)

| Fichier                   | Produit        | Prompt (après le bloc de style)                                                                                                                                                                        |
| ------------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `passes/bigger_chest.png` | Coffre agrandi | `A big overflowing wooden treasure chest with golden trim, twice its normal size, coins and gems spilling out. Large bold white text "60" with a dark outline under the chest. Warm brown background.` |
| `passes/luck_x2.png`      | Chance x2      | `A glowing four-leaf clover with little sparkles. Large bold white text "x2" with a dark outline under it. Emerald green background.`                                                                  |
| `passes/auto_dig.png`     | Creusage auto  | `A magic shovel digging the ground by itself, with small motion lines and flying dirt, no hands. Bold white text "AUTO" with a dark outline under it. Bright orange background.`                       |
| `passes/vip.png`          | VIP            | `A shiny golden crown with red and blue jewels. Large bold white text "VIP" with a dark outline under it. Golden yellow background.`                                                                   |
| `passes/bodyguard.png`    | Garde du corps | `A friendly cartoon bodyguard with sunglasses and crossed arms standing in front of a small wooden treasure chest. Deep navy blue background.`                                                         |

## Developer products (8)

| Fichier                          | Produit           | Prompt (après le bloc de style)                                                                                                                                                    |
| -------------------------------- | ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `products/luck_potion.png`       | Potion de chance  | `A round glass potion bottle with bubbling glowing green liquid and a four-leaf clover label. Large bold white text "x3" with a dark outline under it. Purple background.`         |
| `products/anti_theft_shield.png` | Bouclier anti-vol | `A glowing blue protective shield in front of a closed wooden treasure chest with a padlock. Bright blue background.`                                                              |
| `products/coin_pouch.png`        | Bourse de Pièces  | `A small leather pouch with a few gold coins. Large bold white text "5K" with a dark outline under it. Light gold background.`                                                     |
| `products/coin_bag.png`          | Sac de Pièces     | `A medium burlap money bag full of gold coins. Large bold white text "15K" with a dark outline under it. Gold background.`                                                         |
| `products/coin_chest.png`        | Coffret de Pièces | `A small open treasure box overflowing with gold coins. Large bold white text "35K" with a dark outline under it. Deep gold-orange background.`                                    |
| `products/coin_vault.png`        | Trésor de Pièces  | `A huge mountain of gold coins with gems and a sparkling diamond on top, the biggest treasure. Large bold white text "80K" with a dark outline under it. Rich orange background.`  |
| `products/server_luck_event.png` | Événement chance  | `A big shining golden star with fireworks and confetti bursting around it, a festive party feeling. Large bold white text "x2" with a dark outline under it. Hot pink background.` |
| `products/revenge.png`           | Revanche          | `Two crossed cartoon swords in front of a small treasure chest, with a mischievous energy, nothing violent or bloody. Red background.`                                             |

Les quatre packs de Pièces montent en puissance (bourse, sac, coffret, montagne de pièces) pour que le joueur voie tout de suite lequel est le plus gros.

## Badges (7)

Ajoute le bloc « Medal style » à chacun de ces prompts.

| Fichier                         | Badge                   | Prompt (après le bloc de style et le bloc médaille)                                                                                                         |
| ------------------------------- | ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `badges/first_dig.png`          | Premier coup de pelle   | `A shovel plunged into a small mound of brown dirt with a few flying clods. Earthy brown background.`                                                       |
| `badges/first_secret.png`       | Premier Secret          | `A mysterious glowing cosmic egg radiating rainbow light, very rare and magical. Dark purple starry background.`                                            |
| `badges/shadow_thief.png`       | Voleur de l'ombre       | `A sneaky cartoon thief in a black hood and mask, tiptoeing with a small bag, friendly and playful. Dark night-blue background with a moon.`                |
| `badges/chest_guardian.png`     | Gardien du coffre       | `A treasure chest locked with a big golden padlock, a confident hand raised in a "stop" gesture in front of it. Teal green background.`                     |
| `badges/clay_explorer.png`      | Explorateur de l'Argile | `A fossil bone and a small ammonite shell sticking out of orange clay. Brick orange background.`                                                            |
| `badges/rock_explorer.png`      | Explorateur de la Roche | `A grey boulder cracked open revealing glowing purple and blue crystals inside. Slate grey background.`                                                     |
| `badges/dirt_archaeologist.png` | Archéologue de la Terre | `A magnifying glass over an open archaeologist's notebook full of little item sketches, with a brush and a small trowel. Light brown parchment background.` |

## Contrôle avant d'envoyer sur le Creator Hub

1. L'image est carrée et fait 512 x 512 pixels au plus.
2. Recadrée en cercle, rien d'important n'est coupé (texte et sujet au centre).
3. Le texte, s'il y en a un, est exactement celui demandé (« 60 », « x2 », « AUTO », « VIP », « x3 », « 5K », « 15K », « 35K », « 80K »).
4. Pas de logo, de marque ou de personnage connu (règles de Roblox et droits d'auteur).
5. Lisible en petit : regarde l'icône réduite à la taille d'un pouce.
