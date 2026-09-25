# Journal — Le tableau de bord Team plante en 500

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-23 | Garder le test contrôleur `test/controllers/teams/dashboard_controller_test.rb` en plus du test domaine | Couvre la chaîne complète (contrôleur → use case → vrai adaptateur → vue) et le voisin `/teams/setup` | non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Rejeu navigateur impossible (extension Chrome non connectée). Rejeu fait par `ActionDispatch::IntegrationTest` : connexion Team réelle puis `GET /teams/dashboard`. Sans le correctif → même `NoMethodError` que le log ; avec → 200.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

### Correctif (2026-09-23)

- Test domaine `test/domain/use_cases/identity/get_teams_dashboard_test.rb` : rouge sur `NoMethodError: undefined method 'find_courses'`, vert après correctif.
- Correctif : `get_teams_dashboard.rb:40` appelle `find_all`, le contrat du port. Même résultat qu'avant (10 premiers cours publiés).
- Trou de test comblé : domaine (faux dépôt limité au port) + contrôleur (chaîne complète).
- Effets de bord écartés : `/teams/setup` vert, suite `identity` + port `catalog` + `UsersController` verts (12 runs). Aucune donnée écrite.

### Rapport root cause (2026-09-23)

**Chaîne d'appels** : `GET /teams/dashboard` → `Teams::DashboardController#index` (`app/controllers/teams/dashboard_controller.rb:34`) → `UseCases::Identity::GetTeamsDashboard#execute` → `@course_repo.find_courses` (`app/domain/use_cases/identity/get_teams_dashboard.rb:40`) → `Repositories::Catalog::CourseRepository` ne répond pas → `NoMethodError`.

**Cause** : `app/domain/use_cases/identity/get_teams_dashboard.rb:40`. Le use case appelle une méthode qui ne fait pas partie du port qu'il reçoit : `Ports::Catalog::CourseRepositoryPort` ne déclare que `find_all`. Le renommage vers le contrat du port (`cde1013` / `2449373`) n'a pas été propagé à cet appelant.

**Reformulation sans les mots du symptôme** : le use case dépend d'un nom hors contrat du port, que l'adaptateur n'a aucune obligation de fournir.

**Pourquoi aucun test ne l'a vu** : `GetTeamsDashboard` n'a aucun test (ni domaine, ni contrôleur, ni intégration) — `test/domain/use_cases/identity/` ne contient que `manage_school_test.rb`. Le test de reproduction se place donc au niveau domaine, avec un faux dépôt qui n'implémente que le port.

### Autres constats

- `Repositories::CatalogRepository#find_courses` (`app/infrastructure/repositories/catalog_repository.rb:71`) délègue au même nom inexistant. Même famille de bug, hors périmètre.
- `find_all` ne trie pas par date : `recent_courses` n'est « récent » que de nom.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Façade `CatalogRepository#find_courses` cassée de la même façon | Un bug, un correctif | à ouvrir |
| `recent_courses` sans tri par date | Changement de comportement, pas une régression | à ouvrir |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-09-23 |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
