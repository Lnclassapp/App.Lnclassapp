# Journal — Corriger une copie comme en classe

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-28 | D1 à D4 tranchées par le porteur (issue #350) | Proposition de Touré, maquette Thalès à l'appui | D1 : oui (ADR-XXXX-correction-complete-et-pause-de-recommencer) |
| 2026-10-28 | D2 abandonnée : la meilleure note compte partout ; « Recommencer » en pause 30 min après 3 copies d'affilée | Choix de Touré au grill (Q4, Q4 bis, Q5), validé de vive voix par le porteur, relayé par Touré | Oui, même ADR |
| 2026-10-28 | Le titre du résultat devient l'appréciation ; la phrase d'encouragement et le seuil de 14/20 restent | Grill Q6, ton à 12-13/20 accepté par le porteur | Non : UDR-XXXX-resultat-corrige-comme-en-classe |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Le rendu des bonnes réponses existe déjà pour l'enseignant (`reveal` dans `SessionResultQuery` et les cinq partials `kinds/*_review`) : le chantier l'ouvre à l'élève, il ne le crée pas.
- Les questions d'un exercice se verrouillent dès sa première copie (`UpdateExercise`, `questions_locked?`) : la correction d'une ancienne copie montre toujours les réponses qui l'ont notée.
- Cinq tests figent l'ancienne règle côté résultat (`question_*_test.rb`, `session_result_test.rb`) : ils s'inversent au Lot A.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Une note obtenue la correction sous les yeux n'est pas signalée à l'enseignant | Risque accepté avec la révision de D2 ; la pause le freine seulement | — (à rouvrir si les enseignants le remontent) |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
