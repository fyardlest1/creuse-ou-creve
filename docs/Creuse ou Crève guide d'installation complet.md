# Creuse ou Crève : guide d'installation complet

Nov 19, 2026 · @Yardley Estiverne

Ce guide est écrit pour Windows. Suis les étapes dans l'ordre et coche chaque case de la checklist finale avant de commencer à coder. Toutes les commandes se tapent dans **PowerShell** (ou le terminal intégré de VS Code).

## 0. Ce que tu as déjà

- [x] VS Code
- [x] Roblox Studio
- [x] Extension Rojo dans VS Code
- [x] Extension Luau Language Server dans VS Code

Important : l'extension Rojo de VS Code n'est qu'une interface. Il te manque encore **le programme Rojo lui-même** (le serveur de synchronisation) et **le plugin Rojo dans Studio**. Sans ces deux pièces, rien ne se synchronise. Les étapes ci-dessous les installent.

## 1. Installer Git

1. Télécharge **Git for Windows** sur git-scm.com et installe-le avec les options par défaut.
2. Ferme et rouvre PowerShell, puis vérifie :

```powershell
git --version
```

3. Configure ton identité (une seule fois) :

```powershell
git config --global user.name "Yardley"
git config --global user.email "ton-courriel@exemple.com"
```

4. Assure-toi d'avoir un compte **GitHub**. On y mettra le projet dans un dépôt privé.

## 2. Installer Rokit (le gestionnaire d'outils)

Rokit installe Rojo et garde la même version des outils pour tout le projet. C'est la méthode recommandée par la documentation officielle de Roblox.

1. Dans PowerShell, lance :

```powershell
Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
```

2. **Ferme et rouvre PowerShell**, et si la commande n'est toujours pas reconnue, redémarre l'ordinateur (l'installateur le demande pour mettre à jour le PATH).
3. Vérifie :

```powershell
rokit --version
```

Si le script est bloqué par Windows : télécharge `rokit.exe` sur la page des releases de github.com/rojo-rbx/rokit et double-clique dessus.

## 3. Créer le dossier du projet (hors OneDrive)

Ne mets **pas** le projet dans un dossier OneDrive. OneDrive verrouille et resynchronise les fichiers pendant que Rojo et Git travaillent, ce qui cause des conflits et des fichiers corrompus.

```powershell
mkdir C:\dev\creuse-ou-creve
cd C:\dev\creuse-ou-creve
```

**Avant de taper des commandes, deux pièges à éviter :**

- **Ne travaille pas dans `C:\WINDOWS\system32`.** C'est le dossier où s'ouvre PowerShell quand il est lancé en administrateur. Ouvre un PowerShell **normal** et fais toujours `cd` vers le dossier du projet avant de lancer `rokit`, `rojo`, `git` ou `code .`. Sinon, les fichiers se créent au mauvais endroit.
- **Tape ou colle les commandes une par une**, en appuyant sur Entrée après chacune. Si plusieurs commandes se retrouvent sur la même ligne, PowerShell affiche l'erreur `A positional parameter cannot be found` et ne fait rien.

**Si tu as déjà créé le projet dans OneDrive, déplace-le :**

1. Ferme VS Code (File, puis Close Folder), Roblox Studio et toute fenêtre de l'explorateur Windows ouverte sur ce dossier.
2. Dans un PowerShell normal, tape ces commandes une par une :

```powershell
mkdir C:\dev
```

```powershell
Move-Item "C:\Users\fyard\OneDrive\Desktop\MOBILE-DEV\creuse-ou-creve" "C:\dev\creuse-ou-creve"
```

```powershell
cd C:\dev\creuse-ou-creve
```

```powershell
dir
```

3. `dir` doit afficher les fichiers du projet (`default.project.json`, `rokit.toml`, le dossier `src`). Ouvre ensuite le projet :

```powershell
code .
```

4. Dans le terminal de VS Code, vérifie que `rojo --version` et `git status` répondent.
5. Si `Move-Item` affiche une erreur, c'est presque toujours qu'un programme a encore le dossier ouvert : ferme-le et relance la commande.
6. Garde un seul dossier de projet, `creuse-ou-creve`, **sans accent**. Supprime les doublons (par exemple `Creuse-ou-Crève`) : certains outils en ligne de commande gèrent mal les accents dans les chemins.

## 4. Installer Rojo et StyLua dans le projet

```powershell
rokit init
rokit add rojo-rbx/rojo
rokit add JohnnyMorganz/StyLua
```

Vérifie :

```powershell
rojo --version
stylua --version
```

Un fichier `rokit.toml` apparaît dans le dossier : il fixe les versions des outils. Il sera sauvegardé dans Git.

**StyLua** formate automatiquement ton code Luau à chaque sauvegarde. C'est l'équivalent de Prettier.

## 5. Initialiser le projet Rojo

1. Dans le dossier du projet :

```powershell
rojo init
```

2. Ouvre le dossier dans VS Code :

```powershell
code .
```

3. Remplace tout le contenu de `default.project.json` par celui-ci :

```json
{
  "name": "creuse-ou-creve",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "$ignoreUnknownInstances": true,
      "Shared": { "$path": "src/shared" }
    },
    "ServerScriptService": {
      "$ignoreUnknownInstances": true,
      "Server": { "$path": "src/server" }
    },
    "StarterPlayer": {
      "$ignoreUnknownInstances": true,
      "StarterPlayerScripts": {
        "$ignoreUnknownInstances": true,
        "Client": { "$path": "src/client" }
      }
    },
    "Workspace": {
      "$ignoreUnknownInstances": true
    }
  }
}
```

Pourquoi `$ignoreUnknownInstances` partout : Rojo gère **uniquement le code**. La carte, les modèles 3D et tout ce que tu construis dans Studio restent dans Studio. Sans cette option, Rojo pourrait effacer ce que tu as construit à la main.

4. Vérifie que ces trois dossiers existent (crée-les sinon) : `src/server`, `src/client`, `src/shared`.
5. Crée deux scripts de test :

`src/server/Hello.server.luau`

```lua
print("[Serveur] Creuse ou Creve est pret")
```

`src/client/Hello.client.luau`

```lua
print("[Client] Connexion au jeu reussie")
```

Règle de nommage à retenir : `.server.luau` = Script serveur, `.client.luau` = LocalScript, `.luau` seul = ModuleScript.

## 6. Installer le plugin Rojo dans Roblox Studio

1. Ferme Roblox Studio s'il est ouvert.
2. Dans PowerShell :

```powershell
rojo plugin install
```

3. Rouvre Studio. Un bouton **Rojo** doit apparaître dans l'onglet **Plugins**.

**Attention, deux pièges fréquents :**

- **L'onglet Plugins n'apparaît qu'une fois une place ouverte.** Sur l'écran d'accueil de Studio (Recents, Home, Experiences), il n'y a pas de ruban. Ouvre une place existante ou un Baseplate vide pour voir l'onglet **Plugins** et le bouton **Rojo**.
- **"Manage Plugins" n'affiche pas Rojo.** Cette fenêtre liste seulement les plugins installés depuis le Marketplace. Rojo est installé en fichier local. Pour vérifier qu'il est bien là : menu **Plugins**, puis **Plugins Folder**. Tu dois y voir le fichier `RojoManagedPlugin.rbxm`.

`rojo plugin install` n'affiche aucun message quand l'installation réussit. C'est normal.

Le plugin et le serveur doivent avoir la même version majeure. En installant le plugin avec cette commande, c'est garanti.

## 7. Configurer VS Code

**Extensions à avoir (onglet Extensions, Ctrl+Shift+X) :**

- [x] Rojo (déjà installée)
- [x] Luau Language Server (déjà installée)
- [x] StyLua (de JohnnyMorganz)

**Réglages du projet :** crée le fichier `.vscode/settings.json` à la racine du projet :

```json
{
  "luau-lsp.sourcemap.enabled": true,
  "luau-lsp.sourcemap.rojoProjectFile": "default.project.json",
  "luau-lsp.platform.type": "roblox",
  "editor.formatOnSave": true,
  "[luau]": {
    "editor.defaultFormatter": "JohnnyMorganz.stylua"
  },
  "[lua]": {
    "editor.defaultFormatter": "JohnnyMorganz.stylua"
  }
}
```

Avec la sourcemap activée, Luau Language Server comprend la structure Rojo du projet : l'autocomplétion fonctionne sur `game.ReplicatedStorage.Shared`, et les erreurs s'affichent en direct.

**Désactive Auto Save** (menu File, décoche Auto Save) et sauvegarde avec **Ctrl+S**. Avec Auto Save, StyLua ne formate pas ton code, et Rojo envoie dans Studio du code à moitié tapé, ce qui provoque des erreurs inutiles.

## 8. Mettre le projet sur Git et GitHub

1. Remplace le contenu de `.gitignore` par :

```
*.rbxl
*.rbxlx
*.rbxl.lock
*.rbxlx.lock
sourcemap.json
Packages/
```

On n'envoie jamais les fichiers de place `.rbxl` sur Git : la carte vit sur Roblox, le code vit sur Git.

2. Premier commit :

```powershell
git init
git add .
git commit -m "Initialisation du projet Creuse ou Creve"
```

3. Sur github.com, crée un dépôt **privé** nommé `creuse-ou-creve`, **sans** README ni .gitignore (le projet en a déjà).
4. Relie-le et envoie le code (remplace `TON-COMPTE`) :

```powershell
git branch -M main
git remote add origin https://github.com/TON-COMPTE/creuse-ou-creve.git
git push -u origin main
```

## 9. Premier test de synchronisation

1. Construis un fichier de place de départ :

```powershell
rojo build -o creuse-ou-creve.rbxl
```

2. Ouvre `creuse-ou-creve.rbxl` dans Roblox Studio (double-clic).
3. Dans VS Code, démarre le serveur de synchro :

```powershell
rojo serve
```

Laisse ce terminal ouvert pendant que tu travailles.

4. Dans Studio : onglet **Plugins**, bouton **Rojo**, puis **Connect**.
5. Ouvre la fenêtre **Output** (onglet View, puis Output) et clique sur **Play**. Tu dois voir les deux messages `[Serveur]` et `[Client]`.
6. Arrête le test. Dans VS Code, change le texte du message serveur et sauvegarde. Relance Play : le nouveau message doit apparaître **sans rien copier-coller**. Si c'est le cas, la synchro fonctionne.

## 10. Publier la place et activer les services

**Réglages à choisir dans la fenêtre Publish Experience :**

| Champ | Choix | Pourquoi |
| --- | --- | --- |
| Name | Creuse ou Crève | Le nom du jeu |
| Description | À laisser vide pour l'instant | On l'écrira avant le lancement public |
| Creator | Me | Le jeu reste privé pendant le développement. Le code est dans Git et la carte peut être sauvegardée en fichier, donc on pourra republier sous le groupe Konbit Games avant le lancement sans rien perdre |
| Devices | Computer, Phone, Tablet cochés. VR et Console décochés | Mobile en priorité. L'interface ne sera pas testée en VR ni sur console au lancement |
| Team Create | Désactivé | Tu travailles seul. Le code est sauvegardé par Git, et Team Create peut entrer en conflit avec Rojo sur les scripts |
| Data Sharing | Désactivé | Les données du jeu ne servent pas à entraîner les modèles d'IA de Roblox |

Puis clique sur **Next**.

Une fenêtre **Manage audience** s'ouvre ensuite ("ready to test!"). Ne clique ni sur **Invite** ni sur **Release publicly** : clique seulement sur **Done**. Le jeu reste visible uniquement par toi.

1. Dans Studio : **File**, puis **Publish (Alt+P)**. Nom : "Creuse ou Crève". Laisse le jeu **privé** pour l'instant.
2. Si tu as déjà créé le groupe Roblox "Konbit Games", publie sous le groupe plutôt que sous ton compte personnel. C'est plus simple pour gérer les revenus et ajouter des collaborateurs plus tard.
3. **File, puis Experience Settings**, puis **Security** : active **Enable Studio Access to API Services**. Sans ça, les sauvegardes DataStore ne fonctionnent pas pendant les tests dans Studio.
4. Récupère le **Place ID** (dans l'URL de la page du jeu sur roblox.com, ou en tapant print(game.PlaceId) dans la Command Bar de Studio, onglet View, puis Command Bar. Experience Settings ne l'affiche plus) et ajoute-le dans `default.project.json`, juste sous `"name"` :

```json
"servePlaceIds": [123456789],
```

Avec ça, Rojo refuse de se connecter à une autre place par erreur.

Enregistre ce changement dans Git, une commande à la fois :

```bash
git add .
```

```bash
git commit -m "Ajout du Place ID et configuration de la synchro"
```

```bash
git push
```

Puis refais le test de l'étape 9, cette fois avec la place publiée : `rojo serve` dans VS Code, puis dans Studio **File > Open from Roblox**, "Creuse ou Crève", **Plugins > Rojo > Connect**, puis **Play**. Les messages `[Serveur]` et `[Client]` doivent apparaître dans Output.

5. À partir de maintenant, ouvre toujours **la place publiée** dans Studio (File, puis Open from Roblox), et non le fichier `.rbxl`. Tu peux supprimer le fichier `.rbxl` local.

## 11. Brancher Claude sur Roblox Studio (MCP)

C'est ce qui me permet de lire et d'écrire les scripts directement dans ton Studio, et de lancer les tests moi-même.

On utilise **Claude Code** (la version de Claude qui tourne dans le terminal). C'est le client proposé par la connexion rapide de Studio, et il travaille directement dans le dossier du projet, à côté de Rojo.

1. Installe Claude Code. Dans un PowerShell normal :

```powershell
irm https://claude.ai/install.ps1 | iex
```

2. Ferme et rouvre le terminal, puis lance `claude` une première fois pour te connecter avec ton compte Claude. Quitte ensuite avec `/exit`.
3. Dans Roblox Studio, ouvre **Assistant**, clique sur **…**, puis **Manage MCP Servers**.
4. Active **Enable Studio as MCP server**.
5. Désactive **Data access** (le partage de tes prompts avec Roblox), comme pour Data Sharing à la publication.
6. Dans **Quick connect**, ouvre **Claude Code CLI** et copie la commande avec l'icône de copie (ne la retape pas, elle est longue).
7. Dans le terminal de VS Code, place-toi dans le dossier du projet et colle la commande :

```powershell
cd C:\dev\creuse-ou-creve
```

Colle la commande **dans PowerShell, jamais dans Git Bash**, et ajoute `-s user` juste après `claude mcp add` pour qu'elle fonctionne dans tous les dossiers. La commande complète :

```powershell
claude mcp add -s user --transport stdio Roblox_Studio -- "cmd.exe" "/c" "cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat"
```

Pourquoi pas Git Bash : il transforme `/c` en `C:/`, ce qui casse la commande. Le serveur ne démarre jamais et Claude Code affiche "connection timed out".

8. Vérifie que le serveur est enregistré :

```powershell
claude mcp list
```

9. Lance `claude` dans le dossier du projet, avec Studio ouvert sur "Creuse ou Crève". Dans Studio, la ligne sous Enable Studio as MCP server doit passer de "No clients connected" à un client connecté.
10. Dans Claude Code, demande : "Liste les instances Roblox Studio ouvertes". Si Studio répond, c'est branché.

**Règle importante :** le code reste dans VS Code et Git (c'est la source de vérité). Si je crée un script via MCP, il doit aussi exister dans `src/`, sinon Rojo l'écrasera ou il sera perdu. Je travaillerai donc en écrivant dans les fichiers du projet, et j'utiliserai Studio pour tester et inspecter la carte.

## 12. Ta routine de travail chaque jour

1. Ouvre le dossier `C:\dev\creuse-ou-creve` dans VS Code.
2. `git pull` (si tu travailles sur plusieurs ordis).
3. `rojo serve` dans le terminal de VS Code.
4. Ouvre la place publiée dans Studio, puis Rojo, puis **Connect**.
5. Code dans VS Code, teste dans Studio.
6. En fin de session : `git add .`, `git commit -m "ce que j'ai fait"`, `git push`.
7. Dans Studio : **File**, puis **Publish (Alt+P)** pour sauvegarder la carte.

## 13. Checklist finale

- [x] `git --version` fonctionne
- [x] `rokit --version` fonctionne
- [x] `rojo --version` fonctionne dans le dossier du projet
- [x] `stylua --version` fonctionne dans le dossier du projet
- [x] Le projet est dans `C:\dev\creuse-ou-creve` (pas dans OneDrive)
- [x] `default.project.json` est remplacé avec `$ignoreUnknownInstances`
- [x] `.vscode/settings.json` est créé
- [x] Extension StyLua installée dans VS Code
- [x] Bouton Rojo visible dans Studio
- [x] Le test de synchro de l'étape 9 fonctionne
- [x] Code envoyé sur un dépôt GitHub privé
- [x] Place publiée, API Services activés, `servePlaceIds` ajouté
- [x] Claude Desktop branché sur Studio via MCP

## 14. Dépannage

| Problème | Solution |
| --- | --- |
| `rokit` ou `rojo` n'est pas reconnu | Ferme et rouvre PowerShell et VS Code. Vérifie que tu es bien dans le dossier du projet pour `rojo`. |
| Le script PowerShell est bloqué | Utilise `rokit.exe` depuis la page des releases GitHub (étape 2). |
| Le plugin refuse de se connecter (version) | Relance `rojo plugin install`, puis redémarre Studio. |
| Rojo ne se connecte pas du tout | Vérifie que `rojo serve` tourne toujours dans le terminal, et que le Place ID ouvert est bien dans `servePlaceIds`. |
| Le code n'apparaît pas au bon endroit dans Studio | Vérifie les chemins dans `default.project.json` et les noms de dossiers dans `src/`. |
| Rojo a effacé quelque chose construit dans Studio | Il manque `$ignoreUnknownInstances` sur ce service : ajoute-le. |
| Erreur DataStore pendant les tests | Active "Enable Studio Access to API Services" (étape 10). |
| L'autocomplétion Luau ne trouve pas les modules | Vérifie `.vscode/settings.json`, puis recharge VS Code (Ctrl+Shift+P, "Reload Window"). |
| Claude ne voit pas Studio | Studio doit être ouvert avec le serveur MCP activé. Redémarre Claude Desktop après l'avoir activé. |
| Roblox\_Studio en échec dans /mcp ("connection timed out"), avec cmd.exe C:/ dans la commande | La commande a été ajoutée depuis Git Bash. Dans PowerShell : claude mcp remove Roblox\_Studio -s local, puis rajoute-la avec la commande complète de l'étape 11. Relance claude ensuite. |
| claude mcp list dit Connected, mais /mcp montre un échec | Une entrée locale cassée passe avant la bonne. Supprime-la avec claude mcp remove Roblox\_Studio -s local, puis relance claude. |
