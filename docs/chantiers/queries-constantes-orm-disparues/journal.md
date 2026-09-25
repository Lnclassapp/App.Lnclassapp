# Journal — Requêtes de lecture appelant des modèles ORM disparus

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-24 | Périmètre réduit aux 4 appels hérités d'avant l'ADR-0007 | Le memo initial mélangeait 3 causes distinctes. Un bug, un correctif | Non |
| 2026-09-24 | `classroom-assignment-belongs-to-casses` est livré **avant** ce chantier | Les vues du flux appellent `ce.essential` / `ce.exercise`. Corriger les queries seules ferait replanter la page dès la première assignation | Non |
| 2026-09-24 | Pas d'ADR : la cause n'est pas architecturale | L'architecture cible existe déjà (ADR-0007). Il s'agit d'une migration incomplète | — |

## Ce qui a dérapé

- **Balayage faux, affirmé comme vrai (2026-09-24).** L'expression `grep -E "…[^\n]*…"` ne veut pas dire « sans saut de ligne » : dans une classe de caractères, `grep` lit `\n` comme « antislash ou lettre n ». Toute ligne contenant un « n » était exclue, et `classroom_essentials_controller.rb:25` est passé au travers. C'est le challenger qui l'a trouvé en rejouant l'application. **Leçon** : un balayage se valide en vérifiant qu'il retrouve les cas déjà connus, avant de conclure qu'il n'y en a plus. Refait en `grep -rPzo` (multi-ligne), il retrouve bien les 3 sites connus, et plus aucun appel cassé.

- 2026-09-18 → 2026-09-24 : le chantier est resté en cadrage sans branche. Pendant ce temps, le bug a été signalé une seconde fois (flux enseignant, capture du 2026-09-24).

## Ce qu'on a appris sur la codebase

### Rapport root cause — 2026-09-24

**Chaîne d'appels (flux enseignant)**

```
GET /teachers
→ Teachers::FeedController#index                       (app/controllers/teachers/feed_controller.rb:17)
→ UseCases::Identity::GetTeacherFeed#execute           (app/domain/use_cases/identity/get_teacher_feed.rb:51)
→ Queries::TeachersFeedQuery#get_recent_essentials_in_classrooms
→ Orm::ClassroomEssential                              (app/infrastructure/queries/teachers_feed_query.rb:49)  ← NameError
```

Le chemin n'est atteint que si l'enseignant a au moins une classe. Sans classe, le use case rend la main avant, ligne 38.

**Cause, en une phrase qui ne reprend pas les mots du symptôme** : le commit `0991bd3` (2026-08-29) a appliqué l'ADR-0007 aux modèles ORM et aux repositories d'écriture, mais pas aux objets de lecture CQRS (`app/infrastructure/queries/`) ni à un contrôleur. Ceux-ci désignent encore l'ancien schéma d'une table par type de ressource.

**Fichiers et lignes fautifs**

- `app/infrastructure/queries/teachers_feed_query.rb:49,53`
- `app/infrastructure/queries/student_feed_query.rb:23-24` (`Orm::Course#classroom_courses` n'existe plus) et `:30`
- `app/controllers/teachers/classroom_exercises_controller.rb:76`

**Pourquoi aucun test ne l'a détecté**

1. **Aucun test des queries** : `test/infrastructure/queries/` n'existe pas. `Queries::TeachersFeedQuery` et `Queries::StudentFeedQuery` n'ont jamais été instanciés en test.
2. **Aucun test du use case ni du contrôleur de flux** : aucune référence à `GetTeacherFeed`, `TeachersFeedQuery` ou `teachers_feed` dans `test/`.
3. **Le chargement à l'avance (`eager_load`) ne protège pas** : Zeitwerk résout une constante citée *dans le corps d'une méthode* à l'exécution, pas au chargement. `eager_load` en CI charge le fichier sans erreur.
4. **Les fixtures ne créent aucune assignation** : même un test du flux sur base vide ne ferait pas planter les raccourcis `belongs_to` des vues.

→ Les tests de reproduction vont dans `test/infrastructure/queries/` (niveau le plus bas qui reproduit) et doivent créer au moins une assignation active **et** une archivée.

**Vérifié par `bin/rails runner` (dev, 2026-09-24)**

- `get_recent_essentials_in_classrooms([79])` → `NameError: uninitialized constant Orm::ClassroomEssential`.
- La base de dev contient 0 assignation `Orm::Essential` pour l'enseignant 1. Le piège des `belongs_to` scopés ne peut donc pas s'y manifester : il faudra des données pour le challenger.

### Autres découvertes

- `app/controllers/schoolstaff/feed_controller.rb` n'appelle ni query ni use case, alors que sa vue `schoolstaff/feed/content/_activities.html.erb` lit `@essentials_in_classrooms` : c'est une copie de la vue enseignant, sans donnée derrière.

### Exécution — 2026-09-24

- **Rouge d'abord**, 8 tests :
  - `test/infrastructure/queries/teachers_feed_query_test.rb` (3) → `NameError … Orm::ClassroomEssential` ;
  - `test/infrastructure/queries/student_feed_query_test.rb` (3) → `NameError … Orm::ClassroomExercise` et `ConfigurationError … classroom_courses` ;
  - `test/controllers/teachers/feed_controller_test.rb` → l'erreur exacte de la capture, via `feed_controller.rb:23` ;
  - `test/controllers/teachers/classroom_exercises_controller_test.rb` → `NameError` à la ligne 76.
- **Premier rouge pour une mauvaise raison** : `unique_code` est un `varchar(5)`, et mes codes de test faisaient 8 caractères. Montage corrigé, puis rouge revérifié.
- **Correctif** : les deux queries lisent `Orm::ClassroomAssignment.active` filtré sur `resource_type`. Ajout de `ClassroomAssignment#exercise_id`, qu'attend `GetStudentFeed:40` (contrat de la query, sans toucher au domaine). Suppression de la ligne morte `classroom_exercises_controller.rb:76`, qu'aucune vue ne lisait. En-tête du repository corrigé.
- **Vert** : `bin/rails test` → 391 tests, 0 échec, 0 `skip`. Rubocop et brakeman propres.
- **Cas symétrique** : un enseignant sans classe est toujours redirigé vers `teachers_classrooms_path` (test ajouté).
- **Contrôle sur la base de dev** (transaction annulée) : `GetTeacherFeed` pour l'enseignant 1, avec une fiche assignée à la classe 79 → `success=true`, la fiche, sa matière et sa classe s'affichent.
- **Périmètre élargi à la demande de l'utilisateur (2026-09-24)** : `app/controllers/classroom/teachers/classrooms_controller.rb`, même cause, deux appels :
  - ligne 52 : `classroom_essentials.index_by(&:essential_id)` → `NoMethodError`, et variable lue par aucune vue → ligne supprimée ;
  - lignes 60-62 : `.where(exercise_id: …)` → `PG::UndefinedColumn` sur la page d'une fiche. Remplacé par `.active.where(resource_id: …)`. La variable est lue par `components/_exercise_card.html.erb:140`.
  - Rouge d'abord : `test/controllers/teachers/classrooms_controller_test.rb` (2 tests, les deux messages ci-dessus), puis vert. Suite complète : 394 tests, 0 échec.
  - ~~Balayage de `app/` : plus aucune lecture d'une ancienne colonne `*_id` sur les associations de classe.~~ **Faux**, voir « Ce qui a dérapé ».

### Preuve — challenger, 2026-09-24

Rôle distinct de l'auteur. Parcours HTTP complet sur la base de dev, dans une transaction annulée ; aucun résidu (users 15012 → 15012, classroom_assignments 0 → 0).

| # | Parcours | Verdict |
|---|---|---|
| 1 | `GET /teachers` (symptôme d'origine), 2 classes dans 2 écoles | 200 · fiches actives présentes, archivée absente |
| 2 | Page cours d'une classe | 200 |
| 3 | Page fiche d'une classe | 200 · exercice actif « Assigné » + « Résultats », archivé « Assigner » |
| 4 | Résultats d'un exercice (avec et sans `classroom_id`, et `/report`) | 200 |
| 5 | Flux élève | 200 · matière et exercice actifs présents, archivés absents |
| 6 | Enseignant sans classe · garde de type | redirigé vers `/teachers/classrooms` · `nil` |
| 7 | `bin/rails test` | 394 tests, 0 échec |

Verdict initial : **ne peut pas être fermé**, à cause d'un 7ᵉ appel de même cause (défaut A), puis :

- **Défaut A corrigé** : `classroom_essentials_controller.rb:25`, `.where(exercise_id:)` → `.active.where(resource_id:)`. Rouge d'abord (`PG::UndefinedColumn`, `test/controllers/classroom_essentials_controller_test.rb`), puis vert. Suite complète : 395 tests, 0 échec.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Boucle de redirection `/` ↔ `/students` (élève sans classe) | Cause distincte (routage / redirections) | à ouvrir : `redirection-boucle-eleve-sans-classe` |
| Boucle de redirection `/` ↔ `/teachers/classrooms` (enseignant sans école) | Cause distincte | à ouvrir : `redirection-boucle-enseignant-sans-ecole` |
| `@teacher_classrooms` jamais affecté → bouton d'assignation mort (`catalog/courses/show.html.erb:68`) | Spec manquante plus que bug : relève probablement de `/feature` | à ouvrir |
| Vue schoolstaff du flux sans données | Hors du chemin enseignant/élève | à ouvrir |
| **Défaut B (challenger)** : `GET /classrooms/:id` → 500 `undefined method 'course' for Orm::Course` dès qu'un cours est assigné (`classroom/classrooms/show.html.erb:156`). `Queries::ClassroomDashboardQuery#get_classroom_details` renvoie des ressources (`map(&:resource)`) là où la vue attend des assignations ; même décalage dans `_classroom_exercise.html.erb`. Page atteignable depuis `_classroom_card.html.erb` et `catalog/schools/show.html.erb` | Cause distincte : contrat de retour de la query, pas le schéma disparu | à ouvrir : `classroom-dashboard-ressources-vs-assignations` |
| Action morte `Classroom::ClassroomEssentialsController#show` : aucun template (406), aucun lien. Sa requête est corrigée, pas supprimée | La supprimer touche `config/routes.rb`, fichier partagé | nettoyage à ouvrir |
| `classroom/teachers/classrooms_controller.rb:42` : `@classroom_exercises_by_exercise_id` inclut les assignations archivées, mais n'est lue par aucune vue | Ne plante pas ; probablement du code mort | à trancher lors d'un nettoyage |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-09-24 |
| **PR** | aucune — fusion directe dans `Develop` |
| **ADR produits** | aucun |
| **UDR produits** | aucun |
