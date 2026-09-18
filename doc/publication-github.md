# Publication sur GitHub — Projet 5

Dépôt cible : **`ppe-projet5-deploiement-image-systeme`**
Les liens d'images du rendu pointent déjà vers
`https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/`
— le nom du dépôt et la branche `main` doivent donc être respectés à la lettre.

---

## Étape 1 — Initialiser le dépôt local

Dans PowerShell, à la racine du projet :

```powershell
cd C:\Users\Lami\Documents\PPE-P5
git init
git branch -M main
git add .
git status
```

`git status` doit lister le README, `.gitignore`, les dossiers `doc/`, `scripts/`,
`deploiement/` et **22 fichiers dans `captures/`** — mais **pas** le sous-dossier
`captures/Screenpresso/` ni les fichiers `.iso`, exclus par le `.gitignore`.

Si `Screenpresso` ou une ISO apparaît, ne commite pas : préviens-moi.

```powershell
git commit -m "Projet 5 - deploiement standardise d'un poste (image systeme)"
```

---

## Étape 2 — Créer le dépôt distant et pousser

### Si GitHub CLI est installé (`gh --version` répond)

```powershell
gh auth status
gh repo create ppe-projet5-deploiement-image-systeme --public --source=. --remote=origin --push
```

Une seule commande crée le dépôt, ajoute le distant et pousse.

### Sinon

Crée un dépôt **vide** nommé `ppe-projet5-deploiement-image-systeme` sur GitHub
(public, **sans** README ni .gitignore ni licence — le dépôt doit être vide), puis :

```powershell
git remote add origin https://github.com/L4ami/ppe-projet5-deploiement-image-systeme.git
git push -u origin main
```

---

## Étape 3 — Vérifier que les images s'affichent

Ouvre dans un navigateur :

```
https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/01-vm-reference-parametres.png
```

Si l'image s'affiche, **toutes** les images du rendu s'afficheront dans HackMD. Si tu
obtiens une erreur 404, c'est que le nom du dépôt ou celui de la branche diffère —
dis-le-moi, je corrigerai les 22 liens en une commande.

---

## Étape 4 — Mettre le rendu en ligne sur HackMD

```powershell
notepad C:\Users\Lami\Documents\PPE-P5\doc\rendu-p5.md
```

`Ctrl+A` → `Ctrl+C` → nouvelle note HackMD → `Ctrl+V`.

C'est **ce lien HackMD unique** qui est remis au formateur : le rendu contient tout
(cahier des charges, procédures, captures commentées, problèmes rencontrés,
comparatif de temps, notions acquises), et renvoie au dépôt GitHub pour les fichiers
sources.

---

## Étape 5 — Mettre à jour le dépôt plus tard

Si tu modifies quoi que ce soit ensuite :

```powershell
cd C:\Users\Lami\Documents\PPE-P5
git add .
git commit -m "Corrections apres relecture"
git push
```
