# Journal — Écrans lourds : mesurer avant de mettre en cache

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Protocole

Rejouable par le challenger sans poser de question. Worktree propre, base de développement **dédiée** (le suffixe de `config/database.yml` isole chaque worktree).

```bash
bin/rails db:reset                                 # 4 établissements de db/seeds + comptes de développement (PIN 2468)
bin/rails runner script/perf/seed_dataset.rb       # ≈ 2 min ; refuse de semer deux fois (module : script/perf/dataset.rb)
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

### Après les leviers (2026-09-29, phases 4 et 5)

Requête par requête, `psql` sur la base semée, médiane de 5 exécutions (connexion comprise, ≈ 1 ms) :

| Requête | Avant | Après | Levier |
|---|--:|--:|---|
| `StudentWorkQuery#totals_by` (77 classes, 765 devoirs) | 195 ms | **29 ms** | lot 1 : réécriture seule 195 → 65 ms ; + index partiel → 36 ms (`Index Only Scan`, 0 lecture de table) |
| Pilotage 7 j, élèves actifs (`COUNT(DISTINCT)` sur `started_at`) | 53 ms | 30 ms | lot 2a, `(started_at, student_id)` en index seul |
| Pilotage 7 j, exercices terminés + moyenne | 35 ms | 21 ms | lot 2a, index partiel `completed_at` |
| Pilotage, 10 derniers inscrits | 17,5 ms | 1,9 ms | lot 2a, `users (created_at, id)` lu à rebours |
| Pilotage, nouveaux inscrits | 5,4 ms | 3,7 ms | lot 2a |
| Pilotage 7 j, assignations | 8,7 ms | 7,6 ms | lot 2a, `assigned_at` (voir « leviers gardés à la limite ») |
| Pilotage 7 j, 3 jointures des placements | 40 + 36 + 88 ms | **59 ms** (une lecture) | lot 2b |
| Pilotage année, 3 jointures des placements | 40 + 40 + 123 ms | **98 ms** (une lecture) | lot 2b |
| Recherche « kou », `COUNT(*)` puis page | 125 + 125 ms | 14,5 + 16 ms | lot 3, `BitmapOr` sur les deux index trigrammes |
| Recherche « ko » (2 caractères) | 124 ms | 124 ms | aucun trigramme complet : parcours séquentiel, comme avant — pas de régression |

Ce qui reste dans le pilotage « année » (≈ 250 ms de SQL) : les élèves actifs (70 ms, 145 000 sessions depuis le 1ᵉʳ septembre, soit la moitié de la table), la lecture groupée des placements (98 ms, dont la table de hachage des 148 000 sessions de la période), la couverture (42 ms, trois `EXISTS` par établissement), les exercices terminés (32 ms). Tous croissent avec les sessions de l'année.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-29 | Mesurer en `RAILS_ENV=production` sur la base de développement, et non en développement | Le mode développement ajoute Bullet, le rechargement, l'annotation des gabarits et les logs verbeux : les temps de vue n'y sont pas représentatifs | non |
| 2026-09-29 | Jeu de données en insertion massive (`insert_all!`), identifiants générés dans le script, graine fixe | 2 minutes au lieu d'heures par les use cases ; mêmes volumes à chaque exécution (ADR-0020 pour le procédé) | non : script de mesure, hors `app/` |
| 2026-09-29 | Ni `question_attempts` ni photos dans le jeu | Aucun des écrans mesurés ne les lit (page de résultat d'une session hors liste) | non |
| 2026-09-29 | Scripts dans `script/perf/`, pas dans `test/performance` | Ils écrivent dans la base de développement et ne doivent jamais tourner dans la suite ; `bin/rubocop` les couvre | non |

| 2026-09-29 | `totals_by` part des adhésions présentes des classes et lit une ligne par (classe, devoir, élève) | Le planificateur estimait 1 ligne pour 29 177 et joignait toutes les adhésions ; pré-agréger par couple supprime aussi le tri du `COUNT(DISTINCT (élève, devoir))` | non : mêmes définitions (ADR-0065 §4) |
| 2026-09-29 | Index de sessions **couvrants** (`INCLUDE`) et partiels | Les lectures se font en `Index Only Scan` sans toucher la table ; l'index partiel ne porte que les sessions qui comptent | ADR-0067 §4 (liste des leviers) |
| 2026-09-29 | `users (created_at, id)` plutôt que `users (created_at)` | Le même index sert le comptage de la période et « les 10 derniers inscrits » (`ORDER BY created_at DESC, id DESC`) : 17,5 → 1,9 ms | non |
| 2026-09-29 | Trigramme aussi sur `schools.national_code` | Sans lui, le `OR` de `SchoolsQuery` ne peut pas se faire en `BitmapOr` : un seul membre sans index et tout repart en parcours séquentiel. Mesuré sur 4 032 établissements (jeu × 8, proche des ≈ 3 900 de la production) : 14 ms en parcours, 0,8 ms avec les trois index | amendement ADR-0062 |
| 2026-09-29 | `script/perf/seed_dataset.rb` scindé : le module va dans `script/perf/dataset.rb` | Le test `PERF=1` sème le même jeu dans la base de test ; `seed_dataset.rb` garde sa garde « développement seulement » | non |
| 2026-09-29 | Le test `PERF=1` **commet** le jeu puis `VACUUM ANALYZE`, et vide les tables après | Dans la transaction d'un test, aucune page n'est « all-visible » : chaque `Index Only Scan` retournerait à la table et le test mesurerait un cas qui n'existe pas en production | ADR-0067 §6 |
| 2026-09-29 | Vue « année » : agrégats gardés 5 min dans Solid Cache, derniers inscrits exclus du cache | Décision du porteur. Exclure les inscrits garde le cache sans donnée personnelle et montre un nouveau compte tout de suite ; ils coûtent 5 ms en direct | ADR-0062, second amendement |
| 2026-09-29 | Clé construite sur la DRENA **résolue** (son `public_id` en base), l'année scolaire et le début de période, versionnée | Une valeur d'URL n'entre jamais dans la clé ; une DRENA inconnue lit l'entrée nationale au lieu d'en créer une par valeur tapée | ADR-0062, second amendement |
| 2026-09-29 | Cache injecté dans la query (`cache: Rails.cache`) | Le test compare avec un `NullStore` ; le store de test est déjà un `memory_store` vidé avant chaque test | non |
| 2026-09-29 | `GrowthMigrationsTest` rejoue `AddTrigramSearchIndexes` après « up » | Ce test supprime et recrée `schools.national_code`, ce qui effaçait l'index trigramme de sa base de test ; la vérification de l'index dans `trigram_search_indexes_test.rb` était alors intermittente. On restaure l'état plutôt que d'affaiblir la vérification | non |

## Leviers gardés à la limite, leviers écartés

- **`classroom_assignments (assigned_at)`** : gain de 1 ms sur 7 jours (8,7 → 7,6 ms), nul sur l'année. Le cycle dit d'annuler un levier marginal. Il est gardé parce que le porteur l'a demandé et que l'ADR-0062 l'avait décidé : la table n'est jamais purgée, et sans index le comptage de la semaine parcourt les devoirs de toutes les années. **À réévaluer** si l'écriture des devoirs en pâtit.
- **Index trigrammes des établissements** : aucun gain au volume du bench (504 établissements : le planificateur garde le parcours séquentiel, 3 ms). Gardés sur la mesure au volume de la production (≈ 3 900 établissements, ci-dessus).
- **Réécriture des « élèves actifs »** en `users WHERE id IN (sessions de la période)` : 67 → 55 ms sur l'année, 31 → 30 ms sur 7 jours. Marginal : **non appliquée**.
- **Cache court du pilotage** : d'abord écarté (ADR-0062, option B). Après la mesure (vue « année » à 304 ms en p95), le porteur l'a retenu le 2026-09-29 pour la seule vue « année », 5 minutes (lot 2c, second amendement de l'ADR-0062). 7 et 30 jours restent en direct.

## Ce qui a dérapé

- Premier lancement en mode production : échec au démarrage, parce que `config/storage.yml` (service `railway`) exige `BUCKET_NAME`. Contourné par des variables factices : Active Storage n'est jamais appelé par les écrans mesurés.
- **Mesures faussées par la charge.** Un autre agent (`finitions-ux`) jouait ses tests système en même temps (charge de 5 à 20 sur 4 vCPU). Une série prise sous charge donnait le pilotage 7 j à 214 ms au lieu de 190 et « Établissements, recherche » à 50 ms au lieu de 38. La mesure « après » retenue attend une charge sous 1,5 avant chaque exécution (`bench_quiet`, même script, même jeu).
- Deuxième lancement du bench dans la même minute : `POST /session` renvoie un 429 (`rate_limit to: 5, within: 1.minute`, par adresse). Corrigé par une adresse distante tirée au hasard pour chaque compte.

## Ce qu'on a appris sur la codebase

- Les 28 écrans mesurés sont **sans N+1** : le principe « une query CQRS, un nombre fixe de requêtes » (ADR-0006, ADR-0062) tient à l'échelle.
- Les tests de performance existants (`test/performance/**`, `PERF=1`) ne couvrent que les **écritures massives** (imports, génération de classes). Aucun test ne couvre le temps de lecture d'un écran.
- `/teams/dashboard?q=…` recalcule les indicateurs **et** la recherche quand la page entière est demandée. Seul le frame de recherche est léger.
- Le planificateur se trompe lourdement sur les jointures de `StudentWorkQuery` (1 ligne estimée pour 29 177 réelles). Un index seul ne suffira peut-être pas : il faudra aussi réécrire la requête.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Piste 5 : listes légères (modale unique des établissements, fragment des cartes du catalogue) | Porteur, 2026-09-29 : après les lots UX qui touchent ces vues ; le fragment demande un ADR de cache | ce chantier, lot 5 du [plan](plan.md) |
| Un bench avec des sessions réparties sur une année complète (≈ 1,5 million) | Question 3 du memo, non tranchée ; le pilotage « année » est à la limite du budget | ce chantier ou un suivi |
| Recherche par numéro (`users.contact LIKE '%1234%'`) | Hors décision du porteur (noms seulement) ; parcours séquentiel de `users` | à mesurer si la recherche devient dynamique |
| Coût en écriture des nouveaux index | Non mesuré | à mesurer à la prochaine recette d'import |

## Clôture

| | |
|---|---|
| **Livré le** | — |
| **PR** | — |
| **ADR produits** | [ADR-0067](../../decisions/adr/0067-budgets-de-temps-serveur-des-ecrans.md) ; amendement de l'[ADR-0062](../../decisions/adr/0062-indicateurs-de-pilotage-lus-en-direct.md) |
| **UDR produits** | — |
