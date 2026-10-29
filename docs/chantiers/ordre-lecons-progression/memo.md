# Memo — Les leçons dans l'ordre de la progression

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré (PR vers `Develop`, 2026-10-29), clos |
| **Ouvert le** | 2026-10-29 |
| **Branche** | `fix/ordre-lecons-progression` |
| **Programme** | — |

---

## Le problème

Sur Develop, l'élève de 3e connecté sur son téléphone ouvre « Cours ». L'en-tête annonce « 10 fiches de cours · Progression DPFC 2026-2027 », mais les leçons sont rangées par nom : Angles inscrits (Leçon 6), Calcul littéral (Leçon 1), Calcul numérique (Leçon 5)…

`Queries::Catalog::CourseCatalogQuery` ne range par numéro de leçon (`LESSON_NUMBER`) que l'enseignant (`TEACHER_ORDER`) et l'élève sur ordinateur (`STUDENT_LESSON_ORDER`, CA-E14). Le reste se range par nom : le Cours de l'élève sur téléphone (`PROGRAM_ORDER`), l'enseignant de plusieurs matières (`PROGRAM_ORDER`) et l'équipe (`CATALOG_ORDER`).

## Pour qui

L'élève qui révise dans l'ordre du cours. Les autres acteurs voient le même catalogue, mal rangé.

## Pourquoi maintenant

Le porteur l'a constaté sur Develop le 2026-10-29, avec les 10 leçons pilotes de 3e (chantier `refonte-contenus-maths`), et a demandé la correction.

## Hors périmètre

- Ajouter une colonne de position aux cours : le numéro reste lu dans le sous-titre (« Leçon N »), comme pour l'enseignant.
- Changer l'ordre des matières ou des niveaux.
- L'exercice du jour (`Queries::Assessment::DailyExerciseQuery`).
