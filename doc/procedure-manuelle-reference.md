# Procédure manuelle — Construction du poste de référence STD-PG-01

**À suivre pas à pas, chronomètre lancé.** Cette procédure applique à la main, via
l'interface graphique, **exactement** ce que le script `p5-post-install.ps1` fera
automatiquement sur les autres postes. C'est indispensable pour que le comparatif
de temps soit honnête : on compare deux fois le même travail, pas deux travaux
différents.

> **Règle du chronomètre** : le script `p5-chrono.ps1 -Scenario manuel` affiche la
> phase en cours. Tu appuies sur Entrée **au moment précis** où la phase est finie.
> Ne t'arrête pas pour prendre les captures pendant une phase chronométrée si tu
> peux l'éviter — prends-les en fin de phase, juste avant d'appuyer sur Entrée.

---

## Phase 1 — Création et paramétrage de la machine virtuelle

### Assistant de création

`Fichier` → `Nouvelle machine virtuelle` → **Personnalisé (avancé)**

| Écran de l'assistant | Choix | Pourquoi ce choix |
|---|---|---|
| Compatibilité matérielle | laisser par défaut | — |
| Installation du système | **« J'installerai le système d'exploitation plus tard »** | ⚠️ **Le choix le plus important.** Si on désigne l'ISO ici, VMware active son *Easy Install* : il fabrique son propre fichier de réponses et installe Windows tout seul. Ça fausserait complètement la mesure du temps manuel, et ça entrerait en conflit avec notre fichier de réponses au moment du déploiement automatisé |
| Système invité | Microsoft Windows → **Windows 11 x64** | VMware ajoute alors automatiquement un **TPM 2.0 virtuel (vTPM)** et active un chiffrement dit **partiel** (`vmx.encryptionType = "partial"`). Ce chiffrement ne porte **que** sur les fichiers de configuration liés au TPM, **pas sur le disque virtuel** : ni les snapshots ni la capture Clonezilla n'en sont affectés. On garde donc cette configuration, qui a l'avantage de rendre le poste **réellement conforme** à l'exigence TPM 2.0 du cahier des charges |
| Nom / emplacement | `STD-PG-01` dans `D:\VM\STD-PG-01` | — |
| Processeurs | **2** cœurs au total | plancher du cahier des charges |
| Mémoire | **8192 Mo** | plancher du cahier des charges |
| Réseau | **NAT** | la VM sort sur Internet par la connexion de l'hôte, nécessaire pour winget |
| Contrôleur d'E/S | LSI Logic SAS *(valeur proposée)* | — |
| Type de disque | **SATA** | un disque SATA apparaît sous le nom `sda` dans Clonezilla. Avec NVMe il s'appellerait `nvme0n1` : autant garder des noms simples et prévisibles pour la suite |
| Disque | **Créer un disque virtuel**, **60 Go**, découpé en plusieurs fichiers | 60 Go = plancher du cahier des charges |

### Réglages après création

`Modifier les paramètres de cette machine virtuelle` :

- [ ] Onglet **Options** → `Avancé` → **Type de firmware : UEFI**, case *Secure Boot* **décochée**
      *(UEFI est exigé par Windows 11 ; Secure Boot est laissé désactivé pour que Clonezilla puisse démarrer sur cette machine plus tard)*

> **Vérification par le fichier de configuration.** Plutôt que de faire confiance à
> l'interface, on peut relire directement le fichier `.vmx` de la machine, qui est du
> texte : `firmware = "efi"` confirme l'UEFI, `vtpm.present = "TRUE"` la présence du
> TPM virtuel, l'absence de `uefi.secureBoot.enabled` confirme que Secure Boot est
> bien désactivé, et `sata0:0` / `sata0:1` que le disque et le lecteur CD sont bien
> tous deux sur le bus SATA.
- [ ] Onglet **Matériel** → `CD/DVD` → **Utiliser un fichier image ISO** → `D:\VM\Win11_24H2_French_x64.iso`
- [ ] Vérifier que la case **Connecté à la mise sous tension** est cochée

📸 **capture** → `01-vm-reference-parametres.png` *(fenêtre des paramètres, matériel visible)*

---

## Phase 2 — Installation de Windows

Installation **entièrement manuelle**, comme un technicien sans outil : chaque écran, chaque clic.

- [ ] Démarrer la VM, appuyer sur une touche pour amorcer sur le CD
- [ ] Langue d'installation : **Français (Suisse)** / clavier **Suisse romand**
- [ ] « Installer maintenant » → « Je n'ai pas de clé de produit »
- [ ] Édition : **Windows 11 Pro**
- [ ] Accepter le contrat de licence
- [ ] Type d'installation : **Personnalisé**
- [ ] Sélectionner le disque non alloué de 60 Go → **Suivant** (Windows crée lui-même les partitions)
- [ ] Attendre la copie des fichiers et les redémarrages

📸 **capture** → `04-installation-windows-manuelle.png` *(écran de copie des fichiers, avec le pourcentage visible)*

---

## Phase 3 — Écrans de bienvenue (OOBE)

> **OOBE** = *Out-Of-Box Experience*, la série d'écrans au premier démarrage.
> C'est la phase que le fichier de réponses supprimera entièrement.

- [ ] Pays/région : **Suisse**
- [ ] Clavier : **Suisse romand**, pas de second clavier
- [ ] Nom du réseau / connexion : laisser faire
- [ ] Contrat de licence : accepter
- [ ] Compte : cliquer sur les options pour créer un **compte local** → nom `adm.local`, mot de passe `Adm.Local-2026!`
- [ ] Questions de sécurité : répondre n'importe quoi de cohérent
- [ ] Options de confidentialité : **tout désactiver**
- [ ] Refuser la personnalisation, OneDrive, Game Pass et tout ce qui est proposé

📸 **capture** → `05-oobe-ecrans.png` *(un des écrans de confidentialité, tout désactivé)*
📸 **capture** → `06-bureau-windows-installe.png` *(le bureau, une fois arrivé dessus)*

---

## Phase 4 — Renommage du poste et groupe de travail

- [ ] `Paramètres` → `Système` → `Informations système` → **Renommer ce PC** → `STD-PG-01`
- [ ] `Windows + R` → `sysdm.cpl` → onglet **Nom de l'ordinateur** → **Modifier** → Groupe de travail : `ARVE`
- [ ] Redémarrer quand c'est demandé

📸 **capture** → `07-renommage-et-groupe.png` *(fenêtre `sysdm.cpl` montrant `STD-PG-01` et `ARVE`)*

---

## Phase 5 — Comptes et politique de mot de passe

- [ ] `Windows + R` → `lusrmgr.msc` (console des utilisateurs locaux, disponible en édition Pro)
- [ ] Créer l'utilisateur `utilisateur`, mot de passe `Utilisateur-2026!`, décocher « L'utilisateur doit changer… »
- [ ] Vérifier qu'il est dans le groupe **Utilisateurs** et **pas** dans Administrateurs
- [ ] Vérifier que `adm.local` est bien dans **Administrateurs**
- [ ] Clic droit sur le compte **Invité** → Propriétés → cocher « Le compte est désactivé »
- [ ] `Windows + R` → `secpol.msc` → `Stratégies de comptes` → `Stratégie de mot de passe` :
  - Longueur minimale : **12** caractères
  - Durée de vie maximale : **180** jours
  - Durée de vie minimale : **1** jour
  - Conserver l'historique : **5** mots de passe
- [ ] `Stratégie de verrouillage du compte` :
  - Seuil de verrouillage : **5** tentatives
  - Durée du verrouillage : **15** minutes
  - Réinitialiser le compteur après : **15** minutes

📸 **capture** → `09-comptes-crees.png` *(`lusrmgr.msc`, liste des utilisateurs)*
📸 **capture** → `10-politique-mot-de-passe.png` *(`secpol.msc`, stratégie de mot de passe)*

---

## Phase 6 — Réglages régionaux

- [ ] `Paramètres` → `Heure et langue` → `Date et heure` → fuseau **(UTC+01:00) Berne, Berlin, Rome, Stockholm, Vienne**
- [ ] `Heure et langue` → `Langue et région` → Région : **Suisse**, Format régional : **français (Suisse)**
- [ ] Vérifier que la disposition clavier est **Suisse romand**
- [ ] `Paramètres régionaux administratifs` → **Copier les paramètres** → cocher **Écran d'accueil** et **Nouveaux comptes d'utilisateurs** → OK

> Cette dernière case est celle qu'on oublie toujours : sans elle, le collaborateur
> qui ouvre sa session pour la première fois retombe sur un clavier QWERTY US.

📸 **capture** → `11-regional-copie-parametres.png` *(fenêtre « Copier vos paramètres actuels », les deux cases cochées)*

---

## Phase 7 — Réseau et pare-feu

- [ ] `Paramètres` → `Réseau et Internet` → `Ethernet` → Type de profil réseau : **Privé**
- [ ] Vérifier que l'adresse IP est bien obtenue en **DHCP** (`ipconfig /all` → « DHCP activé : Oui »)
- [ ] `Windows + R` → `wf.msc` → vérifier que le pare-feu est **actif sur les 3 profils**
- [ ] Dans `wf.msc` → `Règles de trafic entrant` → activer le groupe **Découverte de réseau** et **Partage de fichiers et d'imprimantes** (profil privé)
- [ ] Activer la règle `Partage de fichiers et d'imprimantes (Demande d'écho - Trafic entrant ICMPv4)` pour autoriser le ping
- [ ] `Paramètres` → `Système` → `Bureau à distance` → vérifier qu'il est **désactivé**

📸 **capture** → `12-pare-feu-trois-profils.png` *(page d'accueil de `wf.msc`)*

---

## Phase 8 — Sécurité

- [ ] `Windows + R` → `secpol.msc` → `Stratégies locales` → `Options de sécurité` :
  - `Contrôle de compte d'utilisateur : comportement de l'invite d'élévation pour les administrateurs` → **Demande de consentement pour les binaires non-Windows**
  - `Contrôle de compte d'utilisateur : basculer vers le bureau sécurisé…` → **Activé**
  - `Ouverture de session interactive : limite d'inactivité de session` → **900** secondes
- [ ] `Sécurité Windows` → `Contrôle des applications et du navigateur` → `Protection basée sur la réputation` → tout **activé**
- [ ] `Windows + R` → `gpedit.msc` → `Configuration ordinateur` → `Modèles d'administration` → `Composants Windows` → `Stratégies de lecture automatique` → `Désactiver la lecture automatique` = **Activé**, sur **Tous les lecteurs**
- [ ] `Sécurité Windows` → `Protection contre les virus et menaces` → **Rechercher des mises à jour** de protection
- [ ] `Paramètres` → `Windows Update` → vérifier les mises à jour (ne pas attendre l'installation complète, noter juste l'heure)

📸 **capture** → `13-securite-uac-verrouillage.png` *(`secpol.msc`, options de sécurité avec la limite d'inactivité visible)*

---

## Phase 9 — Suppression des applications préinstallées

Menu Démarrer → `Toutes les applications` → clic droit → **Désinstaller**, pour chacune :

- [ ] Clipchamp
- [ ] Actualités
- [ ] Météo
- [ ] Xbox / Xbox Game Bar
- [ ] Solitaire Collection
- [ ] To Do
- [ ] Power Automate
- [ ] Centre de commentaires
- [ ] Contacts
- [ ] Obtenir de l'aide / Assistance rapide
- [ ] Clic droit sur la barre des tâches → `Paramètres de la barre des tâches` → **Widgets : désactivé**

📸 **capture** → `14-applications-supprimees.png` *(liste « Toutes les applications » après nettoyage)*

---

## Phase 10 — Installation des 7 logiciels métier

**À la main, comme un technicien sans gestionnaire de paquets** : aller sur le site
de chaque éditeur, télécharger l'installeur, l'exécuter, cliquer sur Suivant.
C'est cette phase qui explique l'essentiel de l'écart de temps avec l'automatisation.

- [ ] LibreOffice — https://fr.libreoffice.org/download/telecharger-libreoffice/
- [ ] Mozilla Firefox — https://www.mozilla.org/fr/firefox/new/
- [ ] Mozilla Thunderbird — https://www.thunderbird.net/fr/
- [ ] Adobe Acrobat Reader — https://get.adobe.com/fr/reader/ *(décocher les offres additionnelles)*
- [ ] 7-Zip — https://www.7-zip.org/
- [ ] VLC — https://www.videolan.org/vlc/
- [ ] Notepad++ — https://notepad-plus-plus.org/downloads/

📸 **capture** → `15-logiciels-installes.png` *(`Paramètres` → `Applications` → `Applications installées`, les 7 visibles)*

---

## Phase 11 — Arborescence d'entreprise et droits

- [ ] Créer `C:\Entreprise` et les 4 sous-dossiers : `Documents-Communs`, `Modeles`, `Logiciels`, `Sauvegardes`
- [ ] Clic droit sur `C:\Entreprise\Modeles` → `Propriétés` → `Sécurité` → `Avancé` → **Désactiver l'héritage** (convertir en autorisations explicites) → retirer `Utilisateurs` en écriture, ne laisser que **Lecture et exécution**
- [ ] Même chose sur `C:\Entreprise\Logiciels` : retirer complètement `Utilisateurs`, ne laisser que `Administrateurs` et `SYSTEM`
- [ ] Créer `C:\Deploiement\logs`
- [ ] Copier le raccourci de `C:\Entreprise` dans `C:\Users\Public\Desktop`, le renommer **Dossiers Arve Services**

📸 **capture** → `16-arborescence-droits.png` *(onglet Sécurité de `C:\Entreprise\Modeles`)*

---

## Phase 12 — Vérification finale

- [ ] Copier le dossier `scripts` du projet dans la VM (`C:\Deploiement\`)
- [ ] Ouvrir PowerShell **en administrateur** et lancer :

```powershell
powershell -ExecutionPolicy Bypass -File C:\Deploiement\p5-verifier-conformite.ps1
```

- [ ] Vérifier le score : il doit être **≥ 95 %** et sans écart en catégorie Sécurité
- [ ] Corriger les éventuels écarts, relancer

📸 **capture** → `17-conformite-reference-console.png` *(synthèse du script dans la console)*
📸 **capture** → `18-conformite-reference-html.png` *(le rapport HTML ouvert dans le navigateur)*

**Arrêter le chronomètre ici.** Le total de ces 12 phases est la **mesure de référence
du déploiement manuel**, celle qui sera extrapolée à 10 postes dans le comparatif.

---

## Après la vérification

- [ ] Éteindre proprement la VM
- [ ] Dans VMware : **Snapshot** → nom `P5-reference-validee`
  *(indispensable : Sysprep ne peut être exécuté qu'un nombre limité de fois, et il rend la machine inutilisable comme poste de travail. Le snapshot permet de revenir en arrière.)*

📸 **capture** → `19-snapshot-reference-validee.png`
