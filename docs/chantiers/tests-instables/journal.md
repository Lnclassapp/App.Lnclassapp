# Journal — Trois tests instables sous CI bloquée

> Rempli pendant le chantier (2026-09-28).

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Corriger dans les tests, pas dans `app/` | Les trois causes vivent dans les tests : un DDL de test, une attente trop tôt, un délai trop court. Le code de production n'est jamais en faute | Non |
| 2026-09-28 | Vider le cache de requêtes préparées de **toutes** les connexions du pool après un DDL de test (`changing_schema`), plutôt que `enumerate_columns_in_select_statements` | Le réglage Rails changerait le SQL de production pour masquer un effet de test ; le bloc est explicite là où le schéma bouge | Non |
| 2026-09-28 | Attendre la fin de la visite Turbo (`html[aria-busy]` levé) plutôt que d'ajouter une reprise de plus autour de « Mon profil » | La reprise de `with_account_menu` traitait le symptôme ; l'aperçu de Turbo est la cause | Non |
| 2026-09-28 | Reproduire les deux instabilités système par une latence Chrome (`on_a_slow_network`, 1 s par requête), et garder ces tests | La charge ne se commande pas ; la latence si. Elle reproduit **les messages exacts** de la CI et du journal de `pilotage-equipe` | Non |

## Preuves

### Rouge avant le correctif

| Test | Commande | Résultat |
|---|---|---|
| `JoinRequestConcurrencyTest` | 5 fichiers (concurrence, 2 tests de migration, `JoinCapacityTest`, `DoubleSubmissionTest`), `PARALLEL_WORKERS=1`, graines 1 à 25 | rouge à la graine 4 seulement, puis 3 fois sur 3 à la graine 4 : `PreparedStatementCacheExpired: cached plan must not change result type` |
| `SchemaChangeHelperTest` (nouveau) | `bin/rails test test/support/schema_change_helper_test.rb`, bloc sans effet | rouge 3 fois sur 3, même message |
| `RoleHomesTest`, « … slow network … » (nouveau) | sans l'attente de `aria-busy` | rouge 3 fois sur 3 : `expected to find visible css "#account-menu a[role=menuitem][href='/profile']" … Also found "", which matched the selector but not all filters` (message du run 151) |
| `SessionResultTest`, « … lentement » (nouveau) | sans `wait: RESTART_WAIT` | rouge 2 fois sur 2 : `expected "/sessions/…/result" to match /\A\/sessions\/(?!…)[^\/]+\z/` |

Le log du job en échec du run 151 (essai 3, `system:4/6`, graine 28331) a été relu via l'API GitHub : c'est lui qui désigne la ligne `find(… "Mon profil").click`, hors de la reprise de `with_account_menu`.

### Vert après le correctif

| Boucle | Runs | Échecs |
|---|---:|---:|
| Les 5 fichiers de la reproduction n° 1, graines 1 à 40 (dont la graine 4), `PARALLEL_WORKERS=1` | 40 | 0 |
| `schema_change_helper_test.rb` + `join_request_concurrency_test.rb` | 30 | 0 |
| `role_homes_test.rb` + `session_result_test.rb` (11 tests par passe, dont les deux tests sous latence), seule sur la base | 30 | 0 |
| Suite unitaire complète `COVERAGE=0 PARALLEL_WORKERS=2` (5 passes avant le correctif, 5 pendant) | 10 | 0 |

### Portes

| Porte | Résultat |
|---|---|
| `bin/rubocop` | 982 fichiers, 0 offense |
| `CI=1 PARALLEL_WORKERS=2 bin/rails test` | 2 332 runs, 0 échec, 0 erreur (7 `skip` antérieurs) ; lignes 8 427 / 8 427 (100 %), branches 2 057 / 2 057 (100 %) |
| `COVERAGE=0 bin/rails test:system` | 196 runs, 0 échec, 0 erreur, 0 `skip` (3 min 09) |
| `bin/brakeman -q --no-pager` | 0 avertissement |

## Ce qui a dérapé

- **Premier test de reproduction du n° 1 vert du premier coup.** Il lisait l'école depuis un seul fil : depuis Rails 7.2, une requête hors bail rend sa connexion au pool, et le fil reprenait **la connexion même** qui avait joué le DDL (déjà vidée). Réécrit avec deux fils qui tiennent chacun une connexion en même temps : rouge. Leçon : un test de pool doit forcer plusieurs connexions simultanées.
- **Une première boucle système a eu 2 rouges sur 30, par ma faute.** `UniqueViolation` sur « DRENA 1 » et « Matière 7 » dans le `setup` : je rejouais en même temps, sur **la même base de test** du worktree (moins de 50 tests : pas de base par worker), les tests non transactionnels de la reproduction n° 1, qui valident leurs lignes avant de les effacer. Les deux rouges tombent exactement dans la fenêtre de cette boucle (horodatages des logs). Boucle système rejouée seule : 30 sur 30 verts. Leçon : ne jamais faire tourner deux commandes de test en parallèle sur la même base.
- **`delete_network_conditions` casse chromedriver** (`cannot determine loading status … bad inspector message`) à la visite suivante. On remet une latence nulle et un débit illimité (`throughput: -1`) à la place.
- **La suite complète ne reproduit pas le n° 1** en 5 passes : l'ordre fautif (test à plusieurs fils → test de migration → test de concurrence, dans le même processus) est rare. Seule la boucle de graines sur les fichiers en cause l'a trouvé.
- **Les boucles système locales sans latence ne reproduisent ni le n° 2 ni le n° 3** (0 sur 8 passes, sous la charge de la suite unitaire en parallèle). Sans la lecture du log de la CI et le mécanisme d'aperçu de Turbo, le n° 2 aurait été « corrigé » par une reprise de plus.

## Ce qu'on a appris sur la codebase

- Rails ne vide les requêtes préparées que de la connexion qui joue le DDL ; hors transaction il re-prépare seul, **dans** une transaction il lève `PreparedStatementCacheExpired`. Tout test qui migre doit passer par `changing_schema`.
- `remove_column` + `add_column` ne rendent pas le schéma identique : la colonne revient en fin de table. Après `GrowthMigrationsTest`, la base du worker n'a plus l'ordre de `db/schema.rb` jusqu'au prochain chargement du schéma.
- Turbo dessine un aperçu depuis son cache au retour vers une page déjà visitée (`html[data-turbo-preview]`), puis la page reçue ; `html[aria-busy]` couvre toute la visite. Une garde « le nouveau `body` est dessiné » ne suffit pas.
- Les attentes par défaut de Capybara (2 s) ne tiennent pas deux allers-retours sous la suite système chargée ; les étapes lourdes du dépôt ont déjà leurs constantes (`SIGN_IN_WAIT`, `IMPORT_WAIT`, `REPORT_WAIT`).

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| D'autres tests système qui reviennent vers une page déjà visitée peuvent agir sur l'aperçu de Turbo | Aucun n'est instable à ce jour ; les auditer tous élargirait le correctif | à ouvrir si l'un d'eux échoue (`bugfix`), avec `on_a_slow_network` pour reproduire |
| La reprise `with_account_menu` de `RoleHomesTest` est probablement devenue inutile | La retirer est un refactoring de test, hors d'un bugfix | aucun, à retirer au prochain passage sur ce fichier |
| En production, un ajout de colonne à chaud peut lever `PreparedStatementCacheExpired` dans une transaction en cours (même mécanisme que le n° 1) | Hors périmètre : rien ne l'a observé ; la parade (`enumerate_columns_in_select_statements`, ou déploiement qui recycle les connexions) est un choix d'exploitation | à décider par ADR si le symptôme apparaît en production |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-09-28 (PR ouverte, non fusionnée) |
| **PR** | [#85](https://github.com/Lnclassapp/App.Lnclassapp/pull/85) |
| **ADR produits** | aucun (cause non architecturale) |
| **UDR produits** | aucune (rien ne change à l'écran) |
