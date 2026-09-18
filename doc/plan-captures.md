# Plan des captures d'écran — Projet 5

Toutes les captures vont dans `Documents\PPE-P5\captures\`, nommées exactement
comme ci-dessous. Elles sont ensuite publiées sur GitHub et appelées dans le rendu
HackMD par des URL absolues `raw.githubusercontent.com`.

**Règle de rédaction** (appliquée dans le rendu) : chaque capture est encadrée de
texte — une phrase de contexte au-dessus (pourquoi on en arrive là) et une lecture
de l'image en dessous (ce qu'elle prouve).

## A — Poste de référence STD-PG-01 (méthode manuelle)

| Fichier | Contenu |
|---|---|
| `01-vm-reference-parametres.png` | Paramètres de la VM STD-PG-01 |
| `02-editions-iso.png` | Éditions contenues dans l'ISO Windows 11 |
| `04-installation-windows-manuelle.png` | Copie des fichiers, install manuelle |
| `05-oobe-ecrans.png` | Un écran OOBE (confidentialité désactivée) |
| `06-bureau-windows-installe.png` | Bureau atteint |
| `07-renommage-et-groupe.png` | `sysdm.cpl` : STD-PG-01 / ARVE |
| `09-comptes-crees.png` | `lusrmgr.msc` : adm.local + utilisateur |
| `10-politique-mot-de-passe.png` | `secpol.msc` : stratégie de mot de passe |
| `11-regional-copie-parametres.png` | Copie des réglages vers écran d'accueil et nouveaux profils |
| `12-pare-feu-trois-profils.png` | `wf.msc` : 3 profils actifs |
| `13-securite-uac-verrouillage.png` | `secpol.msc` : limite d'inactivité 900 s |
| `14-applications-supprimees.png` | Liste des applications après nettoyage |
| `15-logiciels-installes.png` | Les 7 logiciels dans Applications installées |
| `16-arborescence-droits.png` | Onglet Sécurité de `C:\Entreprise\Modeles` |
| `17-conformite-reference-console.png` | Synthèse du contrôle en console |
| `18-conformite-reference-html.png` | Rapport HTML du poste de référence |
| `19-chrono-manuel-resultat.png` | Tableau final du chronomètre manuel |

## B — Déploiement automatisé STD-PG-02

| Fichier | Contenu |
|---|---|
| `20-media-config-iso-cree.png` | Sortie de `p5-creer-iso-config.ps1` |
| `21-contenu-media-config.png` | `autounattend.xml` à la racine du média |
| `22-vm-std-pg-02-deux-lecteurs.png` | Les 2 lecteurs CD dans VMware |
| `23-install-auto-aucune-question.png` | Installation sans aucune question |
| `24-script-post-install-en-cours.png` | Script en cours (winget) |
| `25-script-post-install-fin.png` | Récapitulatif avec durée totale |
| `26-rapport-deploiement-bureau.png` | `Rapport-deploiement.txt` |
| `27-conformite-02-console.png` | Contrôle en console |
| `28-conformite-02-html.png` | Rapport HTML de STD-PG-02 |
| `29-chrono-auto-resultat.png` | Tableau final du chronomètre auto |

## C — Image système STD-PG-03

| Fichier | Contenu |
|---|---|
| `40-disque-images-prepare.png` | Disque `IMAGES` formaté |
| `41-snapshot-avant-sysprep.png` | Snapshot `P5-reference-validee` |
| `42-sysprep-en-cours.png` | Sysprep en cours |
| `43-clonezilla-savedisk-en-cours.png` | Capture de l'image en cours |
| `44-clonezilla-image-terminee.png` | Fin de capture + durée |
| `45-taille-image.png` | Taille du fichier image |
| `46-vm-std-pg-03-creee.png` | Paramètres de STD-PG-03 |
| `47-clonezilla-restoredisk.png` | Restauration en cours |
| `48-restauration-terminee.png` | Fin de restauration + durée |
| `49-premier-demarrage-mini-oobe.png` | Premier démarrage du poste restauré |
| `50-finalisation-image-fin.png` | Script de finalisation |
| `51-conformite-03-html.png` | Rapport HTML de STD-PG-03 |
| `52-chrono-image-resultat.png` | Tableau final du chronomètre image |

## D — Synthèse

| Fichier | Contenu |
|---|---|
| `60-comparatif-trois-methodes.png` | Tableau comparatif des 3 méthodes |
| `61-depot-github.png` | Dépôt publié sur GitHub |

## Captures optionnelles

| Fichier | Contenu |
|---|---|
| `99-*.png` | Problèmes rencontrés, messages d'erreur, contournements |
