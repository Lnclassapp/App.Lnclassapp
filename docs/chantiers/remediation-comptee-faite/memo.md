# Memo — Une remédiation compte comme exercice fait

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-04 |
| **Branche** | `fix/remediation-comptee-faite` |
| **Programme** | `refonte-application` — suite de [`rapports-exercices`](../rapports-exercices/journal.md) |

---

## Symptôme

Sur les pages de la **direction** (travail des élèves par classe, détail d'une classe, élèves partis), un élève qui a fait un exercice assigné **en remédiation** est compté « pas encore rendu ». Le taux de rendu de sa classe est donc faux, et la moyenne ne tient pas compte de ses sessions.

## Reproduction

1. Un élève de 3ème B (classe principale, active) a deux exercices assignés de la même fiche : X et Y.
2. Il fait X et obtient 25 % : une lacune en attente s'ouvre sur la fiche (ADR-0043).
3. Il fait Y. `StartExerciseSession` (`new_session`) ouvre une session `kind: "remediation"`, rattachée à l'assignation de Y. Il obtient 80 %.
4. La direction ouvre « Travail des élèves », puis la 3ème B : Y compte comme non rendu pour cet élève, et son 80 % n'entre pas dans la moyenne.

Cause : `Queries::School::StudentWorkQuery` (ligne 21) et `Queries::School::DepartedStudentsQuery` (ligne 59) filtrent `kind = 'standard'`. Elles reprennent la définition de « fait » de l'ADR-0048 et de l'ADR-0072 §4.4, écrite avant que la remédiation automatique de l'ADR-0043 ne soit branchée sur `StartExerciseSession`.

## Portée

- **Depuis** : la mise en production de la remédiation automatique (V1, ADR-0043) et de l'espace direction (ADR-0065).
- **Touchés** : la direction, pour tout élève en difficulté qui a une lacune en attente sur une fiche. Ce sont précisément les élèves qu'il faut voir.
- **Données** : aucune donnée corrompue. C'est une lecture fausse : la corriger suffit.
- **Côté enseignant**, c'est déjà corrigé par `rapports-exercices` (ADR-0079 §4.1, [Lnclassapp/App.Lnclassapp#164](https://github.com/Lnclassapp/App.Lnclassapp/pull/164)). Tant que ce chantier n'est pas livré, l'enseignant et la direction ne comptent pas « fait » de la même façon.

## Hors périmètre

- Changer `StartExerciseSession` ou la remédiation elle-même (ADR-0043).
- Les écrans de l'enseignant, corrigés par `rapports-exercices`.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Une session de remédiation sur un exercice, est-ce l'avoir fait ? | **Oui** : décision de l'orchestrateur, sous le mandat délégué du porteur (2026-10-04), pour les deux chantiers. L'élève a bien fait l'exercice, et c'est même là qu'il progresse. | « Fait » = session `completed`, rattachée à l'assignation, d'un élève présent, quel que soit son `kind`. Amendement de l'ADR-0072 §4.4 côté direction. |
| Pourquoi un chantier à part ? | L'index partiel `index_exercise_sessions_handed_in` (`WHERE kind = 'standard'`, ADR-0067 levier 1) tient le budget de 100 ms des pages de la direction. Retirer le filtre sans le remplacer fait sortir ces pages de leur budget. | Une migration remplace l'index (sans `kind`), puis on mesure avant et après au volume de l'ADR-0067. |

## Cas limites identifiés

- Élève dont **toutes** les sessions sur l'assignation sont des remédiations.
- Rendu en retard : la première session faite, quel que soit son `kind`.
- Élève parti (`DepartedStudentsQuery`) : même règle.

## Questions encore ouvertes

- Aucune.
