# Journal — Validation des enseignants en pause

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-02 | Pause de la validation ; la certification par DRENA viendra avant le premier versement aux enseignants | Décision du porteur : l'enseignant doit atteindre son premier usage au plus vite | ADR-0073 |
| 2026-10-02 | Grill réduit à des choix par défaut (arrivée, trace `auto`, demandes en attente, invitation inchangée) | Le porteur a demandé d'arrêter les questions | Memo, ADR-0073 §5 |

## Ce qui a dérapé

- Une première question de cadrage, fermée par le porteur : il voulait la règle appliquée, pas un questionnaire. Les choix restants sont écrits dans le memo, réversibles.

- La première migration validait toute demande en attente : un compte anonymisé ou un établissement inactif aurait été rattaché, et `ON CONFLICT DO NOTHING` pouvait valider une demande sans rattacher personne. Relevé par la relecture de sécurité ; la migration ne valide plus que ce qu'une inscription d'aujourd'hui aurait permis, et échoue sur l'état incohérent.

## Ce qu'on a appris sur la codebase

- `test/db/growth_migrations_test.rb` défait puis refait la table `school_join_requests` hors transaction : toute migration qui touche plus tard à cette table doit s'ajouter à sa liste `LATER`, sinon la base du worker garde l'ancienne contrainte et les tests suivants échouent selon l'ordre de passage (la deuxième preuve est tombée ainsi).

- `JoinRequestRepository#approve` rattache déjà l'enseignant dans le même point de sauvegarde : la pause tient en un appel de plus dans le use case.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Certification des enseignants, DRENA par DRENA, par collègues et directions | Période et règles à fixer par le porteur | `certification-enseignants` (à ouvrir) |
| Événement d'audit pour la validation `auto` | La trace tient dans la demande (`decided_via`, `decided_at`) ; à ajouter si la direction veut voir « qui a rejoint » | Certification |
| Régénérer les codes secrets des établissements où des enseignants sont entrés sans code | Le code ne protège rien pendant la pause | À la reprise de la validation |
