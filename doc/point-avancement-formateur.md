# Projet 5 — Point d'avancement

**Paul Giocanti · E1B · 17.09.2026 — projet en cours, non terminé**

## Méthode retenue

Trois machines virtuelles : `STD-PG-01` construit **manuellement** (poste de
référence et mesure du temps manuel), `STD-PG-02` déployé par **fichier de réponses
`autounattend.xml` + script PowerShell**, `STD-PG-03` prévu par **Sysprep +
Clonezilla**. Windows Autopilot a été étudié mais écarté : il exige un abonnement
Entra ID + Intune, incompatible avec le cahier des charges (aucun compte Microsoft).

## Ce qui est terminé

- **Cahier des charges** du poste standard : matériel, OS, partitionnement GPT,
  comptes, politique de mot de passe, réseau, sécurité, logiciels, droits NTFS.
- **Poste de référence STD-PG-01** construit entièrement à la main, en chronométrant
  les 12 phases : **150 minutes**.
- **Quatre scripts PowerShell** : post-installation (9 étapes chronométrées),
  contrôle de conformité (59 points), fabrication du média de déploiement,
  chronomètre de phases.
- **Contrôle de conformité de STD-PG-01 : 59/59, 100 %, poste accepté.**

## Le résultat le plus intéressant

Au premier passage, le contrôle de conformité a **refusé le poste de référence :
78 %, 13 écarts**. Deux venaient d'erreurs dans mon script de contrôle, onze étaient
réels — dont six applications « désinstallées » via l'interface de Windows qui
étaient **toujours présentes** : Paramètres ne les retire que pour le compte courant,
elles restent dans le modèle de profil et reviendraient sur tout nouveau compte.
Aucun de ces écarts n'était visible à l'œil. Corrigés, le poste est passé à 100 %.

C'est l'argument central du projet : l'automatisation n'est pas seulement plus
rapide, c'est **le seul moyen de savoir ce qu'on a réellement livré**.

## Problèmes rencontrés

1. Windows 11 24H2 ne propose plus aucun moyen documenté de créer un compte local
   pendant l'OOBE — contournement par `start ms-cxh:localonly`.
2. Sur le média français, l'édition s'appelle « Windows 11 Professionnel » : un
   fichier de réponses qui la désigne par son nom échoue. Résolu en passant par la
   clé générique Microsoft.
3. Le renommage du poste n'est effectif qu'après redémarrage — Windows nomme d'abord
   la machine d'après le premier compte créé.
4. **Blocage principal :** les passes `specialize` et `oobeSystem` du fichier de
   réponses échouent systématiquement (« Windows n'a pas pu terminer l'installation »),
   malgré deux simplifications successives. La passe `windowsPE` fonctionne, elle :
   le disque est effacé et repartitionné automatiquement, l'édition sélectionnée,
   une quinzaine d'écrans supprimés. Décision : ne conserver que cette passe et
   déplacer le reste vers le script. Le déploiement n'est donc plus « zéro-touche »
   intégral — il reste ~3 minutes de phase de bienvenue à faire à la main.
5. Boucle de démarrage infinie causée par un ordre d'amorçage CD-avant-disque :
   l'ISO Windows démarre en UEFI sans attendre de touche, l'installation
   recommençait à chaque redémarrage. Corrigé.

## Ce qu'il reste à faire

- Réinstaller STD-PG-02 avec le fichier de réponses corrigé, lancer le script de
  post-installation et le contrôle de conformité.
- Établir le comparatif de temps manuel / automatisé et l'extrapoler à 10 postes.
- Branche Clonezilla : procédure rédigée, non exécutée faute de temps.
- Finaliser le rapport et le publier.
