# Projet 5 — Déploiement standardisé d'un poste de travail

> **PPE — Cours 01 IT Essentials (module 187)** · Classe E1B · Geneva Institute of Technology
> Auteur : **Paul Giocanti** · Septembre 2026

Préparer une méthode reproductible pour équiper **10 postes bureautiques identiques**,
la tester réellement, et mesurer ce qu'elle fait gagner par rapport à une installation
poste par poste.

---

## Le problème

Une PME ouvre un plateau et doit installer 10 postes identiques, avec un seul
technicien. Installer chaque machine à la main coûte cher en temps et produit
inévitablement des postes qui divergent : un réglage oublié ici, une version de
logiciel différente là. Le parc devient impossible à maintenir.

La réponse industrielle tient en trois temps : **décrire** le poste voulu,
**reproduire** cette description automatiquement, **prouver** que le résultat est
conforme.

---

## Ce que contient ce dépôt

| Fichier | Rôle |
|---|---|
| `doc/cahier-des-charges.md` | La définition du poste standard : matériel, système, comptes, réseau, sécurité, logiciels. Source de vérité de tout le reste |
| `deploiement/autounattend.xml` | Fichier de réponses Windows Setup — supprime toutes les questions de l'installation |
| `deploiement/sysprep-unattend.xml` | Fichier de réponses utilisé après restauration d'une image disque |
| `scripts/p5-post-install.ps1` | Configuration complète du poste en 9 étapes chronométrées |
| `scripts/p5-verifier-conformite.ps1` | 40 contrôles automatisés → score de conformité, CSV et rapport HTML |
| `scripts/p5-creer-iso-config.ps1` | Fabrique le média de déploiement sans outil externe (IMAPI2) |
| `scripts/p5-chrono.ps1` | Chronomètre de phases, pour mesurer les trois méthodes de la même façon |
| `doc/procedure-*.md` | Les trois procédures pas à pas, reproductibles |
| `captures/` | Preuves d'exécution |

---

## Les trois méthodes comparées

| | Machine | Méthode | Résultat |
|---|---|---|---|
| Référence | `STD-PG-01` | Installation et configuration **manuelles**, chronométrées | **150,1 min** · conformité 100 % après 3 passages et 13 corrections |
| Test | `STD-PG-02` | **Fichier de réponses + script PowerShell** | **47,4 min** · conformité 100 % **du premier coup** |
| Étudié | Sysprep + image Clonezilla | procédure rédigée et analysée, **non exécutée** faute de temps | — |

Les deux postes déployés passent le **même contrôle de conformité — 59 points** :
c'est ce qui permet d'affirmer qu'ils sont identiques, chiffres à l'appui, plutôt que
de le supposer.

## Résultats mesurés

- Configuration du poste : **78 min en manuel → 7 min en automatisé (− 91 %)**
- Sur 10 postes : **25 h 02 → 7 h 54**, soit 17 heures de technicien
- **Rentable à partir du 5ᵉ poste**, préparation amortie
- Le poste manuel comportait **13 non-conformités dont 6 invisibles** dans l'interface
  de Windows ; le poste automatisé, aucune

---

## Démarrage rapide

Fabriquer le média de déploiement et l'installer sur un poste :

```powershell
# 1. Construire l'ISO de configuration pour le poste n°02
powershell -ExecutionPolicy Bypass -File scripts\p5-creer-iso-config.ps1 -Numero 02

# 2. Dans l'hyperviseur : monter l'ISO Windows 11 Pro ET PPE-P5-Config.iso,
#    puis démarrer la machine. Plus aucune intervention.

# 3. Une fois le poste démarré, contrôler sa conformité
powershell -ExecutionPolicy Bypass -File C:\Deploiement\p5-verifier-conformite.ps1
```

---

## Positionnement par rapport aux outils du marché

Cette approche est la version « sans infrastructure » de ce que font les outils
d'entreprise. Le principe est identique : **on ne transporte pas un disque, on
transporte une description du poste voulu.**

| Outil | Ce qu'il apporte en plus | Ce qu'il exige |
|---|---|---|
| **Windows Autopilot** | Le poste sort du carton, se connecte à Internet et se configure seul, sans que le service informatique le touche | Un abonnement Microsoft Entra ID + Intune |
| **Microsoft Deployment Toolkit (MDT)** | Séquences de tâches, catalogue de pilotes, déploiement réseau par PXE | Un serveur de déploiement |
| **Clonezilla** | Capture et restauration d'un disque entier, gratuit, hors ligne | Une image par modèle de matériel, plusieurs Go à transporter |
| **Ce projet** | Fichier de réponses + script : 100 Ko, versionnable dans Git, indépendant du matériel | Rien d'autre que le média d'installation |

---

## Compétences mises en œuvre

Rédaction d'un cahier des charges technique · fichiers de réponses Windows
(`unattend.xml`, les 3 passes) · Sysprep et généralisation d'image · Clonezilla
(`savedisk` / `restoredisk`) · scripting PowerShell (idempotence, journalisation,
mesure de durée, gestion d'erreurs) · durcissement d'un poste Windows · contrôle de
conformité automatisé · mesure et comparaison de temps d'exécution.

---

*Projet réalisé dans le cadre du PPE de septembre 2026. L'entreprise « Arve Services SA »
est fictive. Les mots de passe présents dans les fichiers de réponses sont des mots de
passe de laboratoire ; la gestion des secrets en production est traitée dans le rapport.*
