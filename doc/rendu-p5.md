# Projet 5 — Déploiement standardisé d'un poste de travail

> **PPE — Cours 01 IT Essentials (module 187)** · Classe E1B · Geneva Institute of Technology
> **Paul Giocanti** · 17 septembre 2026
> Dépôt du projet : https://github.com/L4ami/ppe-projet5-deploiement-image-systeme

---

## Sommaire

1. Le problème à résoudre
2. Méthode retenue et justification des outils
3. Cahier des charges du poste standard
4. **Les livrables : le fichier de réponses et les scripts**
5. Le poste de référence STD-PG-01, construit à la main
6. Le contrôle de conformité, ou comment savoir ce qu'on a livré
7. Le déploiement automatisé STD-PG-02
8. L'image système (Sysprep + Clonezilla)
9. Comparatif de temps
10. Problèmes rencontrés et solutions
11. Méthodes et notions acquises
12. Conclusion

---

## 1 — Le problème à résoudre

**Arve Services SA** (entreprise fictive), PME genevoise d'une trentaine de
collaborateurs, ouvre un nouveau plateau et doit équiper **10 postes de travail
bureautiques identiques**. Le service informatique est composé d'une seule personne.

Installer dix machines une par une pose deux problèmes, et le second est le plus
grave :

- **Le temps.** Ce projet le mesure : **2 h 30 par poste**, soit plus de trois jours
  de travail pour le parc.
- **La divergence.** Un réglage oublié sur le poste 7, une version différente sur le
  poste 3, et le parc devient un ensemble de machines uniques. Le support ne peut
  plus raisonner « sur nos postes », il doit enquêter machine par machine.

L'objectif n'est donc pas seulement d'aller plus vite. C'est de pouvoir affirmer,
preuve à l'appui, que **les dix postes sont identiques**.

---

## 2 — Méthode retenue et justification des outils

L'énoncé autorise « une image système **ou** un script d'installation automatisée »
et cite deux ressources : **Windows Autopilot** et **Clonezilla**. Les deux ont été
étudiées ; voici ce qui a été retenu et pourquoi.

### Windows Autopilot — étudié, non retenu

Autopilot est la version *cloud* du même principe : le poste sort du carton, se
connecte à Internet, et se configure seul à partir d'un profil défini à l'avance par
le service informatique. C'est l'état de l'art.

Il est cependant **inapplicable ici** : Autopilot exige un abonnement **Microsoft
Entra ID** (l'annuaire d'identités de Microsoft, ex-Azure AD) et **Microsoft Intune**
(la console de gestion de parc). Sans tenant Microsoft 365, il n'y a tout simplement
rien à configurer. Le cahier des charges de l'entreprise exclut d'ailleurs tout
compte Microsoft.

Ce qui est retenu d'Autopilot, c'est **sa philosophie** : on ne transporte pas un
disque, on transporte une **description** du poste voulu. C'est exactement ce que
fait le fichier de réponses de ce projet.

### Clonezilla — retenu, mis en œuvre

Clonezilla est l'outil libre de référence pour capturer et restaurer un disque
entier. Il est gratuit, fonctionne hors ligne, et c'est la méthode historique du
déploiement de parc. Il est mis en œuvre au chapitre 7, avec **Sysprep**, l'outil
Microsoft qui prépare un poste à être cloné.

> *Note : la ressource de l'énoncé mentionne « Cloonix / Clonezilla ». Cloonix est un
> simulateur de réseau sans rapport avec le déploiement ; l'outil pertinent ici est
> bien Clonezilla.*

### Le fichier de réponses — retenu comme méthode principale

`autounattend.xml` est le mécanisme natif de Windows Setup : un fichier texte
contenant à l'avance les réponses aux questions de l'installation. Couplé à un script
PowerShell de post-installation, il donne un déploiement **sans aucune intervention**.

### Les trois méthodes sont comparées, pas choisies à l'aveugle

| Machine | Méthode | Ce qu'elle démontre |
|---|---|---|
| `STD-PG-01` | Installation et configuration **manuelles** | Le poste de référence exigé par la consigne, et la mesure du temps manuel |
| `STD-PG-02` | **Fichier de réponses + script PowerShell** | Déploiement sans intervention humaine |
| `STD-PG-03` | **Sysprep + image Clonezilla** | L'outil cité par l'énoncé, et ses limites réelles |

Les trois postes subissent **le même contrôle de conformité automatisé** : 59 points
vérifiés de façon identique. C'est ce qui permet d'affirmer qu'ils sont identiques
au lieu de le supposer.

---

## 3 — Cahier des charges du poste standard

Le cahier des charges complet est dans le dépôt
([`doc/cahier-des-charges.md`](https://github.com/L4ami/ppe-projet5-deploiement-image-systeme/blob/main/doc/cahier-des-charges.md)).
Voici les décisions structurantes et leur justification.

### Système et régionalisation

| Paramètre | Valeur | Pourquoi |
|---|---|---|
| Système | Windows 11 **Pro** 24H2 64 bits | L'édition Famille n'a ni BitLocker, ni stratégies locales (`secpol.msc`) : inutilisable en entreprise |
| Langue / format | Affichage fr-FR, format **fr-CH** | Dates JJ.MM.AAAA, monnaie CHF |
| Clavier | **Suisse romand** (`100C:0000100C`) | Correspond au clavier physique acheté |
| Fuseau | `W. Europe Standard Time` | Genève |

### Partitionnement — un choix qui a des conséquences

Disque **GPT** (*GUID Partition Table*, la table de partitions imposée par l'UEFI) :

| # | Partition | Taille | Rôle |
|---|---|---|---|
| 1 | Système EFI | 300 Mo | Chargeur de démarrage lu par l'UEFI |
| 2 | MSR | 16 Mo | Zone technique réservée à Windows |
| 3 | Windows | **reste du disque** | Système et données, lettre `C:` |

**Pas de partition de récupération séparée**, volontairement. En réservant la
dernière partition à WinRE, il faudrait figer la taille de la partition Windows dans
le fichier de réponses — et le déploiement casserait au premier poste livré avec un
disque de taille différente. Avec `Extend = true`, **le même fichier fonctionne sur
60 Go comme sur 1 To**. C'est exactement la propriété recherchée pour standardiser un
parc.

### Comptes — le moindre privilège appliqué par construction

| Compte | Groupe | Usage |
|---|---|---|
| `adm.local` | Administrateurs | Compte technique du support. Jamais utilisé pour travailler |
| `utilisateur` | Utilisateurs | Session du collaborateur, renommée à la livraison |

Un utilisateur qui travaille avec des droits d'administrateur exécute aussi ses
logiciels malveillants avec ces droits. Avec un compte standard, un rançongiciel
ouvert par erreur ne peut pas modifier le système ni les autres profils.

### Politique de mot de passe — la longueur plutôt que la complexité

12 caractères minimum, 180 jours de validité, 5 mots de passe mémorisés, verrouillage
à 5 tentatives pendant 15 minutes. Les **exigences de complexité sont volontairement
désactivées** : c'est la recommandation actuelle du NIST (SP 800-63B). Imposer
majuscule + chiffre + symbole pousse les utilisateurs vers `Motdepasse1!`, alors qu'un
minimum de 12 caractères force une vraie phrase de passe.

### Logiciels — un socle commun, sans suite bureautique

Le poste embarque **six logiciels** : Firefox, Thunderbird, Adobe Acrobat Reader,
7-Zip, VLC et Notepad++. Tous **gratuits et librement redistribuables** : l'image ou
le script se duplique dix fois sans aucune démarche de licence.

La **suite bureautique en est volontairement exclue**. C'est une décision
d'architecture : elle relève d'un choix par service, et surtout elle ferait vieillir
l'image beaucoup plus vite — chaque mise à jour majeure obligerait à reconstruire le
poste de référence. C'est le découpage qu'utilisent MDT et Intune : une **image socle
mince et stable**, puis des **paquets applicatifs** déployés par groupe
d'utilisateurs.

---

## 4 — Les livrables : le fichier de réponses et les scripts

Le déploiement repose sur **cinq fichiers** : un fichier de réponses et quatre
scripts PowerShell. Ils font au total une trentaine de kilo-octets — à comparer aux
dix gigaoctets d'une image disque. Voici ce que fait chacun et, surtout, pourquoi il
est écrit comme ça.

### `autounattend.xml` — le fichier de réponses

Un fichier de réponses est un fichier texte que Windows Setup lit automatiquement s'il
le trouve **à la racine** d'un lecteur amovible ou d'un CD. Il contient à l'avance les
réponses aux questions de l'installation.

Sa particularité est de s'exécuter en **trois passes indépendantes**, à trois moments
différents :

| Passe | Moment | Ce qu'on y met |
|---|---|---|
| `windowsPE` | avant que Windows existe | langue de Setup, partitionnement, édition, licence |
| `specialize` | Windows copié sur le disque | nom du poste, fuseau horaire, groupe de travail |
| `oobeSystem` | premier démarrage | comptes, écrans de bienvenue, commandes de première session |

La version finale ne conserve que **`windowsPE`** — les deux autres passes échouaient
systématiquement sur cette build (voir chapitre 10, problème P7). Trois choix
méritent d'être expliqués :

**Le partitionnement extensible.** La partition Windows est déclarée avec
`Extend = true` plutôt qu'avec une taille fixe :

```xml
<CreatePartition wcm:action="add">
  <Order>3</Order>
  <Type>Primary</Type>
  <Extend>true</Extend>
</CreatePartition>
```

Conséquence : **le même fichier fonctionne sur un disque de 60 Go comme sur un disque
de 1 To**, sans jamais être modifié. C'est la raison pour laquelle le cahier des
charges renonce à une partition de récupération séparée, qui aurait imposé de figer
les tailles.

**L'édition désignée par une clé, pas par un nom.** Sur le média français, l'édition
s'appelle « Windows 11 **Professionnel** ». Un fichier qui la désigne par son nom
échoue sur ce média. Le nôtre passe par la **clé générique Microsoft** de Windows 11
Pro, qui n'active rien mais indique à Setup quelle édition extraire — indépendamment
de la langue.

**La neutralisation des contrôles matériels.** Cinq commandes de registre écrites dans
`HKLM\SYSTEM\Setup\LabConfig` désactivent les vérifications TPM, Secure Boot, RAM,
processeur et disque. C'est une concession au laboratoire, documentée comme telle : sur
le parc physique réel, le cahier des charges impose TPM 2.0 et Secure Boot, et ce bloc
doit être retiré.

### `p5-post-install.ps1` — la configuration du poste

C'est le cœur du déploiement : **9 étapes**, de l'identité du poste au rapport final.
Quatre principes ont guidé son écriture.

**Il est idempotent.** Le relancer ne casse rien : chaque étape vérifie l'état avant
d'agir. Un compte déjà présent n'est pas recréé, un poste déjà nommé n'est pas
renommé. C'est indispensable pour un script de déploiement — on doit pouvoir le
relancer sur un poste à moitié configuré, ou pour remettre en conformité un poste qui
a dérivé.

**Il chronomètre et journalise tout.** Chaque étape passe par une fonction unique qui
mesure sa durée et capture ses erreurs sans interrompre le reste :

```powershell
function Invoke-Etape {
    param([string]$Nom, [scriptblock]$Action)
    $chrono = [System.Diagnostics.Stopwatch]::StartNew()
    $statut = 'OK'
    try { & $Action } catch { $statut = 'ECHEC'; Write-Warning $_.Exception.Message }
    $chrono.Stop()
    $script:Etapes += [pscustomobject]@{
        Etape = $Nom; Statut = $statut
        Secondes = [math]::Round($chrono.Elapsed.TotalSeconds, 1)
    }
}
```

C'est ce qui produit le comparatif de temps du chapitre 9 : les durées ne sont pas
estimées, elles sont mesurées par le script lui-même. En plus, `Start-Transcript`
écrit une transcription complète **au fil de l'eau** — pas à la fin — pour qu'une
interruption ne fasse pas tout perdre.

**Il désigne les objets Windows par leur identifiant, jamais par leur nom.** Les
groupes locaux et les règles de pare-feu sont traduits : `Administrators` s'appelle
`Administrateurs` sur un Windows français. Un script qui les nomme casse dès qu'on
change de langue. Le nôtre utilise les **SID** (`S-1-5-32-544` pour Administrateurs,
`S-1-5-32-545` pour Utilisateurs) et les **identifiants de ressource** des règles de
pare-feu (`@FirewallAPI.dll,-32752` pour la découverte de réseau). Ces identifiants
sont invariants.

**Il est paramétrable.** Le numéro du poste se donne en paramètre, se lit dans le
fichier `poste.txt` du média, ou à défaut se déduit du numéro de série du matériel.
C'est ce qui permet d'utiliser **un seul fichier de réponses et un seul script pour
les dix postes**.

### `p5-verifier-conformite.ps1` — la preuve

Ce script lit l'état réel de la machine et le compare, point par point, au cahier des
charges : **59 contrôles** répartis en 9 catégories. Il repose sur une seule fonction,
qui prend une exigence, une valeur attendue et un moyen de mesurer la valeur réelle :

```powershell
Test-Exigence 'Securite' 'Verrouillage auto apres 900 s' '900' {
    Get-ValeurRegistre $polSystem 'InactivityTimeoutSecs'
}
```

Cinq modes de comparaison sont disponibles (égalité, contient, motif, vrai/faux,
supérieur ou égal), ce qui permet d'écrire aussi bien « le nom doit correspondre au
motif `STD-PG-NN` » que « la mémoire doit être d'au moins 8 Go ».

Il produit un score, un fichier CSV et un **rapport HTML** lisible. Le verdict n'est
pas qu'une histoire de pourcentage : le critère d'acceptation est **score ≥ 95 % ET
zéro écart en catégorie Sécurité**. Un poste à 98 % dont le verrouillage de compte est
mal réglé reste refusé.

### `p5-creer-iso-config.ps1` — le média de déploiement

Il fabrique l'ISO de 124 Ko qui contient le fichier de réponses et les scripts,
**sans aucun outil externe** : il pilote **IMAPI2**, le composant de gravure intégré à
Windows depuis Vista, via des objets COM. Aucune dépendance à installer, donc le
projet fonctionne sur n'importe quel poste Windows.

Il synchronise aussi automatiquement le contenu du média avec le dossier `scripts\`
avant chaque fabrication — impossible d'oublier de mettre à jour l'ISO après avoir
corrigé un script, une erreur qui a été commise une fois pendant le projet.

### `p5-chrono.ps1` — l'instrument de mesure

Un chronomètre à tours : il affiche une phase, note l'heure, attend une frappe, et
passe à la suivante. Sa valeur tient à deux propriétés : il applique **le même
découpage et le même instrument** aux deux scénarios — comparer deux chiffres obtenus
par deux méthodes différentes n'aurait aucune valeur — et il écrit son CSV **après
chaque phase**, avec un paramètre de reprise, correction apportée après avoir failli
perdre toutes les mesures en fermant la fenêtre par accident.

### Ce que ces cinq fichiers représentent

| | Image disque | Ces fichiers |
|---|---|---|
| Taille | ~10 Go | **~30 Ko** |
| Versionnable dans Git | non | **oui, avec l'historique** |
| Modifier un paramètre | restaurer, modifier, re-sysprep, recapturer | **changer une ligne** |
| Dépend du matériel | oui | **non** |
| Relisible par un humain | non | **oui** |

C'est tout l'argument du projet : on ne transporte pas un disque, on transporte une
**description** du poste voulu.

---

## 5 — Le poste de référence STD-PG-01, construit à la main

La consigne demande un poste de référence. Il a été construit **entièrement
manuellement**, écran par écran, en chronométrant chacune des **12 phases**. Ce
chronométrage sert deux fois : il valide que le poste est conforme, et il fournit la
mesure « installation manuelle » du comparatif final. Aucun travail perdu.

### La VM, et deux pièges évités

![Paramètres de la machine virtuelle STD-PG-01](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/01-vm-reference-parametres.png)

*La machine reprend le plancher matériel du cahier des charges : 2 processeurs,
8 Go de RAM, disque SATA, firmware UEFI, réseau NAT. Le module TPM apparaît en bas
de la liste : VMware en ajoute un automatiquement pour un invité Windows 11, ce qui
rend le poste réellement conforme à l'exigence TPM 2.0 au lieu de la contourner.*

Deux choix de l'assistant méritent d'être signalés, parce qu'ils décident de la
suite :

- **« J'installerai le système d'exploitation ultérieurement »** — désigner l'ISO à
  cet écran déclenche l'*Easy Install* de VMware, qui fabrique son propre fichier de
  réponses. La mesure du temps manuel aurait été faussée, et ce fichier serait entré
  en conflit avec le nôtre au moment du déploiement automatisé.
- **Disque SATA plutôt que NVMe** — un disque SATA s'appelle `sda` sous Clonezilla,
  un NVMe `nvme0n1`. Choisir SATA, c'est s'épargner une source de confusion pour la
  suite.

### Vérifier l'édition avant de partir

![Éditions contenues dans l'ISO](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/02-editions-iso.png)

*`Get-WindowsImage` liste les onze éditions contenues dans le fichier `install.wim`
du média. L'index 6 s'appelle **« Windows 11 Professionnel »** — et non « Windows 11
Pro ».*

Cette vérification, faite avant même de démarrer, a évité un échec : un fichier de
réponses qui désigne l'édition par son nom aurait planté sur ce média français. Le
nôtre la désigne par la **clé générique Microsoft** de Windows 11 Pro, qui n'active
rien mais indique à Setup quelle édition extraire, indépendamment de la langue.

### L'installation manuelle : quinze questions

![Installation manuelle de Windows](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/04-installation-windows-manuelle.png)

*L'écran de copie des fichiers — atteint après avoir répondu à une quinzaine
d'écrans : langue, format, clavier, type d'installation, clé de produit, édition,
contrat de licence, choix du disque.*

### L'OOBE, et une manipulation non documentée

![Création du compte local via ms-cxh](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/05-oobe-compte-local.png)

*La fenêtre « Qui va utiliser cet appareil ? », obtenue par la commande
`start ms-cxh:localonly` lancée depuis `Maj+F10`.*

Windows 11 24H2 **ne propose plus aucun moyen documenté de créer un compte local**
pendant l'OOBE : l'écran « Déverrouillez votre expérience Microsoft » n'offre qu'un
bouton `Se connecter`, et l'ancienne option « Joindre le domaine à la place » a
disparu. Il faut passer par un protocole interne de Windows.

Cette manipulation **disparaît complètement** en déploiement automatisé : le fichier
de réponses crée le compte dans la passe `oobeSystem`, et l'écran n'est jamais
affiché. C'est un argument en faveur de l'automatisation qui n'a rien à voir avec le
temps gagné.

### Configuration : identité, comptes, régionalisation

![Comptes locaux créés](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/09-comptes-crees.png)

*La console `lusrmgr.msc` — disponible uniquement en édition Pro — avec les deux
comptes du cahier des charges. `utilisateur` n'appartient qu'au groupe Utilisateurs.*

![Politique de mot de passe](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/10-politique-mot-de-passe.png)

*`secpol.msc` : 12 caractères minimum, 180 jours de validité, 5 mots de passe
mémorisés, durée de vie minimale d'un jour. Cette dernière valeur n'est pas
cosmétique : sans elle, un utilisateur peut changer cinq fois de mot de passe en deux
minutes pour revenir à son préféré et contourner l'historique.*

![Copie des paramètres régionaux](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/11-regional-copie-parametres.png)

*L'écran le plus souvent oublié d'un déploiement. Les réglages régionaux ne
s'appliquent par défaut qu'au compte courant : sans ces deux cases, le collaborateur
qui ouvre sa session pour la première fois tombe sur un clavier QWERTY américain. Les
trois colonnes affichent bien « Français (Suisse) » pour l'utilisateur actuel,
l'écran d'accueil et les nouveaux comptes.*

### Réseau et sécurité

![Pare-feu actif sur les trois profils](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/12-pare-feu-trois-profils.png)

*Le pare-feu est actif sur les profils Domaine, Privé et Public. La mention « Le
profil privé est actif » confirme que la carte réseau est bien classée en réseau
d'entreprise — nécessaire au partage entre les postes du groupe de travail, sans
désactiver le pare-feu pour autant.*

![Limite d'inactivité de session](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/13-securite-uac-verrouillage.png)

*`secpol.msc` : verrouillage automatique de la session après 900 secondes. Deux des
trois réglages UAC visés étaient déjà aux bonnes valeurs par défaut — le contrôle de
conformité le confirmera plus loin, chiffres à l'appui.*

### Nettoyage et logiciels

![Applications après nettoyage](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/14a-applications-supprimees.png)

*De 23 à 18 applications. Constat inattendu : la build 24H2 européenne utilisée est
déjà bien plus légère que la liste théorique — ni Clipchamp, ni Actualités, ni Météo,
ni Xbox. Les cinq retraits réellement pertinents étaient Teams, Bing, Microsoft 365,
Outlook et OneDrive. Leçon : on constate avant de scripter.*

![Logiciels métier installés](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/15a-logiciels-installes.png)

*Le socle logiciel, installé à la main en allant chercher chaque installeur sur le
site de son éditeur. C'est la phase qui porte l'essentiel de l'écart avec
l'automatisation : **14,5 minutes**.*

### Droits NTFS : le piège de l'héritage

![Droits sur le dossier Modeles](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/16-arborescence-droits.png)

*Résultat de la commande `icacls` sur `C:\Entreprise\Modeles` : seuls Utilisateurs
(lecture et exécution), Système et Administrateurs (contrôle total) subsistent.*

La difficulté ici n'est pas celle qu'on attend. Le groupe `Utilisateurs` n'avait déjà
que la lecture — c'est **`Utilisateurs authentifiés`** qui posait problème : tout
dossier créé à la racine de `C:\` hérite pour ce groupe d'une autorisation
**Modification**, c'est-à-dire pour n'importe quel compte connecté. Il fallait donc
casser l'héritage (`/inheritance:r`) et réattribuer les droits explicitement.

Les groupes sont désignés par leur **SID** (`S-1-5-32-544` pour Administrateurs,
`S-1-5-32-545` pour Utilisateurs) et non par leur nom : un identifiant de sécurité ne
change jamais, un libellé est traduit. La même commande fonctionne sur un Windows
anglais.

---

## 6 — Le contrôle de conformité, ou comment savoir ce qu'on a livré

Un poste « conforme au cahier des charges », ça ne se constate pas à l'œil. J'ai donc
écrit un script qui lit l'état réel de la machine et le compare, point par point, à ce
qui est écrit dans le cahier des charges : **59 contrôles**, répartis en 9 catégories,
qui produisent un score, un fichier CSV et un rapport HTML.

Critère d'acceptation fixé à l'avance : **score ≥ 95 % ET aucun écart en catégorie
Sécurité**.

### Premier passage : le poste de référence est refusé

![Contrôle de conformité en console](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/17-conformite-reference-console.png)

*Premier passage sur STD-PG-01, pourtant configuré avec soin pendant plus de deux
heures : **59 contrôles, 46 conformes, 13 écarts, score 78 %, verdict POSTE REFUSÉ.***

C'est le résultat le plus important du projet, et il était inattendu. L'analyse a
séparé deux natures d'écarts très différentes.

**Deux défauts de l'outil de contrôle.** La longueur minimale du mot de passe
remontait `1` au lieu de `12` : mon filtre cherchait `minimale du mot de passe` et
capturait la ligne « Ancienneté **minimale du mot de passe** (jours) : 1 », qui
apparaît avant la bonne dans la sortie de `net accounts`. Même problème sur le seuil
de verrouillage, dont le libellé exact est « Seuil de verrouillage ». Les deux valeurs
étaient correctement configurées sur le poste. **Leçon retenue :** analyser une sortie
de commande localisée par correspondance de texte est fragile.

**Onze écarts réels — dont six invisibles.** Les six applications désinstallées via
`Paramètres → Applications installées` étaient **toujours présentes**. L'interface
graphique de Windows ne retire une application que pour le **compte courant** ; le
paquet reste enregistré pour les autres utilisateurs et, surtout, dans le **modèle de
profil**. Tout nouveau compte créé sur le poste les aurait récupérées intégralement.
Sur dix postes livrés à dix collaborateurs, le ménage aurait été annulé à la première
ouverture de session.

Le retrait complet exige deux opérations distinctes, là où l'interface n'en propose
qu'une :

```powershell
Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers
Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq $app |
    Remove-AppxProvisionedPackage -Online
```

Les cinq autres écarts venaient de réglages posés à un endroit du registre différent
de celui attendu (SmartScreen, exécution automatique des supports) ou simplement
absents (mises à jour automatiques, blocage des applications indésirables, niveau
d'UAC).

**Les onze écarts ont été corrigés avec exactement les commandes qu'exécute le script
de déploiement**, et non à la souris. C'était impératif : le poste de référence doit
être reproductible à l'identique par le script, sinon le contrôle de STD-PG-02 aurait
remonté des différences.

### Deuxième passage : 98,3 %, un seul écart

Un seul point restait rouge : seuil de verrouillage du compte à **10** au lieu de 5.
Windows 11 24H2 impose ce défaut, et la valeur saisie dans `secpol.msc` n'avait pas
survécu au redémarrage. Corrigée par `net accounts /lockoutthreshold:5`.

Le verdict est resté **POSTE REFUSÉ** malgré les 98,3 %, et c'est voulu : le critère
exige zéro écart en Sécurité. Un poste dont le verrouillage ne se déclenche qu'au
dixième essai au lieu du cinquième n'est pas conforme, même à 98 %.

### Troisième passage : 100 %

![Rapport HTML du poste de référence](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/18-conformite-reference-html.png)

*Le rapport HTML généré par le script : badge **100 %**, 59 contrôles conformes sur
59, 0 écart, verdict **POSTE ACCEPTÉ**. Chaque ligne indique l'exigence, la valeur
attendue et la valeur réellement mesurée sur la machine.*

### Ce que cet épisode démontre

Un poste configuré **manuellement**, avec attention, en suivant une procédure écrite,
présentait **treize non-conformités** dont six totalement invisibles dans l'interface
de Windows. Aucune n'aurait été détectée par une relecture visuelle, ni par le
technicien qui venait de passer deux heures dessus.

C'est l'argument central de ce projet, et il ne porte pas sur la vitesse :
**l'automatisation est le seul moyen de savoir ce qu'on a réellement livré.**

---

## 7 — Le déploiement automatisé STD-PG-02

### Le média de déploiement

Windows Setup cherche automatiquement un fichier nommé `autounattend.xml` **à la
racine** de chaque lecteur amovible et de chaque lecteur de CD/DVD présent au
démarrage. Il n'est donc pas nécessaire de reconstruire l'ISO de Windows, qui pèse
5,8 Go : il suffit de présenter à la machine un **second CD** de 124 Ko contenant le
fichier de réponses et les scripts.

![Fabrication du média de configuration](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/20-media-config-iso-cree.png)

*Le script `p5-creer-iso-config.ps1` synchronise le fichier de réponses et les scripts
dans un dossier, écrit le numéro du poste à déployer, et fabrique l'image ISO. Il
n'utilise aucun outil externe : il pilote **IMAPI2**, le composant de gravure intégré
à Windows depuis Vista, via des objets COM. Résultat : **124 Ko**.*

![Les deux lecteurs CD de la machine cible](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/22-vm-std-pg-02-deux-lecteurs.png)

*La machine cible reçoit deux lecteurs : le premier avec l'ISO de Windows 11, le
second avec `PPE-P5-Config.iso`. C'est tout ce qu'il faut pour déclencher
l'installation pilotée.*

### L'installation, sans une seule question

![Installation automatisée en cours](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/23-install-auto-aucune-question.png)

*L'écran de copie des fichiers. À comparer avec la capture équivalente du poste de
référence : c'est **le même écran**, sauf qu'ici il a été atteint sans répondre à
quoi que ce soit.*

Le fichier de réponses a répondu à la place du technicien pour : la langue
d'installation, le format régional suisse, la disposition de clavier suisse romande,
l'effacement complet du disque, la création des trois partitions GPT, le choix de
l'édition Professionnel via la clé générique, et l'acceptation du contrat de licence.
**Une quinzaine d'écrans supprimés.**

### Le script de post-installation

![Script de post-installation en cours](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/25-script-post-install-en-cours.png)

*Le script s'exécute en neuf étapes, chacune chronométrée et journalisée. On voit ici
les étapes 4 à 7 : réseau et pare-feu en 39,4 s, sécurité complète en 33,8 s,
nettoyage de **17 paquets plus OneDrive** en 23,2 s, puis l'installation des logiciels
par winget.*

Le contraste avec les mesures manuelles est net :

| Étape | Automatisé | Manuel (poste de référence) |
|---|---|---|
| Comptes et politique de mot de passe | **0,9 s** | 17,8 min |
| Régionalisation complète | **1,4 s** | 12,1 min |
| Réseau et pare-feu | **39,4 s** | 4,0 min |
| Sécurité (UAC, verrouillage, SmartScreen, Defender, PUA) | **33,8 s** | 13,0 min |
| Nettoyage des applications | **23,2 s** | 8,0 min — **et incomplet** |
| Logiciels métier | **5,2 min** | 14,5 min |

![Récapitulatif du script](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/26-script-post-install-fin.png)

*Le récapitulatif final : **durée totale du déploiement automatisé, 7,03 minutes**,
avec le détail par étape et par logiciel. L'étape 7 (winget, 314 s) représente à elle
seule **74 % du temps du script** — tout le reste, c'est-à-dire l'intégralité de la
configuration du poste, prend **moins de deux minutes**.*

C'est un enseignement en soi : ce qui coûte cher dans un déploiement manuel, ce n'est
pas l'installation du système ni celle des logiciels — c'est la **configuration**,
faite d'une centaine de petits réglages dispersés dans une dizaine d'interfaces. Et
c'est précisément ce que le script réduit à rien.

![Rapport de déploiement sur le bureau](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/26b-rapport-deploiement-bureau.png)

*Le script dépose un rapport sur le bureau du poste. Un technicien qui reprend la
machine dans six mois sait exactement ce qui a été fait, quand, et en combien de
temps. Aucun équivalent n'existe pour un déploiement manuel.*

### La preuve : le même contrôle, le même résultat

![Contrôle de conformité de STD-PG-02](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/27-conformite-02-console.png)

*Les **mêmes 59 contrôles**, exécutés par le même script sur la machine déployée :
59 conformes, 0 écart, **score 100 %, POSTE ACCEPTÉ**.*

![Rapport HTML de STD-PG-02](https://raw.githubusercontent.com/L4ami/ppe-projet5-deploiement-image-systeme/main/captures/28-conformite-02-html.png)

*Le rapport HTML de STD-PG-02. Mis côte à côte avec celui de STD-PG-01, il constitue
la démonstration demandée par la consigne : les deux postes sont identiques, ligne
par ligne, valeur mesurée par valeur mesurée.*

**Et le chemin parcouru compte autant que le résultat :**

| | STD-PG-01 (manuel) | STD-PG-02 (automatisé) |
|---|---|---|
| Passages du contrôle nécessaires | **3** | **1** |
| Écarts à corriger | **13** | **0** |
| Score final | 100 % | 100 % |

Le poste manuel a exigé trois passages et treize corrections pour atteindre la
conformité. Le poste automatisé l'atteint **du premier coup**. Le script ne peut pas
oublier ; un humain, si.

---

## 8 — L'image système (Sysprep + Clonezilla)

Cette branche a été **étudiée et entièrement documentée**, mais **non exécutée**,
faute de temps. La procédure complète est dans le dépôt
([`doc/procedure-image-clonezilla.md`](https://github.com/L4ami/ppe-projet5-deploiement-image-systeme/blob/main/doc/procedure-image-clonezilla.md)),
ainsi que le fichier de réponses correspondant (`deploiement/sysprep-unattend.xml`).
Voici ce qu'elle apporte et ce qu'elle coûte.

### Pourquoi Sysprep est obligatoire avant toute capture

Un disque Windows contient l'**identité unique** de la machine : le **SID**
(*Security Identifier*), le numéro d'identité utilisé par Windows pour les
autorisations et l'authentification réseau, le nom du poste, l'identifiant
d'activation, l'historique des pilotes.

Cloner un disque tel quel donne dix machines portant **le même SID**. En groupe de
travail, cela provoque des échecs d'authentification sur les partages ; en domaine
Active Directory, la seconde machine ne peut tout simplement pas rejoindre le
domaine. C'est aussi une configuration que Microsoft refuse de supporter.

`sysprep /generalize` supprime cette identité. Au démarrage suivant, Windows en
régénère une neuve et repasse par les écrans de bienvenue — auxquels le fichier
`sysprep-unattend.xml` répond automatiquement. À noter : `/generalize` n'est
utilisable qu'un nombre limité de fois sur une même installation (compteur *rearm*,
3 fois par défaut). D'où le snapshot `P5-reference-validee` pris avant toute
manipulation.

### Ce que Clonezilla apporte

Clonezilla est l'outil libre de référence pour capturer et restaurer un disque
entier. Gratuit, hors ligne, il ne copie **que les blocs utilisés** du système de
fichiers : une image d'un disque de 60 Go ne pèse qu'une dizaine de gigaoctets. Les
deux opérations sont `savedisk` et `restoredisk`.

### Ses limites, et pourquoi le script l'emporte ici

| Limite de l'image | Conséquence concrète |
|---|---|
| Contient les pilotes du matériel de référence | Un parc hétérogène impose une image par modèle, ou l'injection de pilotes avec **DISM** |
| Taille | Une dizaine de Go à stocker et à transporter, contre **124 Ko** pour le média de configuration |
| Vieillissement | L'image est figée : au bout de trois mois, chaque poste restauré doit télécharger trois mois de mises à jour |
| Modification | Changer un paramètre impose de restaurer le poste de référence, le modifier, le re-syspreper et le recapturer — contre **une ligne** à changer dans un script |
| Versionnement | Un fichier de 10 Go ne se met pas dans Git ; un script de 30 Ko oui, avec l'historique de ses modifications |
| Compteur *rearm* | `/generalize` n'est utilisable qu'un nombre limité de fois |

C'est exactement pour ces raisons que l'industrie a basculé vers l'installation
automatisée et le provisionnement (**Windows Autopilot**, **Microsoft Intune**,
**MDT**) : on ne transporte plus un disque, on transporte une **description** du poste
voulu. L'image système garde sa place là où le script ne peut rien — un parc
homogène, hors ligne, sans accès Internet pour winget.

---

## 9 — Comparatif de temps

Les deux scénarios ont été mesurés avec **le même instrument** : un script
chronomètre (`p5-chrono.ps1`) qui enregistre l'heure de début et de fin de chaque
phase et produit un CSV. Comparer deux chiffres obtenus par deux méthodes
différentes n'aurait aucune valeur.

### Phase par phase

| Phase | Manuel | Automatisé |
|---|---|---|
| Création et paramétrage de la VM | 0,1 min | 0,3 min |
| Installation de Windows | 12,2 min | 14,0 min |
| Écrans de bienvenue (OOBE) | 48,2 min | 7,3 min |
| Identité du poste et groupe de travail | *(incluse ci-dessus)* | **8,3 s** |
| Comptes et politique de mot de passe | 17,8 min | **0,9 s** |
| Réglages régionaux | 12,1 min | **1,4 s** |
| Réseau et pare-feu | 4,0 min | **39,4 s** |
| Sécurité | 13,0 min | **33,8 s** |
| Nettoyage des applications | 8,0 min | **23,2 s** |
| Logiciels métier | 14,5 min | **5,2 min** |
| Arborescence et droits NTFS | 8,6 min | **0,3 s** |
| Contrôle de conformité | 11,6 min *(+ 13 corrections)* | ~1 min *(0 écart)* |
| **TOTAL** | **150,1 min** | **47,4 min** |

> **Une réserve d'honnêteté sur la ligne OOBE.** Les 48,2 minutes du poste manuel
> incluent un long téléchargement de mises à jour déclenché par Windows 11 24H2
> pendant la phase de bienvenue, qui ne s'est pas reproduit sur le second poste. Cet
> écart n'est donc **pas entièrement imputable à l'automatisation**. Le comparatif qui
> suit isole la partie réellement attribuable au script.

### Le chiffre qui compte : la configuration

En retirant l'installation du système et l'OOBE — deux phases dont la durée dépend
surtout de la machine et du réseau — il reste le **travail de configuration**, celui
que le script remplace réellement :

| | Manuel | Automatisé |
|---|---|---|
| Configuration complète du poste | **78,0 min** | **7,0 min** |
| Réduction | — | **− 91 %** |

Et à l'intérieur de ces 7 minutes, **5,2 sont consacrées au téléchargement des
logiciels**. La configuration proprement dite — identité, comptes, politique de mot de
passe, régionalisation, réseau, pare-feu, sécurité, nettoyage, arborescence, droits
NTFS — prend **moins de deux minutes**.

### Extrapolation aux 10 postes du cahier des charges

| | Manuel | Automatisé |
|---|---|---|
| Par poste | 150,1 min | 47,4 min |
| **Pour 10 postes** | **25 h 02** | **7 h 54** |
| Gain brut | — | **17 h 08** |

### Le seuil de rentabilité

Automatiser a un coût d'entrée : rédiger le cahier des charges, écrire le fichier de
réponses et les quatre scripts, et les tester représente environ **une journée de
travail, soit 8 heures** — c'est le temps réellement passé sur ce projet.

- Gain par poste : **1 h 43**
- Coût de préparation : **8 h**
- **Seuil de rentabilité : 8 ÷ 1,71 ≈ 4,7 postes**

**L'automatisation devient rentable à partir du 5ᵉ poste.** Sur les 10 postes du
cahier des charges, le gain net est de **9 heures** après amortissement de la
préparation. Sur 20 postes, de 26 heures. Et la préparation, elle, ne se paie
qu'une fois : le fichier de réponses et les scripts resservent au prochain
renouvellement de parc.

### Le temps d'intervention humaine

C'est la métrique que regarde un responsable informatique, et elle est plus
favorable encore que le temps total.

| | Manuel | Automatisé |
|---|---|---|
| Technicien devant la machine | quasiment les 150 min | **≈ 9 min** |
| Détail | chaque écran, chaque clic | une frappe au démarrage · 7,3 min d'OOBE · lancement du script · lancement du contrôle |

Pendant les 38 minutes restantes, la machine travaille seule et le technicien prépare
le poste suivant. **Sur dix postes, cela change la nature du travail** : on ne fait
plus dix installations à la chaîne, on en lance dix et on les contrôle.

### Ce que le temps ne mesure pas

Le gain le plus important de ce projet n'apparaît dans aucun tableau : le poste
manuel a nécessité **trois passages du contrôle de conformité et treize corrections**
pour atteindre 100 %, dont six non-conformités **invisibles dans l'interface de
Windows**. Le poste automatisé atteint 100 % **du premier coup**.

Sur dix postes déployés à la main, il faudrait soit accepter dix postes
potentiellement divergents, soit refaire dix fois ce travail de contrôle et de
correction — ce qui ferait exploser le comparatif bien au-delà des chiffres
ci-dessus.

---

## 10 — Problèmes rencontrés et solutions

Huit incidents ont jalonné ce projet. Ils sont consignés ici avec leur cause réelle et
la correction appliquée — plusieurs ont plus appris que les étapes qui ont fonctionné
du premier coup.

### P1 — L'assistant VMware installe Windows tout seul *(évité)*

À l'écran « Installation du système d'exploitation invité », désigner directement
l'ISO déclenche la fonction *Easy Install* de VMware : le logiciel fabrique son propre
fichier de réponses et installe Windows sans poser de question. La mesure du temps
manuel aurait été faussée, et ce fichier serait entré en conflit avec le nôtre.
**Solution :** cocher « J'installerai le système ultérieurement » et monter l'ISO
manuellement après la création de la machine.

### P2 — L'édition ne s'appelle pas « Pro » sur un média français

`Get-WindowsImage` sur l'ISO française liste onze éditions, dont l'index 6 nommé
**« Windows 11 Professionnel »**. Un fichier de réponses qui désigne l'édition par son
nom (`/IMAGE/NAME = "Windows 11 Pro"`) échoue sur ce média : Setup s'arrête et
redemande quelle édition installer. **Solution :** désigner l'édition par la **clé
générique Microsoft** de Windows 11 Pro. Cette clé n'active rien — elle indique
seulement à Setup quelle édition extraire, quelle que soit la langue du média.

### P3 — Windows 11 24H2 ne propose plus de créer un compte local

Pendant l'OOBE, l'écran « Déverrouillez votre expérience Microsoft » n'offre qu'un
bouton `Se connecter`. L'option officielle « Joindre le domaine à la place », encore
présente sur les versions précédentes de Windows 11 Pro, a disparu.
**Solution :** `Maj + F10` pour ouvrir une invite de commandes, puis
`start ms-cxh:localonly` — un protocole interne de Windows qui ouvre directement la
boîte de dialogue de création d'un compte local.
**Ce que ça démontre :** cette manipulation non documentée devient inutile dès que le
fichier de réponses crée les comptes lui-même.

### P4 — Le poste se nomme d'après le compte, et le renommage exige un redémarrage

Après création du compte `adm.local`, la vérification affichait les comptes sous la
forme `adm-local\adm.local` : Windows 11 24H2 avait nommé la machine **ADM-LOCAL**,
d'après le premier compte créé. Le renommage en `STD-PG-01` semblait accepté, mais le
nom affiché restait l'ancien — **un renommage n'est effectif qu'après redémarrage**.
**Solution :** redémarrer, puis vérifier avec
`Get-CimInstance Win32_ComputerSystem | Select Name, Workgroup`.
**Ce que ça démontre :** sur dix postes à la main, c'est dix occasions d'oublier ce
redémarrage. Le fichier de réponses fixe le nom dans la passe `specialize`, avant même
la première ouverture de session : l'erreur devient impossible.

### P5 — Décalage du chronomètre entre deux phases

Le passage à la phase suivante a été oublié en arrivant sur le bureau : le renommage
du poste a été mesuré à l'intérieur de la phase précédente. **Correction :** phases
fusionnées dans le tableau, avec mention explicite. Le total reste exact.
**Ce que ça démontre :** une mesure manuelle dépend d'un opérateur attentif ; une
mesure produite par un script, comme celle du déploiement automatisé, n'a pas ce
défaut. C'est une limite méthodologique à assumer.

### P6 — Le contrôle de conformité refuse le poste de référence

Traité en détail au chapitre 6. Treize écarts, dont deux dus à des défauts de l'outil
de contrôle lui-même et **six applications « désinstallées » qui étaient toujours
présentes**.

### P7 — Échec des passes `specialize` et `oobeSystem` du fichier de réponses

**Symptôme.** L'installation se déroule correctement jusqu'à la phase de
personnalisation, puis affiche : *« Windows n'a pas pu terminer l'installation. »*

**Ce qui fonctionnait.** Le journal `C:\Windows\Panther\setupact.log` contient la ligne
`Copy unattend payload from E:\autounattend.xml` : le fichier a bien été trouvé et
appliqué. Preuve visuelle supplémentaire : un disque contenant déjà une installation
Windows a été **remis à zéro automatiquement** par la directive `WillWipeDisk`.

Autre preuve observée à l'écran : au redémarrage suivant, l'assistant d'installation
affichait un disque de **64 Go entièrement non alloué**, alors qu'il contenait une
installation de Windows deux minutes plus tôt. La passe `windowsPE` s'exécute donc
correctement — l'échec est postérieur.

**Deux tentatives de correction, deux échecs.**

| Tentative | Modification | Raisonnement |
|---|---|---|
| 1 | Retrait de `Microsoft-Windows-UnattendedJoin` (groupe de travail) et de `Microsoft-Windows-Deployment` (clé `BypassNRO`) | Ne garder dans le fichier de réponses que ce que lui seul peut faire |
| 2 | Un seul compte local au lieu de deux, groupe écrit `Administrators` au lieu de `Administrateurs` | Un libellé de groupe traduit non résolu fait échouer la création du compte, donc toute la passe |

**Décision.** Retirer les passes `specialize` et `oobeSystem`. Le fichier de réponses
final ne conserve que `windowsPE`, vérifiée à l'exécution. Le contenu complet est
archivé dans `autounattend-complet-non-fonctionnel.xml` comme trace de la démarche.

**Conséquence.** Le déploiement n'est plus « zéro-touche » intégral : il reste 7,3
minutes de phase de bienvenue à passer à la main. Mais le fichier de réponses
supprime toujours une quinzaine d'écrans, et **la totalité du travail de
configuration reste automatisée** — c'est-à-dire l'essentiel du temps.

**Ce que ça enseigne.** Un fichier de réponses n'est pas un tout-ou-rien : il
s'exécute en **passes indépendantes**, et une passe peut réussir pendant qu'une autre
échoue. Le bon réflexe en production n'est pas de déboguer un XML pendant des heures,
mais de **réduire le fichier à ce qui est vérifié** et de déplacer le reste vers un
script — qui, lui, est testable, journalisé et corrigible en une ligne. C'est
exactement le rapport de force entre image et script décrit au chapitre 2.

### P8 — Boucle de démarrage infinie causée par l'ordre d'amorçage

L'installation recommençait depuis le début à chaque redémarrage. **Cause :** pour
forcer le premier amorçage sur le CD, l'ordre de démarrage avait été fixé à
`bios.bootOrder = "cdrom,hdd"` dans le fichier `.vmx`. Or l'ISO d'installation de
Windows démarre en UEFI **sans attendre d'appui sur une touche** : à chaque
redémarrage, la machine repartait sur le CD.

**Correction :** `bios.bootOrder = "hdd,cdrom"`. Un disque vide n'est pas amorçable, le
firmware bascule alors tout seul sur le CD ; dès que Windows y a copié ses fichiers,
le disque reprend la priorité. La boucle devient impossible.

**Difficulté annexe, instructive.** Les deux premières corrections du `.vmx` sont
restées sans effet : **VMware conserve la configuration en mémoire tant que l'onglet
de la machine est ouvert** et la réécrit par-dessus à l'extinction. Il faut fermer
l'onglet pour que le fichier puisse être modifié. La présence des fichiers
`STD-PG-02.vmx.lck` dans le dossier de la VM est le signe que VMware le tient encore.

---

## 11 — Méthodes et notions acquises

### Désigner les objets Windows par leur identifiant, pas par leur nom

Les noms des groupes locaux et des règles de pare-feu sont **traduits** : le groupe
`Administrators` s'appelle `Administrateurs` sur un Windows français. Un script qui
les désigne par leur libellé casse dès qu'on change de langue. Les scripts de ce
projet utilisent donc :

- les **SID** pour les groupes : `S-1-5-32-544` (Administrateurs), `S-1-5-32-545`
  (Utilisateurs), `S-1-5-18` (Système)
- les **identifiants de ressource** pour les règles de pare-feu :
  `@FirewallAPI.dll,-32752` (Découverte de réseau), `@FirewallAPI.dll,-28752`
  (Bureau à distance)

Ces identifiants sont invariants. C'est ce qui rend un script portable — et c'est
précisément la leçon que l'échec de la passe `oobeSystem` (P7, tentative 2) a
confirmée par l'absurde.

### Les droits NTFS : l'héritage avant tout

Pour rendre un dossier accessible en lecture seule, le réflexe est de modifier les
droits du groupe `Utilisateurs`. C'est insuffisant : tout dossier créé à la racine de
`C:\` hérite d'une autorisation **Modification** pour **`Utilisateurs authentifiés`**,
c'est-à-dire pour n'importe quel compte connecté. Il faut donc d'abord **casser
l'héritage** (`icacls /inheritance:r`) puis réattribuer explicitement.

```powershell
icacls "C:\Entreprise\Modeles" /inheritance:r `
    /grant:r "*S-1-5-32-544:(OI)(CI)F" `
    /grant:r "*S-1-5-18:(OI)(CI)F" `
    /grant:r "*S-1-5-32-545:(OI)(CI)RX"
```

`(OI)` = *Object Inherit*, s'applique aux fichiers ; `(CI)` = *Container Inherit*,
s'applique aux sous-dossiers ; `F` = contrôle total ; `RX` = lecture et exécution.

### Désinstaller une application Windows, vraiment

L'interface `Paramètres → Applications installées` ne retire une application que pour
le **compte courant**. Pour un déploiement, il faut deux opérations : retirer le
paquet **pour tous les utilisateurs**, et le retirer du **modèle de profil**
(*provisioned package*), sans quoi il revient sur chaque nouveau compte créé.

### Les trois passes d'un fichier de réponses

| Passe | Moment | Ce qu'on y met |
|---|---|---|
| `windowsPE` | avant que Windows existe | langue de Setup, partitionnement, édition, licence |
| `specialize` | Windows copié sur le disque | nom du poste, fuseau, groupe de travail |
| `oobeSystem` | premier démarrage | comptes, écrans de bienvenue, commandes de première session |

Comprendre ce découpage, c'est pouvoir diagnostiquer : si le disque est partitionné
mais que l'installation échoue ensuite, `windowsPE` a réussi et le problème est dans
une passe ultérieure. C'est ce raisonnement qui a permis de sauver le projet au
chapitre 9.

### Mesurer honnêtement

Trois principes appliqués tout au long : **le même instrument** pour les deux
scénarios ; les phases communes aux deux méthodes (création de la VM) **neutralisées**
car elles ne peuvent expliquer aucune différence ; et, en cas de doute, **sous-estimer
le temps manuel** plutôt que le gonfler — la pause du technicien a été déduite, et les
valeurs reconstituées d'après les horodatages des captures sont signalées comme telles
dans le fichier CSV.

### Journaliser au fil de l'eau, pas à la fin

Le script chronomètre n'écrivait initialement son fichier qu'à la toute fin. Une
fermeture accidentelle de la fenêtre a failli coûter toutes les mesures. Il a été
corrigé pour écrire **après chaque phase**, et doté d'un paramètre de reprise. Le
script de post-installation, lui, n'avait pas ce défaut : il utilise
`Start-Transcript`, qui écrit en continu.

---

## 12 — Conclusion

Le projet demandait une méthode de déploiement standardisée, un test sur une seconde
machine et un comparatif de temps. Les trois sont là, mesurés :

- **150,1 minutes** pour installer et configurer un poste à la main
- **47,4 minutes** pour le même poste par fichier de réponses et script
- **78 → 7 minutes** sur la partie configuration, soit **− 91 %**
- **Rentable à partir du 5ᵉ poste**, 9 heures de gain net sur les 10 postes
- **Deux postes, 59 contrôles identiques, 100 % chacun**

Mais le résultat que je retiens n'est pas un chiffre. C'est qu'un poste que j'avais
configuré moi-même, avec soin, en suivant une procédure écrite, comportait **treize
non-conformités — dont six que l'interface de Windows me montrait comme réglées**.
Aucune relecture visuelle ne les aurait trouvées.

L'automatisation n'a donc pas seulement rendu le déploiement plus rapide. Elle l'a
rendu **vérifiable**. Un script produit toujours le même état, et un contrôle
automatisé permet de le prouver point par point, sur chaque poste, en une minute. Le
gain de temps est un effet de bord agréable ; le vrai apport, c'est de pouvoir
répondre à la question « qu'est-ce qu'on a livré, exactement ? ».

Le projet a aussi rencontré une limite réelle, et ne la cache pas : les passes
`specialize` et `oobeSystem` du fichier de réponses n'ont jamais fonctionné sur cette
build de Windows 11 24H2, malgré deux tentatives de correction raisonnées. Le
déploiement n'est donc pas « zéro-touche » : il reste sept minutes de phase de
bienvenue à faire à la main. La réponse apportée — réduire le fichier de réponses à ce
qui est vérifié et déplacer le reste vers un script testable et journalisé — est
exactement celle qu'on appliquerait en production, et elle renforce plutôt qu'elle
n'affaiblit la démonstration : c'est bien le script, et non le fichier de réponses,
qui porte l'essentiel de la valeur.

---

*Dépôt du projet : https://github.com/L4ami/ppe-projet5-deploiement-image-systeme*
*Paul Giocanti · E1B · Geneva Institute of Technology · septembre 2026*
