# Plan d'exécution — Develop charge seul les leçons v3 du programme

Un seul lot, séquentiel : pas de migration, de route ni de vue.

## Lot A — Develop remplace entières les leçons v3 du programme

- **Couche**       : domaine + infrastructure + tâche de pré-déploiement
- **Fichiers**     : `app/domain/entities/catalog/v3_programme_levels.rb` (nouveau) · `app/domain/entities/catalog/automatic_load_stage.rb`
                     `app/domain/ports/catalog/lesson_source_port.rb` · `app/infrastructure/repositories/catalog/repository_lesson_source.rb`
                     `app/domain/use_cases/catalog/load_repository_lessons.rb` · `app/domain/use_cases/catalog/import_course_tree.rb`
                     `app/domain/ports/catalog/content_tree_writer_port.rb` · `app/infrastructure/repositories/catalog/content_tree_writer.rb`
                     `lib/tasks/contenus.rake`
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/catalog/{automatic_load_stage,v3_programme_levels}_test.rb`
                     `test/domain/use_cases/catalog/{load_repository_lessons,import_course_tree}_test.rb`
                     `test/infrastructure/repositories/catalog/{repository_lesson_source,content_tree_writer_replace_lesson}_test.rb`
                     `test/integration/catalog/automatic_lesson_load_test.rb`
- **Done quand**   : CA-1 à CA-8 verts ; temps du premier chargement mesuré en local et noté dans l'ADR.
