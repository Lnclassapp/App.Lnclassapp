# Plan d'exécution — Les leçons dans l'ordre de la progression

## Graphe

```
Lot A (seul)
```

---

## Lot A — Ranger par numéro de leçon partout

- **Couche**       : infrastructure (query)
- **Fichiers**     : `app/infrastructure/queries/catalog/course_catalog_query.rb`
                     `test/infrastructure/queries/catalog/course_catalog_query_test.rb`
- **Dépend de**    : —
- **Test associé** : `test/infrastructure/queries/catalog/course_catalog_query_test.rb` (CA-1 à CA-3 : sous-titres « Leçon 10 », « Leçon 2 », sans numéro ; élève sans fiches, enseignant multi-matières, équipe)
- **Done quand**   : `PROGRAM_ORDER` et `CATALOG_ORDER` placent `LESSON_NUMBER` avant `courses.name`, `PROGRAM_ORDER.first(2)` (ordre des matières) inchangé ; `STUDENT_LESSON_ORDER` devient redondant et disparaît s'il ne sert plus ; tests verts, commentaires (CA-E14) mis à jour.

---

## Portes de sortie

- [x] Tests du fichier touché verts ; `bin/ci-quiet` une fois sur le head final
- [x] `journal.md` clos
- [x] PR unique vers `Develop`
