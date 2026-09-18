# Cahier des charges — Poste de travail standard

**Projet 5 — Déploiement standardisé d'un poste (image système)**
Cours 01 IT Essentials (module 187) · Classe E1B · Geneva Institute of Technology
Auteur : Paul Giocanti (PG) · Date : 17.09.2026 · Version 1.0

---

## 1. Contexte et périmètre

**Arve Services SA** (entreprise fictive), PME genevoise d'une trentaine de collaborateurs,
ouvre un nouveau plateau et doit équiper **10 postes de travail bureautiques identiques**.

Le service informatique est composé d'**une seule personne**. Installer 10 postes un par un
à la main représenterait plusieurs jours de travail, avec un risque élevé de divergence entre
les postes (un oubli de configuration sur le poste 7, une version de logiciel différente sur
le poste 3…). L'objectif de ce projet est donc de définir **un poste type unique** puis de le
reproduire **automatiquement** et **à l'identique** sur les 10 machines.

### Ce qu'on entend par « poste standard »

Un poste standard, c'est un poste dont **chaque paramètre est décidé à l'avance et écrit
quelque part**. Sans cahier des charges, l'automatisation n'a aucun sens : un script ne fait
que répéter une décision. Ce document est donc la **source de vérité** du projet — le fichier
de réponses, le script de post-installation et le script de contrôle de conformité découlent
tous des tableaux ci-dessous.

| Élément | Décision |
|---|---|
| Nombre de postes | 10 |
| Usage | Bureautique (traitement de texte, tableur, PDF, messagerie, navigation web) |
| Profil des utilisateurs | Non-informaticiens, pas de droits d'administration |
| Domaine / annuaire | Aucun — groupe de travail (la PME n'a pas de contrôleur de domaine) |
| Support | 1 technicien, intervention à distance impossible (pas de RMM) |

---

## 2. Configuration matérielle minimale

Le parc étant acheté neuf et identique, le cahier des charges fixe un **plancher matériel**.
Il sert à deux choses : valider le bon de commande, et garantir que l'image / le script
fonctionnera sur toutes les machines.

| Composant | Exigence minimale | Justification |
|---|---|---|
| Processeur | x86-64, 2 cœurs, 1 GHz, compatible Windows 11 | Prérequis officiel Microsoft pour Windows 11 |
| Mémoire vive (RAM) | 8 Go | Le minimum officiel est 4 Go ; 8 Go est le minimum réaliste pour une suite bureautique + navigateur |
| Stockage | SSD 128 Go | Le minimum officiel est 64 Go ; un SSD divise le temps de déploiement par 3 à 5 |
| Micrologiciel (firmware) | UEFI avec **Secure Boot** activé | Prérequis Windows 11, et protection contre les rootkits de démarrage |
| TPM | Version 2.0 activée | Prérequis Windows 11, support du chiffrement BitLocker |
| Réseau | Ethernet Gigabit | Le déploiement et les mises à jour passent par le réseau |
| Affichage | 1920 × 1080 | Confort bureautique |

> **Sigles.** **UEFI** = *Unified Extensible Firmware Interface*, le programme de démarrage
> de la carte mère qui a remplacé le BIOS. **TPM** = *Trusted Platform Module*, une puce
> qui stocke des clés de chiffrement. **Secure Boot** = fonction de l'UEFI qui refuse de
> démarrer un système non signé.

### Matériel réellement utilisé pour ce projet

Faute de 10 machines physiques, le projet est réalisé sur **machines virtuelles VMware
Workstation Pro**, hébergées sur un Lenovo Legion Pro 5 (Intel Core i9-14900HX, 32 Go de RAM,
SSD NVMe). Une machine virtuelle est un ordinateur simulé par logiciel : elle a son propre
disque, sa propre carte réseau et son propre firmware UEFI, ce qui la rend représentative
d'un poste physique pour un exercice de déploiement.

| Paramètre de la VM | Valeur |
|---|---|
| Processeurs virtuels | 2 |
| Mémoire vive | 8 Go |
| Disque | 60 Go, SCSI, alloué dynamiquement |
| Firmware | UEFI, Secure Boot désactivé *(pour permettre l'amorçage de Clonezilla)* |
| TPM | Module TPM 2.0 virtuel (vTPM) fourni par VMware, chiffrement partiel de la VM |
| Réseau | VMnet8 (NAT) |

---

## 3. Système d'exploitation

| Paramètre | Valeur retenue | Pourquoi |
|---|---|---|
| Système | Windows 11 **Pro** 64 bits, version 24H2 | L'édition **Famille** ne permet ni BitLocker, ni les stratégies locales (`secpol.msc`), ni le pilotage fin par registre : inutilisable en entreprise |
| Langue d'affichage | Français (fr-FR) | Utilisateurs francophones |
| Format régional | Français (Suisse) — fr-CH | Dates JJ.MM.AAAA, séparateur décimal, monnaie CHF |
| Clavier | **Suisse romand** (fr-CH) | Le clavier physique acheté est suisse romand |
| Fuseau horaire | `W. Europe Standard Time` (UTC+1 / UTC+2 en été) | Genève |
| Pays / région | Suisse (GeoID 223) | Détermine les services régionaux et le Microsoft Store |

### Partitionnement du disque

Disque en **GPT** (*GUID Partition Table*, la table de partitions moderne imposée par l'UEFI).

| # | Partition | Taille | Système de fichiers | Rôle |
|---|---|---|---|---|
| 1 | Système EFI | 300 Mo | FAT32 | Contient le chargeur de démarrage lu par l'UEFI |
| 2 | MSR | 16 Mo | — | *Microsoft Reserved*, zone technique réservée à Windows |
| 3 | Windows | Reste du disque | NTFS | Système, applications et données ; lettre `C:` |

**Choix assumé : pas de partition de récupération séparée.** Windows place alors
l'environnement de récupération (**WinRE**) dans la partition Windows. C'est un compromis
volontaire : une partition de récupération séparée impose de figer la taille de la partition
Windows dans le fichier de réponses, ce qui casse le déploiement dès qu'on change la taille
du disque. Avec `Extend = true`, le **même fichier de réponses fonctionne sur un disque de
60 Go comme sur un disque de 1 To** — c'est exactement la propriété recherchée pour
standardiser 10 postes.

---

## 4. Identité du poste et comptes

### Nommage

Convention : `STD-PG-NN`

| Segment | Signification |
|---|---|
| `STD` | Poste **standard** (par opposition à un serveur ou un poste spécifique) |
| `PG` | Initiales du technicien responsable — Paul Giocanti |
| `NN` | Numéro du poste, de `01` à `10` |

Groupe de travail : **`ARVE`** (tous les postes dans le même groupe, pour que le voisinage
réseau et le partage de fichiers fonctionnent entre eux).

### Comptes locaux

| Compte | Type | Groupe | Usage |
|---|---|---|---|
| `adm.local` | Administrateur local | Administrateurs | Compte technique du support : installations, dépannage. **Jamais** utilisé pour travailler |
| `utilisateur` | Standard | Utilisateurs | Session de travail du collaborateur. Renommé au nom du collaborateur à la livraison du poste |

**Pourquoi deux comptes séparés ?** C'est le principe du **moindre privilège** : un utilisateur
qui travaille avec des droits d'administrateur exécute aussi ses logiciels malveillants avec
des droits d'administrateur. Avec un compte standard, un rançongiciel ouvert par erreur ne peut
pas modifier le système ni les autres profils. C'est la recommandation qui avait été signalée
en fin de Projet 3, elle est ici appliquée par construction.

Aucun compte Microsoft : les postes sont gérés localement par le service informatique.

### Politique de mots de passe

| Règle | Valeur | Commande appliquée |
|---|---|---|
| Longueur minimale | 12 caractères | `net accounts /minpwlen:12` |
| Durée de vie maximale | 180 jours | `net accounts /maxpwage:180` |
| Historique | 5 derniers mots de passe interdits | `net accounts /uniquepw:5` |
| Verrouillage du compte | 5 échecs | `net accounts /lockoutthreshold:5` |
| Durée du verrouillage | 15 minutes | `net accounts /lockoutduration:15` |

---

## 5. Réseau

| Paramètre | Valeur | Justification |
|---|---|---|
| Adressage | **DHCP** | 10 postes identiques : l'attribution automatique évite 10 saisies manuelles et 10 risques de conflit d'adresses. L'adressage fixe reste réservé aux serveurs et imprimantes (voir Projet 1) |
| Profil réseau | Privé / « Réseau d'entreprise » | Autorise la découverte réseau interne tout en gardant le pare-feu actif |
| Découverte réseau | Activée | Nécessaire au partage entre postes du groupe de travail |
| Bureau à distance (RDP) | **Désactivé** | Surface d'attaque inutile : le support intervient physiquement |

> **Sigles.** **DHCP** = *Dynamic Host Configuration Protocol*, le service qui distribue
> automatiquement les adresses IP. **RDP** = *Remote Desktop Protocol*, le bureau à distance
> de Windows.

---

## 6. Sécurité

| Exigence | Valeur cible | Mise en œuvre |
|---|---|---|
| Pare-feu Windows | Actif sur les 3 profils (Domaine, Privé, Public) | `Set-NetFirewallProfile -All -Enabled True` |
| Antivirus | Microsoft Defender actif, protection temps réel | Vérifié via `Get-MpComputerStatus` |
| SmartScreen | Activé, blocage des applications inconnues | Clé de registre `EnableSmartScreen` |
| Contrôle de compte d'utilisateur (UAC) | Niveau élevé, bureau sécurisé | `ConsentPromptBehaviorAdmin = 2`, `PromptOnSecureDesktop = 1` |
| Verrouillage automatique de session | 15 minutes d'inactivité | `InactivityTimeoutSecs = 900` |
| Exécution automatique des supports amovibles | Désactivée | `NoDriveTypeAutoRun = 255` |
| Mises à jour Windows | Téléchargement et installation automatiques | `AUOptions = 4` |
| Chiffrement du disque | BitLocker — **prévu, non activé** dans le lab | Nécessite un TPM matériel ; la procédure est documentée pour le parc physique |

> **Sigle.** **UAC** = *User Account Control*, le contrôle de compte d'utilisateur : la fenêtre
> qui demande confirmation avant une action nécessitant les droits d'administrateur.

---

## 7. Logiciels

### Périmètre retenu : le socle commun, sans suite bureautique

Le poste standard embarque le **socle logiciel commun** : navigateur, messagerie,
lecteur de PDF, archiveur, lecteur multimédia et éditeur de texte. La **suite
bureautique en est volontairement exclue**, et c'est une décision d'architecture,
pas un oubli.

Deux raisons :

1. **La licence.** Tous les logiciels retenus ici sont gratuits et librement
   redistribuables : l'image ou le script peut être dupliqué dix fois sans aucune
   démarche de licence. Une suite bureautique — même libre — relève d'un choix de
   service (comptabilité, direction, atelier) et se déploie donc *après* le socle,
   au cas par cas.
2. **Le vieillissement de l'image.** Plus le socle contient de logiciels volumineux,
   plus il se périme vite : chaque mise à jour majeure d'une suite bureautique
   obligerait à reconstruire le poste de référence et à recapturer l'image.

C'est exactement le découpage qu'utilisent les outils de déploiement du marché
(MDT, Intune) : une **image socle** mince et stable, puis des **paquets applicatifs**
déployés par groupe d'utilisateurs. Sur ce projet, ajouter la suite bureautique au
socle se ferait en une ligne dans `p5-post-install.ps1` — ce qui est précisément
l'argument en faveur du script plutôt que de l'image.

La liste est donc volontairement courte : chaque logiciel supplémentaire, c'est une
surface d'attaque, un cycle de mise à jour et un ticket de support de plus,
multipliés par dix postes.

Tous les logiciels sont installés en mode silencieux via **winget**, le gestionnaire de paquets
officiel de Microsoft intégré à Windows 11. Un gestionnaire de paquets télécharge, installe et
met à jour un logiciel à partir d'un simple identifiant, sans aucun clic — c'est ce qui rend
l'installation scriptable.

| Logiciel | Identifiant winget | Rôle |
|---|---|---|
| Mozilla Firefox | `Mozilla.Firefox` | Navigateur web |
| Mozilla Thunderbird | `Mozilla.Thunderbird` | Messagerie |
| Adobe Acrobat Reader | `Adobe.Acrobat.Reader.64-bit` | Lecture de PDF |
| 7-Zip | `7zip.7zip` | Archivage et décompression |
| VLC | `VideoLAN.VLC` | Lecture des fichiers multimédias reçus en pièce jointe |
| Notepad++ | `Notepad++.Notepad++` | Édition de fichiers texte et de configuration |

### Applications préinstallées à retirer

Windows 11 est livré avec des applications grand public sans usage professionnel. Elles
consomment de l'espace, de la bande passante en mises à jour, et allongent le temps de
démarrage. Le script les retire **du système et du modèle de profil**, pour qu'elles ne
reviennent pas à la création d'un nouvel utilisateur.

**Réellement présentes sur le média utilisé** (Windows 11 Pro 24H2 française) et
retirées : **Microsoft Teams** (l'entreprise n'a pas de tenant Microsoft 365),
**Microsoft Bing**, **Microsoft 365 (Office)** — simple raccourci vers un abonnement,
la suite retenue étant LibreOffice —, **Outlook** (la messagerie retenue est
Thunderbird) et **Microsoft OneDrive** (556 Mo, synchronisation cloud personnelle
incompatible avec le choix « aucun compte Microsoft »).

Le script de déploiement vise en plus une quinzaine d'applications grand public
présentes sur d'autres médias d'installation (Clipchamp, Actualités, Météo, Xbox,
Solitaire, To Do, Power Automate, Centre de commentaires, Contacts, Assistance
rapide). Leur retrait est sans effet si elles sont absentes : le script reste ainsi
valable quel que soit le média utilisé.

---

## 8. Arborescence et personnalisation

| Chemin | Contenu | Droits |
|---|---|---|
| `C:\Entreprise\Documents-Communs` | Documents partagés du poste | Utilisateurs : lecture / écriture |
| `C:\Entreprise\Modeles` | Modèles de documents de l'entreprise | Utilisateurs : **lecture seule** |
| `C:\Entreprise\Logiciels` | Sources d'installation locales | Administrateurs uniquement |
| `C:\Entreprise\Sauvegardes` | Point de sauvegarde local | Utilisateurs : lecture / écriture |
| `C:\Deploiement` | Scripts, journaux et rapports de déploiement | Administrateurs uniquement |

Un raccourci vers `C:\Entreprise` est déposé sur le **bureau public**, donc visible par tous
les comptes du poste sans avoir à le recréer pour chacun.

---

## 9. Traçabilité exigée

Un déploiement industriel doit pouvoir se justifier après coup. Chaque poste déployé produit
donc automatiquement :

| Fichier | Contenu |
|---|---|
| `C:\Deploiement\logs\post-install_<date>.log` | Transcription complète de l'exécution du script |
| `C:\Deploiement\logs\rapport-deploiement.json` | Durée de chaque étape, statut, logiciels installés |
| `C:\Deploiement\logs\conformite-<poste>.csv` | Résultat point par point du contrôle de conformité |
| `C:\Deploiement\logs\conformite-<poste>.html` | Même rapport, lisible, avec score de conformité |

**Critère d'acceptation d'un poste : score de conformité ≥ 95 %, et aucun écart sur un point
classé « Sécurité ».**

---

## 10. Tableau de synthèse — les 10 postes

| Poste | Nom | Rôle dans le projet |
|---|---|---|
| 01 | `STD-PG-01` | **Poste de référence**, construit manuellement, chronométré |
| 02 | `STD-PG-02` | **Test du déploiement automatisé** (fichier de réponses + script) |
| 03 | `STD-PG-03` | **Test de la restauration d'image** (Sysprep + Clonezilla) |
| 04 → 10 | `STD-PG-04` … `STD-PG-10` | Déployés en série avec la méthode retenue |

---

*Fin du cahier des charges — version 1.0 du 17.09.2026.*
