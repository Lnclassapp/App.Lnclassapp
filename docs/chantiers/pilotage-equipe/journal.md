# Journal — Pilotage de l'équipe

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Numéros ADR-0062 et UDR-0049 imposés par l'orchestrateur | Six chantiers parallèles : éviter les collisions de numéros | non |
| 2026-09-28 | Les neuf décisions par défaut du memo | Le porteur laisse les décisions par défaut ; chacune est marquée « à confirmer » | oui, ADR-0062 et UDR-0049 |
| 2026-09-28 | Helper nommé `Teams::DashboardsHelper` et non `School::DashboardHelper` | Un module `::School` de premier niveau aurait pu masquer des références `School::…` hors de leur namespace ; `Teams` existe déjà | non |
| 2026-09-28 | La couverture des établissements s'écrit en SQL constant (`COVERAGE`), seule l'année liée | Brakeman signalait l'interpolation de sous-requêtes construites par `to_sql` ; le SQL constant supprime l'alerte sans exception dans `brakeman.ignore` | non |
| 2026-09-28 | Le porteur valide les neuf décisions par défaut telles que proposées (« je valide les choix du pilotage ») : memo marqué « décidé par le porteur le 2026-09-28 », ADR-0062 et UDR-0049 (et les amendements des UDR-0006 et 0018) passent à « Accepté » | Décision du porteur relayée par l'orchestrateur | oui, ADR-0062 et UDR-0049 |
| 2026-09-28 | Aucun use case : deux queries et deux policies appelées par le contrôleur | Lecture pure (ADR-0006, ADR-0012) ; `UseCasePoliciesTest` ne concerne que `app/domain/use_cases`, rien à y ajouter | non |

## Ce qui a dérapé

- **Débordement horizontal à 390 px** : le test système l'a vu (`scrollWidth` 718 pour 375). Une grille CSS donne à ses enfants `min-width: auto` : la carte « Par DRENA » s'élargissait jusqu'à la largeur minimale du tableau, malgré son conteneur `overflow-x-auto`. Correctif : `grid-cols-1` (colonnes `minmax(0, 1fr)`) sur les grilles de la page.
- **Libellé de chiffre** : le nombre étant en `block`, Capybara lit « 2\nélèves » ; les tests système comparent par expression (`\s+`), la lecture d'écran reste « 2 élèves ».
- Trois tests existants supposaient « Pilotage » inactif : `test/routing/v1_routes_test.rb` (`NOT_IN_V1`), `test/helpers/navigation_helper_test.rb` (deux exemples d'entrée inactive, repris sur les destinations de la direction) et `test/system/role_homes_test.rb`.
- Une passe complète des tests système a vu échouer une fois `test/system/assessment/session_result_test.rb:42` (« Recommencer » : URL encore sur l'ancienne session). Hors périmètre, non touché par ce chantier ; vert trois fois de suite en isolé. Test instable à surveiller.
- Une première mesure de temps donnait 11 ms : `bin/rails runner` active le cache de requêtes, les appels répétés ne touchaient plus la base. Mesure refaite sans cache.

## Ce qu'on a appris sur la codebase

- Rien ne rattache un élève à une DRENA en dehors de sa classe : toute lecture territoriale passe par la classe principale active de l'année (ADR-0040, ADR-0041). Même chose pour l'enseignant par son établissement principal.
- Les factories donnent un auteur `team` créé « maintenant » à chaque contenu : un test d'inscrits de la période doit créer ses exercices sous un auteur ancien (`an_exercise` dans le test de la query).
- Tailwind v4 compile toute fraction (`w-7/20`) : 21 classes littérales suffisent pour des barres sans attribut `style`.

### Mesures du 2026-09-28

Base de test locale, données insérées en SQL puis annulées (transaction), `ANALYZE` fait, cache de requêtes désactivé.

| Volume | Pilotage national | Sous une DRENA | Recherche |
|---|---|---|---|
| 2 000 établissements, 10 000 classes, 10 000 élèves, 10 000 sessions | 0,17 à 0,27 s | 0,16 à 0,17 s | 0,12 s |
| mêmes établissements, 100 000 élèves, 100 000 sessions | 0,64 s | 0,35 s | 0,71 s |

Requêtes les plus lentes à 10 000 élèves : la couverture (12 ms), la répartition par niveau et les deux comptes par DRENA (10 ms chacune).

```
EXPLAIN ANALYZE SELECT COUNT(DISTINCT student_id) FROM exercise_sessions WHERE started_at >= now() - interval '7 days'
  Seq Scan on exercise_sessions  (actual time=0.017..21.872 rows=13329)  Rows Removed by Filter: 86671
  Execution Time: 23.976 ms
EXPLAIN ANALYZE SELECT COUNT(*) FROM users WHERE anonymized_at IS NULL AND created_at >= now() - interval '7 days'
  Seq Scan on users  (actual time=0.006..18.010 rows=2192)  Rows Removed by Filter: 97809
  Execution Time: 18.153 ms
```

Nombre de requêtes, vérifié par test et constant quel que soit le volume : 18 (national), 21 (sous une DRENA), 4 (recherche).

Budget (ADR-0051) : JavaScript 39,1 Ko gzip / 60 (aucun octet ajouté), CSS 12,6 Ko gzip / 30.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Index sur les dates (`exercise_sessions.started_at`, `completed_at`, `users.created_at`, `classroom_assignments.assigned_at`) et trigramme sur le nom | Inutiles aux volumes de la V1 ; seuil de reprise de 300 ms écrit dans l'ADR-0062 | `optimize` à ouvrir au seuil |
| Tendance (comparaison à la période précédente), courbes, export | Hors périmètre de la V1 du pilotage | V2 du pilotage, à la demande |
| Fiche de compte depuis la recherche | ID-21/22, V2 | V2 |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-09-28 (branche poussée, PR non ouverte) |
| **PR** | non ouverte (consigne de l'orchestrateur) |
| **ADR produits** | [ADR-0062](../../decisions/adr/0062-indicateurs-de-pilotage-lus-en-direct.md) |
| **UDR produits** | [UDR-0049](../../decisions/udr/0049-page-pilotage-de-l-equipe.md) ; amendements UDR-0006, UDR-0018 |
