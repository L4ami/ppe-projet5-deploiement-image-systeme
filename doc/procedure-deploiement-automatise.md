# Procédure — Déploiement automatisé (fichier de réponses + script)

Cible : **STD-PG-02**. Objectif : prouver qu'un poste identique au poste de référence
se déploie **sans aucune intervention humaine** entre le démarrage de la machine et
le poste prêt à l'emploi.

---

## Principe

Windows Setup cherche tout seul un fichier nommé `autounattend.xml` **à la racine**
de chaque lecteur amovible et de chaque lecteur de CD/DVD présent au démarrage.
S'il le trouve, il lit dedans les réponses aux questions qu'il aurait posées et
n'affiche plus rien.

On n'a donc **pas besoin de reconstruire l'ISO de Windows** (5 à 6 Go) : il suffit
de présenter à la machine un **second CD** de quelques dizaines de kilo-octets qui
contient le fichier de réponses et les scripts.

```
ISO Windows 11 Pro  ──►  lecteur CD 1   (le système à installer)
PPE-P5-Config.iso   ──►  lecteur CD 2   (les réponses + les scripts)
```

Enchaînement complet, sans personne devant la machine :

| Moment | Ce qui se passe | Qui décide |
|---|---|---|
| Amorçage | WinPE démarre, lit `autounattend.xml` | passe `windowsPE` |
| Partitionnement | Le disque 0 est effacé, 3 partitions GPT créées | passe `windowsPE` |
| Copie du système | Édition Pro sélectionnée par la clé générique | passe `windowsPE` |
| 1er redémarrage | Nom de poste, fuseau, groupe de travail `ARVE` | passe `specialize` |
| 2e redémarrage | Écrans OOBE supprimés, comptes créés, ouverture de session auto | passe `oobeSystem` |
| Session ouverte | `demarrer-post-install.cmd` → `p5-post-install.ps1` | script |
| Fin | Rapport écrit, redémarrage | script |

---

## Étapes

### 1. Fabriquer le média de configuration

Sur l'hôte (le Legion), dans **Windows PowerShell en administrateur** :

```powershell
cd C:\Users\Lami\Documents\PPE-P5\scripts
powershell -ExecutionPolicy Bypass -File .\p5-creer-iso-config.ps1 -Numero 02
```

Le script recopie le fichier de réponses et les scripts dans
`deploiement\media-config\`, écrit `poste.txt` avec le numéro demandé, puis
construit `deploiement\PPE-P5-Config.iso`.

📸 **capture** → `20-media-config-iso-cree.png` *(sortie du script, avec la taille de l'ISO)*
📸 **capture** → `21-contenu-media-config.png` *(le dossier `media-config` dans l'explorateur, `autounattend.xml` visible à la racine)*

---

### 2. Créer la machine virtuelle STD-PG-02

Mêmes paramètres que le poste de référence — c'est le principe même du parc standardisé :

| Paramètre | Valeur |
|---|---|
| Processeurs | 2 |
| Mémoire | 8192 Mo |
| Disque | 60 Go |
| Firmware | UEFI, Secure Boot décoché |
| Réseau | NAT (VMnet8) |

Puis, dans les paramètres de la VM :

- Lecteur **CD/DVD 1** → fichier image ISO → l'**ISO Windows 11 Pro**
- **Ajouter** un matériel → **Lecteur de CD/DVD** → fichier image ISO → `PPE-P5-Config.iso`
- Vérifier que les deux lecteurs sont cochés **Connecté à la mise sous tension**

📸 **capture** → `22-vm-std-pg-02-deux-lecteurs.png` *(fenêtre des paramètres, les deux lecteurs CD visibles avec leurs ISO)*

---

### 3. Lancer le chronomètre, puis la machine

Sur l'hôte :

```powershell
cd C:\Users\Lami\Documents\PPE-P5\scripts
powershell -ExecutionPolicy Bypass -File .\p5-chrono.ps1 -Scenario auto
```

Puis démarrer la VM et **ne plus y toucher**.

> Au tout premier écran, le message « Appuyez sur une touche pour démarrer depuis le
> CD » attend une frappe : c'est la **seule** interaction. Sur du matériel physique
> déployé par clé USB ou par le réseau (PXE), cette frappe n'existe pas. Elle est
> comptée dans le temps d'intervention humaine, honnêtement, dans le comparatif.

📸 **capture** → `23-install-auto-aucune-question.png` *(l'écran de copie des fichiers, à comparer avec `04` : aucune question n'a été posée avant)*

---

### 4. Observer la post-installation

Après le second redémarrage, la session `adm.local` s'ouvre toute seule et la fenêtre
PowerShell du script apparaît.

📸 **capture** → `24-script-post-install-en-cours.png` *(la console en cours, pendant l'installation des logiciels par winget)*
📸 **capture** → `25-script-post-install-fin.png` *(le récapitulatif final avec la durée totale)*

Après le redémarrage final, sur le bureau :

📸 **capture** → `26-rapport-deploiement-bureau.png` *(le fichier `Rapport-deploiement.txt` ouvert)*

---

### 5. Contrôler la conformité

Session `adm.local`, PowerShell **en administrateur** :

```powershell
powershell -ExecutionPolicy Bypass -File C:\Deploiement\p5-verifier-conformite.ps1
```

📸 **capture** → `27-conformite-02-console.png`
📸 **capture** → `28-conformite-02-html.png` *(rapport HTML dans le navigateur, score bien visible)*

**C'est la preuve du test demandé par la consigne** : le même contrôle, les mêmes
40 points, exécuté sur la machine de référence et sur la machine déployée.

---

### 6. Récupérer les mesures

Copier depuis la VM vers l'hôte, dans `Documents\PPE-P5\doc\` :

- `C:\Deploiement\logs\rapport-deploiement.json`
- `C:\Deploiement\logs\durees-etapes.csv`
- `C:\Deploiement\logs\conformite-STD-PG-02.csv`

Arrêter le chronomètre de l'hôte : il produit `doc\chrono-auto.csv`.

---

## Si ça ne se déroule pas comme prévu

| Symptôme | Cause la plus probable | Correction |
|---|---|---|
| Setup pose quand même les questions | Le fichier de réponses n'a pas été trouvé | Vérifier qu'il est bien **à la racine** de l'ISO de config, et que le second lecteur CD est connecté |
| Setup s'arrête sur le choix de l'édition | La clé générique ne correspond à aucune édition du média | Le média ne contient pas Windows 11 **Pro** : vérifier avec `Get-WindowsImage` |
| Erreur de partitionnement | Le disque n'est pas le disque 0 | Ne laisser qu'un seul disque virtuel attaché pendant l'installation |
| Le compte `adm.local` n'est pas administrateur | Nom du groupe traduit différemment | Adapter la balise `<Group>` selon la langue du média (voir commentaire en tête du fichier de réponses) |
| Le script ne se lance pas | Lettre du lecteur CD hors de la plage D→P | Ajouter la lettre dans la boucle de `FirstLogonCommands` |
| winget échoue sur tous les paquets | Pas d'accès Internet dans la VM | Vérifier le mode NAT de la carte réseau |

> Tous les incidents réellement rencontrés doivent être notés ici avec leur solution :
> c'est la section du rapport que le formateur lit en premier.
