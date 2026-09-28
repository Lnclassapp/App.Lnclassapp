# Memo — Trois tests instables sous CI bloquée

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré (PR vers `Develop`, en attente de fusion) |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `fix/tests-instables` |
| **Programme** | `refonte-application` — étape 0 de l'ordre V2 → V6, question Q15 ([feuille de route §5](../refonte-application/feuille-de-route.md#dette-suivie-par-le-programme)) |

---

## Le problème

Trois tests échouent par intermittence, sans changement de code entre deux exécutions. Tant que la CI GitHub est bloquée (jusqu'au 2026-10-03), chaque échec coûte un `bin/ci` local complet, et la tentation est de relancer jusqu'au vert : c'est exactement ce que ce chantier interdit.

## Symptômes (littéraux)

| # | Test | Message |
|---|---|---|
| 1 | `JoinRequestConcurrencyTest` (`test/infrastructure/repositories/school/join_request_concurrency_test.rb`) | `ActiveRecord::PreparedStatementCacheExpired: ERROR:  cached plan must not change result type`, levée par `Orm::SchoolJoinRequest.create!` (`join_request_repository.rb:24`) dans un fil du test |
| 2 | `RoleHomesTest` (`test/system/role_homes_test.rb`), équipe | `Capybara::ElementNotFound: Unable to find visible css "#account-menu a[role=menuitem][href='/profile']" with text "Mon profil"` — [run 151, essai 3, job `system:4/6`](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36398103132/job/108867747561), graine 28331 |
| 3 | `Assessment::SessionResultTest` (`test/system/assessment/session_result_test.rb:42`) | après « Recommencer », `expected "/sessions/<ancienne>/result" to match /\A\/sessions\/(?!<ancienne>)[^\/]+\z/` |

## Reproduction

| # | Étapes exactes | Résultat avant correctif |
|---|---|---|
| 1 | `COVERAGE=0 PARALLEL_WORKERS=1 bin/rails test test/infrastructure/repositories/school/join_request_concurrency_test.rb test/db/growth_migrations_test.rb test/db/add_school_codes_migration_test.rb test/integration/classroom/join_capacity_test.rb test/integration/assessment/double_submission_test.rb --seed 4` | rouge **3 fois sur 3** à la graine 4 (1 graine sur 25 essayées) ; ordre fautif : `JoinCapacityTest` → `GrowthMigrationsTest` → `JoinRequestConcurrencyTest`. Suite complète (`PARALLEL_WORKERS=2`) : 0 échec sur 5 passes, l'ordre fautif est rare |
| 1 bis | `test/support/schema_change_helper_test.rb` (test de reproduction écrit pour ce chantier) | rouge 3 fois sur 3, même message |
| 2 | `RoleHomesTest`, test « back home by the logo on a slow network… » (écrit pour ce chantier) : latence de 1 s par requête (`on_a_slow_network`), retour au logo vers une page déjà visitée, ouverture du menu | rouge 3 fois sur 3, **même message que la CI** (« found … which matched the selector but not all filters » : menu présent mais masqué). Sans latence : 0 échec sur 8 passes locales |
| 3 | `SessionResultTest`, test « « Recommencer » … le serveur répond lentement » (écrit pour ce chantier) | rouge 2 fois sur 2, **même message que le journal de `pilotage-equipe`**. Sans latence : 0 échec sur 8 passes locales |

## Cause racine (rapport de l'explorer)

**1 — Requêtes préparées périmées dans le pool.** `GrowthMigrationsTest` et `AddSchoolCodesMigrationRunTest` jouent de vraies migrations `down` puis `up` hors transaction. `remove_column` puis `add_column` replacent `schools.national_code`, `schools.school_code` et `teacher_profiles.referral_token` **en fin de table** (le schéma chargé les a dans l'ordre alphabétique de `db/schema.rb`). `SELECT "schools".* …` change donc de forme. Rails ne vide le cache de requêtes préparées que de la connexion qui a joué le DDL (`add_column`, `reset_column_information` → `active_connection&.clear_cache!`). Une autre connexion, ouverte par un test à plusieurs fils (`JoinCapacityTest`, `DoubleSubmissionTest`) et restée libre dans le pool, garde son `SELECT "schools".*` préparé. `JoinRequestConcurrencyTest` la reprend : la validation `belongs_to :school` de `create!` rejoue la requête **dans une transaction**, où Rails ne peut pas re-préparer (`postgresql/database_statements.rb:153`) et lève `PreparedStatementCacheExpired`. Fichiers : `test/db/growth_migrations_test.rb:16`, `test/db/add_school_codes_migration_test.rb:44`.
*Pourquoi aucun test ne l'a vu* : il faut trois tests dans un ordre précis dans le même processus ; la suite ne vérifie jamais l'état du pool après un test qui change le schéma.

**2 — Menu ouvert sur l'aperçu de Turbo.** Au retour par le logo vers un accueil déjà visité, Turbo dessine d'abord la copie en cache (aperçu, `html[data-turbo-preview]`), puis la page reçue. La garde `body[data-leaving]` disparaît dès l'aperçu : le test ouvrait le menu du compte sur l'aperçu, puis la page reçue le remplaçait par un menu fermé, et `find(… "Mon profil").click` (hors de la reprise de `with_account_menu`) ne trouvait plus qu'une entrée masquée. Fichier : `test/system/role_homes_test.rb`, `assert_navigation` (retour par le logo).
*Pourquoi aucun test ne l'a vu* : sans charge, la page reçue arrive avant que le test ouvre le menu.

**3 — Délai d'attente trop court pour deux allers-retours.** « Recommencer » est un formulaire Turbo : POST, redirection 303, puis la page de la session. `assert_current_path` attendait les 2 s par défaut de Capybara ; sous la suite système chargée (2 vCPU en CI, 20 à 45 de charge sur le poste partagé), les deux réponses dépassent 2 s. Fichier : `test/system/assessment/session_result_test.rb` (`play_nine_out_of_ten`, 42 avant correctif).
*Pourquoi aucun test ne l'a vu* : sans charge, les deux réponses tiennent en moins d'une seconde.

Aucune des trois causes n'est dans `app/` : le code de production est hors de cause, **aucune donnée n'est à réparer**, aucun ADR (cause non architecturale), aucune UDR (rien ne change à l'écran).

## Correctif

| # | Où | Quoi |
|---|---|---|
| 1 | `test/support/schema_change_helper.rb` (nouveau) ; les deux tests de migration | `changing_schema { … }` : tout DDL d'un test passe par ce bloc, qui vide ensuite le cache de requêtes préparées de **toutes** les connexions du pool |
| 2 | `test/system/role_homes_test.rb` | `back_home_by_logo` attend en plus `html:not([aria-busy])` : Turbo lève `aria-busy` à la fin de la visite, après la page reçue |
| 3 | `test/system/assessment/session_result_test.rb` | `assert_current_path … wait: RESTART_WAIT` (10 s) après « Recommencer » |
| 2, 3 | `test/support/slow_network_helper.rb` (nouveau) | `on_a_slow_network { … }` : latence Chrome de 1 s par requête, pour les tests de reproduction |

## Pour qui

Les développeurs et agents qui fusionnent vers `Develop` : un test rouge doit dire quelque chose.

## Pourquoi maintenant

Étape 0 de l'ordre V2 → V6 ; la V2 touche aux demandes en attente, donc au test n° 1 ; la CI GitHub est bloquée jusqu'au 2026-10-03.

## Hors périmètre

- Tout changement dans `app/` : aucune cause n'y vit.
- `enumerate_columns_in_select_statements` (Rails) : il éviterait le symptôme n° 1 en production lors d'un ajout de colonne à chaud, mais c'est un choix de configuration de production, pas un correctif de test → journal, dette.
- La reprise `with_account_menu` de `RoleHomesTest` : elle reste, même si la cause n° 2 la rend moins utile.
- Les autres tests système qui suivent un retour vers une page déjà visitée : non instables à ce jour → journal.

## Portes de sortie (lot unique, pas de `plan.md`)

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit avant toute ligne de correctif (graine 4 ; latence réseau)
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [x] Tests de reproduction écrits **avant** le correctif
- [x] Tests lancés et **rouges**, pour la bonne raison (messages identiques à ceux de la CI et des journaux)
- [x] Correctif appliqué dans la couche de la **cause** (les tests eux-mêmes)
- [x] Tests au vert ; boucles de rejeu (voir journal)
- [x] Cas symétrique : les autres tests de `RoleHomesTest` et `SessionResultTest`, et les tests de migration, verts
- [x] Données corrompues : aucune
- [x] `bin/rubocop`, `CI=1 PARALLEL_WORKERS=2 bin/rails test` (couverture 100 %), `COVERAGE=0 bin/rails test:system`, `bin/brakeman` : voir journal
- [x] Commit `fix(…)` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés
