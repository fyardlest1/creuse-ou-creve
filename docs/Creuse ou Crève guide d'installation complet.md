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

Le plugin et le serveur doivent avoir la même version majeure. En installant le plugin avec cette commande, c'est garanti.

## 7. Configurer VS Code

**Extensions à avoir (onglet Extensions, Ctrl+Shift+X) :**

- [x] Rojo (déjà installée)
- [x] Luau Language Server (déjà installée)
- [ ] StyLua (de JohnnyMorganz)

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

1. Dans Studio : **File**, puis **Publish to Roblox**. Nom : "Creuse ou Crève". Laisse le jeu **privé** pour l'instant.
2. Si tu as déjà créé le groupe Roblox "Konbit Games", publie sous le groupe plutôt que sous ton compte personnel. C'est plus simple pour gérer les revenus et ajouter des collaborateurs plus tard.
3. **Game Settings**, puis **Security** : active **Enable Studio Access to API Services**. Sans ça, les sauvegardes DataStore ne fonctionnent pas pendant les tests dans Studio.
4. Récupère le **Place ID** (dans l'URL de la page du jeu sur roblox.com, ou dans Game Settings) et ajoute-le dans `default.project.json`, juste sous `"name"` :

```json
"servePlaceIds": [123456789],
```

Avec ça, Rojo refuse de se connecter à une autre place par erreur.

5. À partir de maintenant, ouvre toujours **la place publiée** dans Studio (File, puis Open from Roblox), et non le fichier `.rbxl`. Tu peux supprimer le fichier `.rbxl` local.

## 11. Brancher Claude sur Roblox Studio (MCP)

C'est ce qui me permet de lire et d'écrire les scripts directement dans ton Studio, et de lancer les tests moi-même.

1. Installe **Claude Desktop** sur ton ordi (claude.ai/download) et connecte-toi.
2. Dans Roblox Studio, ouvre **Assistant**, clique sur **…**, puis **Manage MCP Servers**.
3. Active **Enable Studio as MCP server**.
4. Dans la même fenêtre, utilise la **connexion rapide** et choisis **Claude Desktop**.
5. Redémarre Claude Desktop, puis Roblox Studio.
6. Dans Claude Desktop, demande : "Liste les instances Roblox Studio ouvertes". Si Studio répond, c'est branché.

**Règle importante :** le code reste dans VS Code et Git (c'est la source de vérité). Si je crée un script via MCP, il doit aussi exister dans `src/`, sinon Rojo l'écrasera ou il sera perdu. Je travaillerai donc en écrivant dans les fichiers du projet, et j'utiliserai Studio pour tester et inspecter la carte.

## 12. Ta routine de travail chaque jour

1. Ouvre le dossier `C:\dev\creuse-ou-creve` dans VS Code.
2. `git pull` (si tu travailles sur plusieurs ordis).
3. `rojo serve` dans le terminal de VS Code.
4. Ouvre la place publiée dans Studio, puis Rojo, puis **Connect**.
5. Code dans VS Code, teste dans Studio.
6. En fin de session : `git add .`, `git commit -m "ce que j'ai fait"`, `git push`.
7. Dans Studio : **File**, puis **Publish to Roblox** pour sauvegarder la carte.

## 13. Checklist finale

- [ ] `git --version` fonctionne
- [ ] `rokit --version` fonctionne
- [ ] `rojo --version` fonctionne dans le dossier du projet
- [ ] `stylua --version` fonctionne dans le dossier du projet
- [ ] Le projet est dans `C:\dev\creuse-ou-creve` (pas dans OneDrive)
- [ ] `default.project.json` est remplacé avec `$ignoreUnknownInstances`
- [ ] `.vscode/settings.json` est créé
- [ ] Extension StyLua installée dans VS Code
- [ ] Bouton Rojo visible dans Studio
- [ ] Le test de synchro de l'étape 9 fonctionne
- [ ] Code envoyé sur un dépôt GitHub privé
- [ ] Place publiée, API Services activés, `servePlaceIds` ajouté
- [ ] Claude Desktop branché sur Studio via MCP

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
