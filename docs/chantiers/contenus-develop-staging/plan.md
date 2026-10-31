# Plan d'exécution — Les leçons arrivent seules sur Develop et Staging

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — chargement automatique (seul, séquentiel)
```

Un seul cas d'usage, de bout en bout : pas de Lot 0 (aucune migration, aucune route, aucune vue ; le seul fichier partagé, la locale des imports, appartient au Lot A).

---

## Lot A — Develop et Staging chargent seuls les leçons à sujets de devoir

- **Couche**       : domaine + infrastructure + delivery (tâche de démarrage)
- **Fichiers**     : `app/domain/entities/catalog/automatic_load_stage.rb` (nouveau : Develop, Staging, production, PR, inconnu)
                     `app/domain/ports/catalog/lesson_source_port.rb` (nouveau : fichiers de leçon du dépôt, nom, empreinte, document)
                     `app/domain/use_cases/catalog/load_repository_lessons.rb` (nouveau)
                     `app/domain/use_cases/catalog/import_course_tree.rb` (mode « remplacer une leçon publiée », réservé à cet appelant)
                     `app/domain/ports/catalog/content_tree_writer_port.rb` · `app/infrastructure/repositories/catalog/content_tree_writer.rb` (remplacement d'une leçon publiée sur demande explicite)
                     `app/domain/ports/catalog/import_report_repository_port.rb` · `app/infrastructure/repositories/catalog/import_report_repository.rb` (dernière empreinte réussie par nom de fichier ; ligne refusée « environnement non reconnu »)
                     `app/infrastructure/repositories/catalog/repository_lesson_source.rb` (nouveau : lit `docs/contenus/lecons-traitees`)
                     `lib/tasks/contenus.rake` (nouveau : `contenus:charger`, verrou consultatif, jamais d'exception sortante)
                     `bin/docker-entrypoint` (lance la tâche après `db:prepare`)
                     `config/locales/teams/imports.fr.yml` (`unknown_environment`)
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/catalog/automatic_load_stage_test.rb`
                     `test/domain/use_cases/catalog/load_repository_lessons_test.rb`
                     `test/integration/catalog/automatic_lesson_load_test.rb` (vraie base : les 7 scénarios du PRD §4)
                     `test/domain/use_cases/catalog/import_course_tree_test.rb` (l'import à la main refuse toujours une leçon publiée)
- **Done quand**   : avec `RAILWAY_ENVIRONMENT_NAME=Develop`, `bin/rails contenus:charger` sur une base où Thalès est publiée avec l'ancien contenu et une séance d'élève remplace ses exercices et sujets (4 sujets, 2 exercices par notion, tout publié, séance effacée, texte des fiches inchangé) et laisse une ligne terminée dans l'écran Imports ; relancé, il ne fait rien ; avec `production`, rien ; avec `Recette`, une ligne refusée « environnement non reconnu : Recette ».

---

## Vérification de collision

Un seul lot : pas de collision possible.

| Fichier | Lot propriétaire |
|---|---|
| `config/locales/teams/imports.fr.yml` | Lot A |
| `bin/docker-entrypoint` | Lot A |

## Dispatch

```
Vague 1 : Lot A → 1 agent (executant-lot), worktree /home/user/lnclass-contenus-develop-staging
```

## Portes de sortie

- [ ] Tous les lots sont `Done`
- [ ] Un rôle distinct de l'auteur a **exécuté** le résultat (tests lancés, parcours refait dans l'application)
- [ ] Pureté du domaine, rubocop, tests, parcours système : au vert
- [ ] ADR et UDR à jour et indexés
- [ ] `journal.md` complété

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Ici : il lance `contenus:charger` sur une base de développement avec `RAILWAY_ENVIRONMENT_NAME=Develop` (Thalès publiée, ancienne version, une séance d'élève), vérifie à l'écran « Prépare devoirs » à 4 sujets et la ligne dans Imports, relance (rien), puis `Recette` (ligne refusée) et `production` (rien).
