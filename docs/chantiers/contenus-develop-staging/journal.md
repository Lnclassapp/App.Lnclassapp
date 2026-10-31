# Journal — Les leçons arrivent seules sur Develop et Staging

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-31 | « Dernier chargement réussi » = dernier rapport `course_tree` **terminé, sans erreur, avec au moins un élément écrit**, dont le fichier porte le nom `chargement-automatique-…` (colonne `files` en jsonb). | Un rapport terminé avec une erreur (niveau absent, notion introuvable) ne doit pas passer pour un chargement : la leçon est retentée au déploiement suivant (PRD §3). | Non (précision du §4.3 de l'ADR) |
| 2026-10-31 | La ligne « environnement non reconnu » est un rapport créé directement `rejected` (`record_rejection`), avec pour empreinte le SHA-256 de `unknown_environment:<nom>` (la colonne est obligatoire). Une ligne par démarrage tant que le nom reste inconnu. | Le moteur d'import ne sait pas refuser sans fichier ; le rapport n'est jamais « en cours », donc il ne bloque aucun import. | Non |
| 2026-10-31 | Libellé `notion_not_found` : « notion introuvable dans la **fiche de cours** : %{name} » (et non « dans la leçon »). | `test/i18n/locale_files_test.rb` interdit « leçon » (UDR-0007) dans les locales. | Non |
| 2026-10-31 | Le use case reçoit `policy:` (ManageContentPolicy) et l'applique à l'auteur trouvé. | `test/architecture/use_case_policies_test.rb` exige une policy injectée (ADR-0028) ; inatteignable en pratique (l'auteur est de l'équipe) mais testé. | Non |
| 2026-10-31 | Verrou consultatif lu hors du cache de requêtes (`connection.uncached`). | Dans les tests (cache actif) le second `pg_try_advisory_lock` renvoyait la réponse mémorisée du premier. | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Le plan ne listait pas quelques fichiers indispensables, ajoutés par ce lot (lectures ou constantes seulement) : `app/domain/entities/catalog/import_error.rb` (+ son test, 39 → 41 codes : `ImportError` refuse tout code hors liste fermée), `CourseRepository#slugs_by_key` (+ port : retrouver le slug de la leçon que l'import vient d'écrire), `UserRepository#oldest_active_team_actor` (+ port : « plus ancien membre actif de l'équipe »).
- Tests système non lancés : ce lot ne touche aucune vue, contrôleur, composant, CSS ni Stimulus. Les 88 erreurs `application.css introuvable` de `test/integration` viennent d'un worktree sans assets compilés, pas du lot.
- Limite connue : si l'import réussit mais que la publication échoue en cours de route (exception), le rapport est « terminé » et le fichier ne sera pas retenté tant qu'il ne change pas ; un refus partiel de publication (exercice non publiable) laisse l'exercice en brouillon sans nouvelle ligne.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `Data.define do … end` : une constante écrite dans le bloc se déclare dans le module englobant, pas sur la classe ; `AutomaticLoadStage::LOADING` est donc posée après le bloc.
- `ActiveRecord::Base.connection_pool.checkout` dans un test rend la connexion partagée (même session PostgreSQL) : pour simuler « un autre démarrage » tenant le verrou, il faut une vraie connexion `PG.connect`.
- Le verrou consultatif est un verrou de session : un test qui échoue avant `pg_advisory_unlock` le laisse sur la connexion partagée de tout le processus de test.

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
