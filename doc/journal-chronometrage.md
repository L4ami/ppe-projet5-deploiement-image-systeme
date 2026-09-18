# Journal de chronométrage — corrections à appliquer

Ce fichier consigne les interruptions survenues pendant les mesures, afin que le
comparatif de temps du rapport repose sur des durées corrigées et justifiées.

| Scénario | Phase concernée | Événement | Heure | Correction à appliquer |
|---|---|---|---|---|
| manuel | 1/12 — Création de la VM | Phase clôturée immédiatement : la création de la VM est identique dans les trois scénarios, elle ne peut pas expliquer une différence de temps | — | Phase neutralisée, exclue du comparatif |
| manuel | 3/12 — Écrans de bienvenue OOBE | Pause du technicien pendant la mise à jour OOBE de la 24H2 | Départ **12h07** — retour **13h00** | **Déduire 53 minutes** de la durée mesurée de la phase 3 |

**Principe retenu :** en cas de doute, on sous-estime le temps manuel plutôt que de
le gonfler. Un comparatif dont la méthode manuelle aurait été artificiellement
allongée par une pause n'aurait aucune valeur de démonstration.

---

## Incident — fermeture accidentelle de la fenêtre du chronomètre (phase 10)

**Symptôme.** La fenêtre PowerShell exécutant `p5-chrono.ps1` a été fermée pendant la
phase 10. Le script n'écrivait son fichier CSV qu'à la toute fin des 12 phases : les
mesures des phases 1 à 9 n'avaient donc encore jamais été enregistrées sur disque.

**Récupération.** Aucune donnée n'a été perdue :

- Les phases **1 à 5** étaient visibles à l'écran sur une capture prise plus tôt
  (heures de début et durées exactes).
- Les phases **6 à 9** ont été reconstituées à partir des **horodatages des captures
  d'écran** prises pendant chacune d'elles — l'horloge de la barre des tâches est
  visible sur toutes. Précision estimée : ±1 minute.

Le fichier `doc/chrono-manuel.csv` porte une colonne `Source` qui distingue
explicitement les valeurs mesurées des valeurs reconstituées. Aucune valeur n'est
présentée comme mesurée si elle ne l'est pas.

**Correction apportée à l'outil.** `p5-chrono.ps1` a été modifié sur deux points :

1. **Écriture incrémentale** : le CSV est réécrit après *chaque* phase, plus
   seulement à la fin. Une fermeture accidentelle ne coûte désormais que la phase
   en cours.
2. **Reprise** : un paramètre `-Depuis <n>` permet de reprendre à une phase donnée
   sans recommencer depuis le début.

**Ce que ça illustre.** Un outil de mesure qui ne persiste ses résultats qu'à la fin
d'un traitement long est fragile par conception — c'est le même raisonnement qui
pousse à journaliser au fil de l'eau plutôt qu'en fin de script. Le script de
déploiement `p5-post-install.ps1`, lui, écrit sa transcription en continu via
`Start-Transcript` : il n'avait pas ce défaut.
