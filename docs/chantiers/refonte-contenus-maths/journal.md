# Journal — Refonte des contenus de mathématiques

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-29 | Lot A : le schéma v3 refuse d'abord (5 questions, explanation 20-2000, 4 problèmes, 1 exercice par notion) ; le rapport donne alors le code `schema` au chemin de l'élément. Les raisons propres (`too_few_questions`, `lesson_exercise_count`…) restent dans l'adaptateur, pour un appel sans schéma. | Le moteur valide le schéma avant l'adaptateur ; les deux disent le même chemin. | Non |
| 2026-10-29 | Alignement des raisons (CA-18) : l'import fait foi. Le schéma v3 ne compte plus les questions, les problèmes, l'exercice d'une notion ni la correction, et ne juge plus le fond des figures : l'adaptateur rend `essential_exercise_count`, `lesson_exercise_count`, `too_few_questions`/`invalid_count`, `blank`/`too_short`(nouveau)/`too_long`, `figure_invalid`. Le script rend le code de l'import pour tout le reste (`schema` quand le schéma refuse, qui masque alors l'adaptateur), et n'avertit que de ce que l'import ignore. Remplace la décision du Lot A ci-dessous. | Un fichier refusé par le script doit l'être par l'import pour la même raison ; test de parité. | Non (ADR §4.1 mis à jour) |
| 2026-10-29 | Lot A : `replace_draft` garde l'auteur de la leçon (le port n'a pas d'`author_id`) ; les séances de remédiation hors leçon dont la lacune disparaît deviennent ordinaires. | Pas de port à changer ; la base impose `remediation ⇔ lacune`. | Non |
| 2026-10-29 | Lot F2 : le point dérivé (Thalès) est une contrainte `{"point","on","parallel_to","through"}` recalculée à chaque tracé ; le volume du solide est affiché en `V ≈` sans unité ; le solide se recadre à chaque curseur (pas d'échelle fixe). | Aucun curseur sur geometry (Lot 0 bis) : le point déplaçable D commande E ; la sortie de `solid` reste lisible sans connaître le maximum du curseur. | Non (forme ajoutée à l'ADR §4.2) |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot A : le plan ne listait pas `import_error.rb` ni `run_import.rb` ; sans eux, aucun nouveau motif d'import (`format_retired`…) n'existe. Le champ du lot a été élargi en cours de route.
- Lot A : `saint_michel.rb` importe des leçons de Tle D au format 1, désormais retiré ; la démo s'arrête avec un message clair jusqu'au Lot P2.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

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
