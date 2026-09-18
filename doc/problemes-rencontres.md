# Problèmes rencontrés et solutions

Journal tenu au fil du projet. Chaque entrée décrit le symptôme observé, la cause
réelle et la correction appliquée. Cette section est reprise telle quelle dans le
rapport final.

---

## P1 — L'assistant VMware installe Windows tout seul (évité)

**Symptôme potentiel.** À l'écran « Installation du système d'exploitation invité »,
désigner directement l'ISO déclenche la fonction *Easy Install* de VMware : le
logiciel fabrique son propre fichier de réponses et installe Windows sans poser de
question.

**Pourquoi c'est un problème ici.** La mesure du temps d'installation manuelle
aurait été faussée (une installation automatisée mesurée comme manuelle), et le
fichier de réponses de VMware serait entré en conflit avec le nôtre lors du
déploiement automatisé.

**Solution.** Cocher « J'installerai le système d'exploitation ultérieurement » et
monter l'ISO manuellement dans le lecteur CD après la création de la machine.

---

## P2 — L'édition ne s'appelle pas « Windows 11 Pro » sur un média français

**Symptôme.** `Get-WindowsImage` sur l'ISO française liste 11 éditions, dont
l'index 6 nommé **« Windows 11 Professionnel »** — et non « Windows 11 Pro ».

**Pourquoi c'est un problème.** Un fichier de réponses qui désigne l'édition à
installer par son nom (`/IMAGE/NAME = "Windows 11 Pro"`) échoue sur ce média :
Windows Setup s'arrête et redemande quelle édition installer, ce qui casse le
caractère « sans intervention » du déploiement.

**Solution.** Ne pas désigner l'édition par son nom mais par la **clé générique
Microsoft** de Windows 11 Pro (`VK7JG-NPHTM-C97JM-9MPGT-3V66T`). Cette clé n'active
rien : elle indique seulement à Setup quelle édition extraire, et fonctionne quelle
que soit la langue du média.

---

## P3 — Windows 11 24H2 ne propose plus de créer un compte local

**Symptôme.** Pendant l'OOBE, l'écran « Déverrouillez votre expérience Microsoft »
n'offre qu'un bouton `Se connecter`. L'option officielle « Joindre le domaine à la
place », encore présente sur les versions précédentes de Windows 11 Pro, a disparu.

**Solution appliquée.** Depuis l'OOBE, `Maj + F10` pour ouvrir une invite de
commandes, puis :

```
start ms-cxh:localonly
```

`ms-cxh:` est un protocole interne de Windows qui ouvre les boîtes de dialogue de
gestion de comptes ; le suffixe `localonly` ouvre directement celle de la création
d'un compte local.

**Ce que ça démontre.** Cette manipulation non documentée devient **inutile** en
déploiement automatisé : le fichier de réponses crée `adm.local` et `utilisateur`
dans la passe `oobeSystem`, sans jamais afficher cet écran. C'est un argument
concret en faveur de l'installation automatisée, au-delà du seul gain de temps.

---

## P4 — Le poste se nomme lui-même d'après le compte, et le renommage exige un redémarrage

**Symptôme.** Après création du compte `adm.local`, la vérification
`Get-LocalGroupMember` affiche les comptes sous la forme `adm-local\adm.local` :
le poste s'appelle **ADM-LOCAL**. Windows 11 24H2 génère automatiquement le nom de
la machine à partir du nom du premier compte créé, en remplaçant le point par un
tiret.

Le renommage en `STD-PG-01` via `sysdm.cpl` semblait avoir été accepté, mais le nom
affiché restait l'ancien.

**Cause réelle.** Un renommage de poste n'est effectif qu'**après redémarrage**.
Tant que la machine n'a pas redémarré, la résolution des identifiants de sécurité
(SID) continue d'utiliser l'ancien nom.

**Solution.** Redémarrer, puis vérifier avec :

```powershell
Get-CimInstance Win32_ComputerSystem | Select-Object Name, Workgroup
```

**Ce que ça démontre.** Sur 10 postes déployés à la main, c'est 10 occasions
d'oublier ce redémarrage et de livrer un poste au mauvais nom. Le fichier de
réponses fixe le nom dans la passe `specialize`, avant même la première ouverture
de session — l'erreur devient impossible.

---

## P5 — Décalage du chronomètre entre les phases 3 et 4

**Symptôme.** Le passage à la phase suivante du chronomètre a été oublié au moment
d'arriver sur le bureau : le renommage du poste et le changement de groupe de
travail ont été mesurés à l'intérieur de la phase 3.

**Correction.** Phases 3 et 4 fusionnées dans le tableau des mesures, avec mention
explicite. Le **total** du scénario manuel reste exact — seule la répartition entre
deux lignes est affectée.

**Ce que ça démontre.** Une mesure manuelle dépend d'un opérateur attentif ; une
mesure produite par un script (comme celle du déploiement automatisé, horodatée par
`p5-post-install.ps1`) n'a pas ce défaut. C'est une limite méthodologique à assumer
dans le comparatif.

---

## P6 — Le contrôle de conformité refuse le poste de référence lui-même (78 %)

**Symptôme.** Premier passage de `p5-verifier-conformite.ps1` sur STD-PG-01, pourtant
configuré avec soin pendant deux heures : **59 contrôles, 46 conformes, 13 écarts,
score 78 %, verdict POSTE REFUSÉ.**

L'analyse a séparé deux natures d'écarts très différentes.

### a) Deux défauts de l'outil de contrôle (2 écarts)

| Contrôle | Mesuré | Cause |
|---|---|---|
| Longueur minimale du mot de passe | `1` au lieu de `12` | Le filtre cherchait `minimale du mot de passe` et capturait la ligne « Ancienneté **minimale du mot de passe** (jours) : 1 », qui apparaît **avant** la bonne dans la sortie de `net accounts` |
| Seuil de verrouillage du compte | vide | Le filtre cherchait `verrouillage du compte` ; la ligne s'appelle en réalité « Seuil de verrouillage » |

Les deux valeurs étaient correctement configurées sur le poste. **Leçon :** analyser
une sortie de commande localisée par correspondance de texte est fragile. Les filtres
ont été resserrés sur le libellé exact.

### b) Onze écarts réels — dont six invisibles dans l'interface

Le plus instructif : les six applications **désinstallées via `Paramètres →
Applications installées` étaient toujours présentes**.

L'interface graphique de Windows ne retire une application que pour le **compte
courant**. Le paquet reste enregistré pour les autres utilisateurs, et surtout il
reste dans le **modèle de profil** (*provisioned package*) : tout nouveau compte
créé sur le poste les récupérerait intégralement. Sur dix postes livrés à dix
collaborateurs, le ménage aurait été entièrement annulé à la première ouverture de
session.

Le retrait complet exige deux opérations distinctes :

```powershell
Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers
Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq $app |
    Remove-AppxProvisionedPackage -Online
```

Les cinq autres écarts venaient de réglages posés à un endroit du registre différent
de celui attendu (SmartScreen, exécution automatique) ou simplement absents
(mises à jour automatiques, PUA, niveau d'UAC).

**Correction appliquée.** Les onze écarts ont été corrigés avec **exactement les
commandes qu'exécute `p5-post-install.ps1`**, et non à la souris. C'était impératif :
le poste de référence doit être reproductible à l'identique par le script, sinon le
contrôle de conformité de STD-PG-02 aurait remonté des différences.

### c) Le seuil de verrouillage, dernier écart (98,3 %)

Deuxième passage : 58/59, un seul écart — seuil de verrouillage à **10** au lieu de 5.
Windows 11 24H2 impose ce défaut, et la valeur saisie dans `secpol.msc` n'avait pas
survécu. Corrigée par `net accounts /lockoutthreshold:5`.

**Troisième passage : 59/59, score 100 %, POSTE ACCEPTÉ.**

### Ce que cet incident démontre

C'est le résultat le plus important du projet. Un poste configuré **manuellement**,
avec attention, en suivant une procédure écrite, présentait **treize non-conformités**
dont six totalement invisibles dans l'interface de Windows. Aucune n'aurait été
détectée par une relecture visuelle.

C'est précisément l'argument en faveur du déploiement automatisé : non pas seulement
« c'est plus rapide », mais **« c'est le seul moyen de savoir ce qu'on a réellement
livré »**.

---

## P7 — Échec des passes `specialize` et `oobeSystem` du fichier de réponses

**Symptôme.** Sur STD-PG-02, l'installation se déroule correctement jusqu'à la phase
de personnalisation, puis affiche : *« Windows n'a pas pu terminer l'installation.
Pour installer Windows sur cet ordinateur, redémarrez le programme d'installation. »*

**Ce qui fonctionnait.** Le journal `C:\Windows\Panther\setupact.log` contient la ligne
`Copy unattend payload from E:\autounattend.xml` : le fichier a bien été trouvé sur le
second lecteur de CD et appliqué. Preuve visuelle supplémentaire : un disque contenant
déjà une installation Windows a été **remis à zéro automatiquement** par la directive
`WillWipeDisk`. La passe `windowsPE` s'exécute donc correctement.

**Deux tentatives de correction, deux échecs.**

| Tentative | Modification | Raisonnement | Résultat |
|---|---|---|---|
| 1 | Retrait de `Microsoft-Windows-UnattendedJoin` (groupe de travail) et de `Microsoft-Windows-Deployment` (clé `BypassNRO`) de la passe `specialize` | Ne garder dans le fichier de réponses que ce que lui seul peut faire ; le script applique le groupe de travail de toute façon | Échec au même point |
| 2 | Un seul compte local au lieu de deux, et groupe écrit `Administrators` au lieu de `Administrateurs` | Un libellé de groupe traduit non résolu fait échouer la création du compte, donc toute la passe | Échec au même point |

**Décision.** Retirer les passes `specialize` et `oobeSystem`. Le fichier de réponses
final ne conserve que `windowsPE`, vérifiée à l'exécution. Le contenu complet est
archivé dans `autounattend-complet-non-fonctionnel.xml`.

**Conséquence sur le résultat.** Le déploiement n'est plus « zéro-touche » intégral :
il reste une phase de bienvenue à passer à la main, soit environ 3 minutes. Mais le
fichier de réponses supprime toujours **une quinzaine d'écrans** — langue, format
régional, clavier suisse romand, partitionnement GPT complet, sélection de l'édition
Professionnel, contrat de licence — et surtout, **la totalité du travail de
configuration reste automatisée par le script**, qui représente l'essentiel du temps.

**Ce que ça enseigne.** Un fichier de réponses n'est pas un tout-ou-rien : il
s'exécute en passes indépendantes, et une passe peut réussir pendant qu'une autre
échoue. Le bon réflexe en production n'est pas de déboguer un XML pendant des heures,
mais de **réduire le fichier à ce qui est vérifié** et de déplacer le reste vers un
script — qui, lui, est testable, journalisé et corrigible en une ligne. C'est
exactement le rapport de force entre image et script décrit au chapitre 2.

---

## P8 — Boucle de démarrage infinie causée par l'ordre d'amorçage

**Symptôme.** L'installation recommençait depuis le début à chaque redémarrage :
copie des fichiers, redémarrage, et retour à l'écran « Sélectionner l'emplacement ».

**Cause.** Pour forcer le premier amorçage sur le CD, l'ordre de démarrage avait été
fixé à `bios.bootOrder = "cdrom,hdd"` dans le fichier `.vmx`. Or l'ISO d'installation
de Windows démarre en UEFI **sans attendre d'appui sur une touche** : à chaque
redémarrage, la machine repartait donc sur le CD.

**Correction.** `bios.bootOrder = "hdd,cdrom"`. Un disque vide n'est pas amorçable :
le firmware bascule alors tout seul sur le CD. Dès que Windows y a copié ses fichiers,
le disque devient amorçable et reprend la priorité. C'est la configuration correcte,
et elle rend la boucle impossible.

**Difficulté annexe.** Les deux premières corrections du fichier `.vmx` sont restées
sans effet : **VMware conserve la configuration en mémoire tant que l'onglet de la
machine est ouvert**, et la réécrit par-dessus à l'extinction. Il faut fermer l'onglet
(la machine disparaît de la liste, rien n'est supprimé) pour que le fichier puisse
être modifié. La présence des fichiers `STD-PG-02.vmx.lck` dans le dossier de la VM
est le signe que VMware le tient encore.
