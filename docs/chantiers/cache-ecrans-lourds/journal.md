# Journal — Écrans lourds : mesurer avant de mettre en cache

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Protocole

Rejouable par le challenger sans poser de question. Worktree propre, base de développement **dédiée** (le suffixe de `config/database.yml` isole chaque worktree).

```bash
bin/rails db:reset                                 # 4 établissements de db/seeds + comptes de développement (PIN 2468)
bin/rails runner script/perf/seed_dataset.rb       # ≈ 2 min ; refuse de semer deux fois
# Mode production sur la base de développement. Les variables BUCKET_* sont factices : elles ne servent
# qu'à charger config/storage.yml, aucun appel n'est fait.
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 RAILS_LOG_LEVEL=warn \
BUCKET_NAME=bench BUCKET_ENDPOINT=http://127.0.0.1:9 BUCKET_ACCESS_KEY_ID=x BUCKET_SECRET_ACCESS_KEY=x \
DATABASE_URL=postgres://dev-rails:dev-rails@localhost:5432/app_lnclassapp_development<suffixe> \
bin/rails runner script/perf/measure_screens.rb    # ≈ 2 min ; tableau Markdown + tmp/perf-screens.json
```

- **Trois exécutions**, médiane par écran et par colonne. `PERF_RUNS` (30 par défaut) fixe le nombre de requêtes mesurées par écran. `PERF_ONLY=dashboard,admin` restreint la mesure à certains écrans.
- Le bench lance `ANALYZE` avant de mesurer : juste après l'insertion en masse, les statistiques du planificateur sont vides.
- **Connexion** : un vrai `POST /session` avec le PIN. Le second facteur de l'équipe est marqué vérifié directement en base : en production, le secret TOTP est chiffré avec une clé absente du poste. Chaque compte se connecte depuis une adresse privée tirée au hasard, parce que la connexion est limitée à 5 par minute et par adresse. Un premier essai a reçu un 429.
- **Comptes mesurés** : équipe `0700000000` (seeds), enseignant `0520000001` (6 classes du lycée focus), élève `0120000001` (classe du lycée focus), direction `0720000001`.
- **Détection de N+1** : chaque SQL est réduit à sa forme (littéraux et listes remplacés par `?`), puis les formes identiques sont comptées dans un même rendu. Ce comptage remplace le doublement du jeu de données prévu par le cycle : il donne la même information sans semer deux fois.
- **Ko gzip** : `Zlib.gzip` du corps, pour approcher ce que Thruster envoie.

Aucune gem ajoutée : `ActiveSupport::Notifications` (`sql.active_record`, `process_action.action_controller`), `GC.stat`, `Zlib`, `ActionDispatch::Integration::Session`.

## Où part le temps

`EXPLAIN (ANALYZE, BUFFERS)` sur les requêtes les plus lentes, relevées par le bench (`slowest` dans `tmp/perf-screens.json`), même jeu de données.

### Travail des élèves — `Queries::School::StudentWorkQuery#totals_by` (195 ms sur 214)

- Une seule requête coûte **198 à 208 ms**. Le planificateur estime **1 ligne** là où il y en a **29 177**. Il construit alors une table de hachage sur **toutes** les adhésions (40 001 lignes, `Seq Scan on classroom_students`), la joint aux 765 devoirs de la classe (42 075 couples), puis fait **42 075 lectures d'index** `exercise_sessions (student_id, completed_at)`. 260 698 lignes sont rejetées par le filtre de jointure. Total : 274 882 pages lues.
- Le tri `COUNT(DISTINCT (student_id, classroom_assignment_id))` prend environ 50 ms à lui seul (quicksort de 29 177 lignes).
- Les deux autres requêtes de la page coûtent 12 ms et 3 ms.
- Piste : partir des 765 devoirs, sur un index `exercise_sessions (classroom_assignment_id, …)` restreint aux sessions terminées standard (memo, piste 1).

### Pilotage — `Queries::School::TeamDashboardQuery` (298 à 362 ms en SQL)

Le coût n'est pas concentré dans une requête : il est réparti sur des jointures répétées.

| Requête (période « année ») | Temps | Plan |
|---|--:|---|
| `drena_rows` : élèves placés actifs par DRENA (`placements.where(student_id: sessions depuis …)`) | 99 à 141 ms | parcours complets de `exercise_sessions` (149 577 lignes), `classroom_students`, `users`, `classrooms` |
| `flows` : élèves actifs (`COUNT(DISTINCT student_id)` sur `started_at`) | 69 à 107 ms | `Seq Scan on exercise_sessions` + `users` |
| `flows` : exercices terminés + moyenne | 41 à 50 ms | `Parallel Seq Scan on exercise_sessions` |
| `coverage` : établissements avec classe, enseignant, élève | 40 à 44 ms | 3 sous-requêtes `EXISTS` par établissement |
| `placed_by_level` | 39 à 47 ms | jointure complète à quatre tables |
| `drena_rows` : élèves placés par DRENA | 32 à 47 ms | la même jointure une seconde fois |

- Aucun index sur `exercise_sessions.started_at` ni sur `completed_at`, comme l'ADR-0062 l'annonçait.
- La jointure des placements (`classroom_students × users × classrooms × schools`) est calculée **quatre fois** : total, par niveau, par DRENA, actifs par DRENA. Chaque passage coûte 30 à 100 ms à 40 000 élèves.

### Recherche du pilotage — `Queries::Identity::AccountSearchQuery` (250 ms)

- Deux requêtes identiques dans leur filtre, le `COUNT(*)` et la page : **deux `Seq Scan on users`** de 123 à 127 ms chacun. `translate(lower(first || ' ' || last))` est évalué deux fois par ligne, sur 44 154 lignes. « kou » trouve 5 693 comptes.
- Les deux requêtes de placement qui suivent coûtent 1,4 ms.

### Listes au rendu — `teams/schools/_school_row`, `catalog/courses/_course_card`

- Établissements : chaque ligne porte un menu ⋮, **deux** `ui_modal`, chacune avec son `form_with` (jeton CSRF compris), et les icônes SVG en ligne. Cela fait **≈ 11 Ko de HTML par ligne**, 578 Ko pour 50 lignes, 113 000 allocations et 61 ms de vue. Le SQL tient en 5 ms.
- Catalogue : 210 cartes à ≈ 2,6 Ko chacune (badge de matière, badge de niveau, icône SVG), 550 Ko, 117 000 allocations, 58 ms de vue. Le SQL tient en 5 ms (une seule requête `pluck`).

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-29 | Mesurer en `RAILS_ENV=production` sur la base de développement, et non en développement | Le mode développement ajoute Bullet, le rechargement, l'annotation des gabarits et les logs verbeux : les temps de vue n'y sont pas représentatifs | non |
| 2026-09-29 | Jeu de données en insertion massive (`insert_all!`), identifiants générés dans le script, graine fixe | 2 minutes au lieu d'heures par les use cases ; mêmes volumes à chaque exécution (ADR-0020 pour le procédé) | non : script de mesure, hors `app/` |
| 2026-09-29 | Ni `question_attempts` ni photos dans le jeu | Aucun des écrans mesurés ne les lit (page de résultat d'une session hors liste) | non |
| 2026-09-29 | Scripts dans `script/perf/`, pas dans `test/performance` | Ils écrivent dans la base de développement et ne doivent jamais tourner dans la suite ; `bin/rubocop` les couvre | non |

## Ce qui a dérapé

- Premier lancement en mode production : échec au démarrage, parce que `config/storage.yml` (service `railway`) exige `BUCKET_NAME`. Contourné par des variables factices : Active Storage n'est jamais appelé par les écrans mesurés.
- Deuxième lancement du bench dans la même minute : `POST /session` renvoie un 429 (`rate_limit to: 5, within: 1.minute`, par adresse). Corrigé par une adresse distante tirée au hasard pour chaque compte.

## Ce qu'on a appris sur la codebase

- Les 28 écrans mesurés sont **sans N+1** : le principe « une query CQRS, un nombre fixe de requêtes » (ADR-0006, ADR-0062) tient à l'échelle.
- Les tests de performance existants (`test/performance/**`, `PERF=1`) ne couvrent que les **écritures massives** (imports, génération de classes). Aucun test ne couvre le temps de lecture d'un écran.
- `/teams/dashboard?q=…` recalcule les indicateurs **et** la recherche quand la page entière est demandée. Seul le frame de recherche est léger.
- Le planificateur se trompe lourdement sur les jointures de `StudentWorkQuery` (1 ligne estimée pour 29 177 réelles). Un index seul ne suffira peut-être pas : il faudra aussi réécrire la requête.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Les cinq pistes du memo | Porteur, 2026-09-29 : mesurer d'abord, ne rien optimiser encore | ce chantier, phases 2 à 5, après décision |
| Un bench avec des sessions réparties sur une année complète | Pas encore demandé (question 3 du memo) | ce chantier |

## Clôture

| | |
|---|---|
| **Livré le** | — |
| **PR** | — |
| **ADR produits** | — |
| **UDR produits** | — |
