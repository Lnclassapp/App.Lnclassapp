# Journal — Corriger le texte d'une leçon à l'écran

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-14 | Bonne réponse modifiable même après des tentatives, sans recalcul | Décision du porteur | ADR-0113 §4.6 (amendement) |
| 2026-11-14 | Le formulaire porte les identifiants ; tout écart avec la structure enregistrée est refusé sous verrou | Un réimport entre l'ouverture et l'enregistrement ne doit rien écrire de travers | Non |
| 2026-11-14 | Une question qui cassait déjà sa règle de type avant la correction n'est pas refusée pour cela | Ne pas bloquer une coquille sur un défaut ancien de l'import | Non |

## À trancher

- [ ] 2026-11-14 · edition-texte-lecon · L'entraînement d'une notion (« Je m'entraîne ») et les textes des questions de types sans proposition (trous, nombre, rédaction : réponse attendue, unité, grille) ne se corrigent pas à l'écran. — appliqué : import seulement ; autres : les ajouter à la modale ; recommandé : attendre un besoin constaté.

## Ce qui a dérapé

- Lot commencé comme Lot B de #598 ; #598 a été fusionnée avant, puis #601 a corrigé la régression du badge « Brouillon ». Le travail a été repris sur une nouvelle branche.
- Les constantes `TEXT_MAX`/`STEP_MAX` de `NotionSheet` sont définies dans le bloc de `Data.define` : elles tombent dans `Entities::Catalog`, pas sous `NotionSheet`. La vue n'y fait pas référence ; le use case valide les longueurs.

- Revue sécurité : rien d'exploitable ; une question forgée (texte au lieu de champs) donnait un 500 → écartée, 422 `structure_changed` (test).
- Revue pannes silencieuses, quatre points traités :
  - une règle déjà cassée à l'import couvrait aussi une bonne réponse retirée en plus → la soustraction ne vaut que si la clé et les textes reliés sont inchangés (test) ;
  - une erreur de fiche sans champ (étapes hors bornes à l'import) n'avait pas de message → `base: reimport` (test) ;
  - deux renommages simultanés vers le même nom donnaient un 500 → `attempt_with_cause`, « nom déjà pris » (test) ;
  - borne de l'indice d'exercice alignée sur l'entité (400).

## Ce qu'on a appris sur la codebase

- `question_attempts.correct` et `exercise_sessions.score_percent` sont enregistrés : changer `answers.correct` ne touche aucun résultat passé, sans code de plus.
- `Orm::QuestionAttempt` est en lecture seule : les tests posent la tentative par la fabrique.

## Dette laissée derrière

- Aucune.
