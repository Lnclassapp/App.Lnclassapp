# Journal — Validation des enseignants en pause

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-02 | Pause de la validation ; la certification par DRENA viendra avant le premier versement aux enseignants | Décision du porteur : l'enseignant doit atteindre son premier usage au plus vite | ADR-0073 |
| 2026-10-02 | Grill réduit à des choix par défaut (arrivée, trace `auto`, demandes en attente, invitation inchangée) | Le porteur a demandé d'arrêter les questions | Memo, ADR-0073 §5 |

## Ce qui a dérapé

- Une première question de cadrage, fermée par le porteur : il voulait la règle appliquée, pas un questionnaire. Les choix restants sont écrits dans le memo, réversibles.

## Ce qu'on a appris sur la codebase

- `JoinRequestRepository#approve` rattache déjà l'enseignant dans le même point de sauvegarde : la pause tient en un appel de plus dans le use case.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Certification des enseignants, DRENA par DRENA, par collègues et directions | Période et règles à fixer par le porteur | `certification-enseignants` (à ouvrir) |
| Régénérer les codes secrets des établissements où des enseignants sont entrés sans code | Le code ne protège rien pendant la pause | À la reprise de la validation |
