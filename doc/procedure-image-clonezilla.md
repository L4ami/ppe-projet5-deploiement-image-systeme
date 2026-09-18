# Procédure — Image système (Sysprep + Clonezilla)

Cible : **STD-PG-03**. Objectif : capturer le poste de référence sous forme d'**image
disque**, puis la restaurer sur une machine vierge — la méthode « historique » du
déploiement de parc, et l'outil cité dans les ressources de l'énoncé.

---

## Pourquoi Sysprep avant la capture

Un disque Windows contient l'**identité unique** de la machine : le **SID**
(*Security Identifier*, le numéro d'identité utilisé par Windows pour les
autorisations et l'authentification réseau), le nom du poste, l'identifiant
d'activation, l'historique des pilotes installés.

Cloner un disque tel quel donne 10 machines portant **le même SID**. En groupe de
travail cela provoque des échecs d'authentification sur les partages ; en domaine
Active Directory, la seconde machine ne peut tout simplement pas rejoindre le
domaine. C'est aussi une configuration que Microsoft refuse de supporter.

`sysprep /generalize` supprime cette identité. Au démarrage suivant, Windows en
regénère une neuve et repasse par les écrans de bienvenue — auxquels notre fichier
`sysprep-unattend.xml` répond automatiquement.

> **À savoir** : `/generalize` ne peut être exécuté qu'un nombre limité de fois sur
> une même installation (compteur `rearm`, 3 fois par défaut sur Windows 11). D'où
> le snapshot VMware pris avant : il permet de recommencer sans réinstaller.

---

## Étape 0 — Préparer le disque de stockage des images

Sur la VM **STD-PG-01**, encore fonctionnelle (avant Sysprep) :

- [ ] VMware → paramètres de STD-PG-01 → **Ajouter** → **Disque dur** → 60 Go, SCSI
- [ ] Démarrer la VM, `Windows + X` → `Gestion des disques`
- [ ] Initialiser le nouveau disque en **GPT**, créer un volume **NTFS** simple, nom de volume `IMAGES`

📸 **capture** → `40-disque-images-prepare.png`

---

## Étape 1 — Snapshot de sécurité

- [ ] Éteindre la VM
- [ ] VMware → `Machine virtuelle` → `Snapshot` → `Prendre un snapshot` → nom : **`P5-reference-validee`**

📸 **capture** → `41-snapshot-avant-sysprep.png`

---

## Étape 2 — Sysprep

- [ ] Redémarrer STD-PG-01, session `adm.local`
- [ ] Copier `sysprep-unattend.xml` dans `C:\Deploiement\`
- [ ] Démarrer le chronomètre sur l'hôte : `p5-chrono.ps1 -Scenario image`
- [ ] PowerShell **en administrateur** :

```powershell
C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:C:\Deploiement\sysprep-unattend.xml
```

| Option | Rôle |
|---|---|
| `/generalize` | efface le SID, le nom du poste, les pilotes spécifiques et les journaux |
| `/oobe` | au prochain démarrage, la machine repasse par les écrans de bienvenue |
| `/shutdown` | éteint la machine à la fin, pour capturer un disque propre |
| `/unattend:` | fournit les réponses à ces écrans de bienvenue |

La machine s'éteint toute seule à la fin. **Ne pas la redémarrer** : le prochain
démarrage consommerait la généralisation.

📸 **capture** → `42-sysprep-en-cours.png`

---

## Étape 3 — Capturer l'image avec Clonezilla

- [ ] VMware → paramètres de STD-PG-01 → lecteur CD/DVD → monter l'**ISO Clonezilla**
- [ ] Vérifier l'ordre d'amorçage (ou appuyer sur `Échap` / `F2` au démarrage pour choisir le CD)
- [ ] Démarrer la VM

Dans Clonezilla, enchaînement des menus :

| Écran | Choix |
|---|---|
| Menu d'amorçage | `Clonezilla live (Default settings, VGA 1024x768)` |
| Langue | `fr_CH.UTF-8` ou `en_US.UTF-8` |
| Disposition clavier | `Don't touch keymap` |
| Mode | `Start_Clonezilla` |
| Type d'opération | **`device-image`** (disque ↔ fichier image) |
| Emplacement du dépôt | **`local_dev`** (un disque branché sur la machine) |
| *(attendre le scan, puis Entrée)* | choisir la partition **`sdb1`** — le disque `IMAGES` |
| Répertoire | `/` (racine) |
| Mode | **`Beginner`** |
| Action | **`savedisk`** (sauvegarder un disque entier dans une image) |
| Nom de l'image | `std-pg-01-ref-2026-09-17` |
| Disque source | **`sda`** |
| Compression | laisser le défaut (`-z1p`, zstd multi-cœur) |
| Vérification du système de fichiers | `Skip checking` |
| Vérifier l'image après | **`Yes`** — une image non restaurable ne se découvre jamais au bon moment |
| Confirmations | `y` puis `y` |

📸 **capture** → `43-clonezilla-savedisk-en-cours.png` *(barre de progression avec le débit)*
📸 **capture** → `44-clonezilla-image-terminee.png` *(message de fin et durée)*

> **À noter pour le rapport** : Clonezilla ne copie **que les blocs utilisés** du
> système de fichiers, pas les 60 Go du disque. C'est ce qui explique qu'une image
> d'un disque de 60 Go ne pèse qu'une dizaine de gigaoctets.

- [ ] En fin de capture, choisir `poweroff`
- [ ] Noter la **taille de l'image** et la **durée** affichées

📸 **capture** → `45-taille-image.png` *(le dossier de l'image et sa taille)*

---

## Étape 4 — Préparer la machine cible STD-PG-03

- [ ] Retirer le disque `IMAGES` des paramètres de STD-PG-01 *(sans supprimer le fichier .vmdk)*
- [ ] Créer la VM **STD-PG-03** : 2 processeurs, 8192 Mo, disque **neuf de 60 Go**, UEFI sans Secure Boot, NAT
- [ ] Ajouter à STD-PG-03 le disque **existant** `IMAGES` (`Ajouter` → `Disque dur` → `Utiliser un disque virtuel existant`)
- [ ] Monter l'**ISO Clonezilla** dans son lecteur CD

📸 **capture** → `46-vm-std-pg-03-creee.png`

---

## Étape 5 — Restaurer l'image

Démarrer STD-PG-03 sur Clonezilla, mêmes menus jusqu'à `Beginner`, puis :

| Écran | Choix |
|---|---|
| Action | **`restoredisk`** (restaurer une image sur un disque) |
| Image à restaurer | `std-pg-01-ref-2026-09-17` |
| Disque cible | **`sda`** — le disque neuf de 60 Go |
| Confirmations | `y` puis `y` (le contenu du disque cible est écrasé) |

📸 **capture** → `47-clonezilla-restoredisk.png`
📸 **capture** → `48-restauration-terminee.png` *(message de fin et durée)*

- [ ] `poweroff` à la fin
- [ ] **Retirer** le disque `IMAGES` de STD-PG-03 : un poste standard n'a qu'un seul disque
- [ ] Remplacer l'ISO Clonezilla par **`PPE-P5-Config.iso`** dans le lecteur CD

> ⚠️ Avant cette étape, régénérer l'ISO de configuration avec le bon numéro de poste :
> ```powershell
> powershell -ExecutionPolicy Bypass -File .\p5-creer-iso-config.ps1 -Numero 03
> ```

---

## Étape 6 — Premier démarrage et finalisation

- [ ] Démarrer STD-PG-03

Windows termine sa généralisation, applique `sysprep-unattend.xml` (langue, clavier,
fuseau, groupe de travail), ouvre automatiquement la session `adm.local` et lance
`demarrer-post-image.cmd`, qui appelle le script de post-installation **avec
`-SansLogiciels`** : les 7 applications sont déjà dans l'image, il ne reste que
l'identité du poste à appliquer.

📸 **capture** → `49-premier-demarrage-mini-oobe.png`
📸 **capture** → `50-finalisation-image-fin.png` *(récapitulatif du script)*

---

## Étape 7 — Contrôle de conformité

```powershell
powershell -ExecutionPolicy Bypass -File C:\Deploiement\p5-verifier-conformite.ps1
```

📸 **capture** → `51-conformite-03-html.png`

Arrêter le chronomètre de l'hôte → `doc\chrono-image.csv`.

---

## Limites de la méthode image, à écrire dans le rapport

| Limite | Conséquence concrète |
|---|---|
| L'image contient les pilotes du matériel de référence | Un parc hétérogène impose une image par modèle de machine, ou l'injection de pilotes avec **DISM** |
| Taille du fichier | Une dizaine de Go à transporter et à stocker, contre 100 Ko pour le fichier de réponses |
| Vieillissement | L'image est figée : au bout de trois mois, chaque poste restauré doit télécharger trois mois de mises à jour. Il faut donc « rafraîchir » l'image régulièrement (*image servicing*) |
| Modification | Changer un seul paramètre impose de restaurer le poste de référence, le modifier, le re-sysprepper et le recapturer — contre une ligne à changer dans un script |
| Compteur `rearm` | `/generalize` n'est utilisable qu'un nombre limité de fois sur une même installation |

C'est exactement pour ces raisons que l'industrie a basculé vers l'installation
automatisée et le provisionnement (**Windows Autopilot**, **Microsoft Intune**,
**MDT**) : on ne transporte plus un disque, on transporte une **description** du
poste voulu.
