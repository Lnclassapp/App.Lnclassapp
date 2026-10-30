# Journal — Les leçons dans l'ordre de la progression

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-29 | `MATERIAL_ORDER` (rang puis nom de la matière) extraite de `PROGRAM_ORDER` ; `PROGRAM_ORDER` et `CATALOG_ORDER` placent `LESSON_NUMBER` avant `courses.name` | `student_materials` utilisait `PROGRAM_ORDER.first(2)` : l'ordre des matières reste inchangé | Non |
| 2026-10-29 | `STUDENT_LESSON_ORDER` et `TEACHER_ORDER` supprimés, `order_for` ramené à deux ordres (programme pour l'élève et l'enseignant multi-matières, catalogue sinon) | Redondants une fois le numéro de leçon dans les deux ordres de base | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Rien.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Deux tests existants figeaient l'ancien ordre par nom (équipe dans `course_catalog_query_test.rb`, téléphone de l'élève dans `courses_controller_test.rb`) ; mis à jour.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Rien | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
