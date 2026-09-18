# Point de reprise — Projet 5

**Arrêt : 17 septembre 2026, fin d'après-midi.**
Tout est sauvegardé. Rien n'est à refaire de ce qui est listé comme terminé.

---

## ✅ Ce qui est TERMINÉ et validé

| Élément | État |
|---|---|
| Cahier des charges | rédigé et justifié — `doc/cahier-des-charges.md` |
| **Poste de référence STD-PG-01** | construit, **100 % conforme (59/59)**, snapshot `P5-reference-validee` |
| Temps manuel mesuré | **150 minutes**, 12 phases — `doc/chrono-manuel.csv` |
| Fichier de réponses | corrigé, ne garde que `windowsPE` (vérifiée à l'exécution) |
| 4 scripts PowerShell | écrits et testés |
| 3 procédures pas à pas | rédigées |
| Journal des problèmes | 8 incidents documentés — `doc/problemes-rencontres.md` |
| Rendu | chapitres 1 à 4 rédigés — `doc/rendu-p5.md` |
| Captures | ~21 prises, dans `captures/` |

**Les 70 % de la note les plus lourds sont déjà couverts** : cahier des charges (15 %),
qualité du script (30 %), et une bonne partie de la documentation (30 %).

---

## ▶️ REPRENDRE ICI — le déploiement de STD-PG-02

L'état de STD-PG-02 est incertain (installation interrompue). **On repart propre.**

### Étape 1 — Remettre la VM à zéro

1. VMware → `Mettre hors tension` STD-PG-02
2. **Clic droit sur l'onglet `STD-PG-02` → `Fermer l'onglet`**
   *(indispensable : tant que l'onglet est ouvert, VMware réécrit le fichier `.vmx`)*
3. Vérifier dans `D:\VM\STD-PG-02.vmx` que la ligne est bien :
   `bios.bootOrder = "hdd,cdrom"`
4. Rouvrir : `Fichier` → `Ouvrir` → `D:\VM\STD-PG-02.vmx`

### Étape 2 — Refabriquer le média de configuration

Sur le **Lenovo** (pas dans la VM) :

```powershell
cd C:\Users\Lami\Documents\PPE-P5\scripts
powershell -ExecutionPolicy Bypass -File .\p5-creer-iso-config.ps1 -Numero 02
```

*(si l'ISO est verrouillée : décocher `Connecté` sur le lecteur CD dans VMware)*

### Étape 3 — Installer

Démarrer la VM. **Ne toucher à aucune touche.**

- Le disque n'est pas amorçable → le firmware bascule sur le CD
- Si l'écran « Sélectionner l'emplacement » apparaît : `Delete Partition` sur chaque
  partition, puis `Suivant`
- Plus aucune question de langue, clavier, édition ou licence : c'est la passe
  `windowsPE` du fichier de réponses qui y répond

📸 `23-install-auto-aucune-question.png` *(déjà prise)*

### Étape 4 — Phase de bienvenue, à la main (~3 min)

- Suisse → clavier Suisse romand → ignorer la 2ᵉ disposition
- Compte : `Maj+F10` → `start ms-cxh:localonly` → `adm.local` / `Adm.Local-2026!`
- Confidentialité : tout désactiver

📸 `24-oobe-manuel-std-pg-02.png`

### Étape 5 — Lancer le script de post-installation

PowerShell **en administrateur** dans la VM (vérifier la lettre du lecteur CONFIG-P5) :

```powershell
powershell -ExecutionPolicy Bypass -File D:\PPE-P5\p5-post-install.ps1 -Numero 02
```

📸 `25-script-post-install-en-cours.png` · `26-script-post-install-fin.png`

Le script écrit lui-même ses durées dans `C:\Deploiement\logs\rapport-deploiement.json`.

### Étape 6 — Contrôle de conformité

```powershell
powershell -ExecutionPolicy Bypass -File C:\Deploiement\p5-verifier-conformite.ps1
```

📸 `27-conformite-02-console.png` · `28-conformite-02-html.png`

*(pour ouvrir le rapport HTML, le copier d'abord sur le bureau : Edge ne peut pas
lire `C:\Deploiement`, dossier réservé aux administrateurs)*

### Étape 7 — Captures d'incident à renommer

Dans la bibliothèque Screenpresso :

| Capture existante | Nouveau nom |
|---|---|
| Erreur « Windows n'a pas pu terminer l'installation » | `99a-echec-passe-specialize.png` |
| Écran « Sélectionner l'emplacement », 64 Go non alloué | `99b-disque-efface-par-le-fichier-de-reponses.png` |
| Message `[BLOQUÉ] L'image ISO est verrouillée` | `99c-iso-verrouillee.png` |

La 99b est la plus importante : elle prouve que le fichier de réponses a bien été
appliqué.

---

## 📝 Ce qu'il restera ensuite (Claude s'en charge)

- Comparatif de temps manuel vs automatisé, avec extrapolation aux 10 postes
- Chapitres 5 à 11 du rendu
- `README.md` et `.gitignore` : **déjà prêts** à la racine du projet
- Publication GitHub en ligne de commande, puis mise en ligne HackMD

---

## 🗂️ Repères

| Quoi | Où |
|---|---|
| Projet | `C:\Users\Lami\Documents\PPE-P5\` |
| VMs | `D:\VM\` |
| ISO Windows | `D:\VM\Win11_24H2_French_x64.iso` |
| ISO de config | `C:\Users\Lami\Documents\PPE-P5\deploiement\PPE-P5-Config.iso` |
| Mots de passe | `adm.local` / `Adm.Local-2026!` — `utilisateur` / `Utilisateur-2026!` |
| Dépôt prévu | `ppe-projet5-deploiement-image-systeme` |
