# Journal — Comprendre où en est la classe sur un exercice

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-04 | Le porteur délègue la suite du cadrage (« prends des décisions alignées ») après avoir validé couleurs, meilleur score, signe et seuil de 5 | Avancer jusqu'au plan sans lui poser chaque question | — |
| 2026-10-04 | La statistique est celle d'un **exercice assigné**, sur les sessions de l'assignation, et non celle d'un exercice sur toutes les sessions | Le « 18/25 » doit être le « 18 faits » de la même page (ADR-0048, ADR-0072) | ADR-0079 §4.1 |
| 2026-10-04 | Le détail va dans la **page de suivi** existante, sous `FollowAssignmentPolicy` : ni écran, ni route, ni policy nouveaux | La page nomme déjà des élèves sous la bonne policy | UDR-0072 §2 |
| 2026-10-04 | Badges déduits du meilleur score de l'assignation, pas de la table des badges | Couleur et badge ne se contredisent jamais | ADR-0079 §4.2 |
| 2026-10-04 | **Autonomie totale** accordée par le porteur : décisions prises sans question, au service du progrès des utilisateurs | Consigne du porteur | — |
| 2026-10-04 | Relecture par la mission (« aider chaque acteur à progresser ») : taux au premier essai par question, « À reprendre en classe » sous 50 %, élèves en baisse ou qui stagnent en tête | Chaque lecture doit appeler un geste de l'enseignant | ADR-0079 §2, §4.5, §4.7 |
| 2026-10-04 | Rouge et jaune deviennent des tokens propres à la compréhension (`struggling`, `fragile`), distincts de l'ambre d'urgence | La charte (§5) réserve l'ambre à l'urgence, et la même ligne affiche une échéance en retard en ambre | UDR-0072 §3.1 |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Branche ouverte sur un `Develop` local périmé de 394 commits** (clone du conteneur figé au 2026-10-01). Le premier cadrage s'appuyait sur un code disparu : page classe sans « Exercices assignés », pas d'échéance, pas de page de suivi. Découvert au moment de numéroter l'ADR. Rebasé sur `origin/Develop`, puis memo corrigé. **À refaire autrement : `git fetch origin Develop` avant `git switch -c`, toujours.**
- Les captures envoyées comme « états » étaient celles de la jauge de contexte de Claude Code, pas des maquettes : l'UDR propose une mise en page sans maquette du porteur.
- L'exploration déléguée à un agent a été perdue lors d'un redémarrage du conteneur ; refaite à la main.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `Grading.mastery_for` donne déjà les trois catégories (« Acquis », « Fragile », « En difficulté ») ; aucun seuil n'est à créer.
- Deux définitions de « réussite » coexistent : la fiche essentielle dans la classe (UDR-0029) lit toutes les sessions des élèves présents ; le suivi d'un exercice assigné (ADR-0072) ne lit que les sessions de l'assignation. Elles ne sont jamais sur la même page.
- `AssignmentFollowUpQuery.present_students` est la définition partagée de l'élève « présent » (adhésion non quittée, compte non anonymisé).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
