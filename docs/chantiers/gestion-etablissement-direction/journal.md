# Journal — La direction gère son établissement

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-01 | Numéros ADR-0071 et UDR-0056 | ADR-0069 et 0070 sont pris sur des branches ouvertes (`perf/ci-quota`, `ccr-9b7287af-3kx7cj`) ; ADR-0065 à 0067 et UDR-0052, 0053 d'`espace-direction` sont en collision avec `Develop` | — |
| 2026-10-01 | Deux policies au lieu d'élargir `ManageSchoolPolicy` | Elle ouvre aussi l'import, les DRENA et la validation des comptes en attente (Q1) ; et l'équipe ne retire pas d'enseignant (grill 9) | ADR-0071 §4.1 |
| 2026-10-01 | Table `teacher_school_departures` | Sans trace du retrait, le code reprend l'enseignant aussitôt (grill 5) | ADR-0071 §4.4 |
| 2026-10-01 | Adaptateurs des nouvelles méthodes de port au Lot 0 | Leçon du challenge 1 d'`espace-direction` : `port_contracts_test` casse sinon | — |
| 2026-10-01 | Bloc « Classes par niveau » déplacé en partiel partagé au Lot 0 | La direction et l'équipe ont le même gabarit ; deux vues de l'équipe (`update`, `deactivate`) le rendaient aussi, trouvées par la recherche des appelants | UDR-0056 §3.2 |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

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


## Lot 0 — Socle (2026-10-01)

**Statut : fusionné** dans `feature/gestion-etablissement-direction` (commit `4990a645`). Table `teacher_school_departures`, entité, trois policies, port de départ et trois méthodes de port **avec leurs adaptateurs**, `OwnSchoolQuery`, routes de l'UDR-0056 §3.0, troisième destination, page « Établissement » en lecture, bloc « Classes par niveau » déplacé en `shared/_level_classrooms` (les tests de la fiche de l'équipe passent sans modification), fabrique `create_teacher_departure`.

Portes (agent, revérifiées par le porteur du chantier sur 248 tests ciblés et un chargement du schéma dans une base vierge) : rubocop 0 offense ; 2 625 tests unitaires, couverture 100 % ; 291 tests système ; migrate / rollback / migrate. **Deux étapes de `bin/ci` rouges, étrangères au lot** : `bin/brakeman` (`--ensure-latest` refuse la 8.0.6 depuis la sortie de la 8.1.0 ; 0 alerte sans l'option) ; `heavy_screens_budget_test` « pilotage 7 j » (p95 339 ms pour 300 ms, déjà rouge à 324 ms sur le commit de base : lenteur de la machine locale).

Écarts : trois tests existants modifiés au minimum (`school_admin_routes_test` : liste fermée des cinq écritures ; `student_work_test` : trois entrées ; `models_test` : 37 modèles) ; `db/schema.rb` complété à la main (le dump local PG16 réécrivait toutes les contraintes CHECK).

Corrections de documents qui en découlent : GD-02 (une direction sans établissement reçoit 403, comme DS-11) ; déclaration des routes de l'UDR-0056 §3.0 (le `resource :school` imbriqué ne donnait pas les noms du tableau) ; clés `on_delete: :restrict` dans l'exemple de migration de l'ADR-0071 ; `JoinRequestsQuery#status_for` rend un `Status` de tout état (le Lot D ne passe à la policy qu'une demande `pending`) ; dossiers de worktree courts pour la vague 2.
