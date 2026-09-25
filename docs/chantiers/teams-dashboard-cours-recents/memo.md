# Memo — Le tableau de bord Team plante en 500

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-09-23 |
| **Branche** | `fix/teams-dashboard-cours-recents` |
| **Programme** | — |

---

## Symptôme

Un membre Team connecté qui ouvre `/teams/dashboard` obtient une page d'erreur 500 au lieu du tableau de bord.

Log de développement (2026-09-23 14:38:05) :

```
Started GET "/teams/dashboard"
Processing by Teams::DashboardController#index as HTML
Completed 500 Internal Server Error in 30ms
NoMethodError (undefined method 'find_courses' for an instance of Repositories::Catalog::CourseRepository):
app/domain/use_cases/identity/get_teams_dashboard.rb:40:in 'UseCases::Identity::GetTeamsDashboard#execute'
app/controllers/teams/dashboard_controller.rb:34:in 'Teams::DashboardController#index'
```

## Reproduction

1. `bin/dev`, environnement de développement.
2. Se connecter en tant que membre Team (utilisateur `id = 1`).
3. Ouvrir `/teams/dashboard`.
4. → 500 `NoMethodError` au lieu du tableau de bord.

Reproduit par l'utilisateur, trace consignée dans `log/development.log` (deux occurrences : lignes ~2044 et ~22851).

## Portée

- **Depuis quand** : le port `Ports::Catalog::CourseRepositoryPort` expose `find_all` ; l'adaptateur `Repositories::Catalog::CourseRepository` n'a jamais exposé `find_courses` depuis sa refonte hexagonale (`cde1013`, nettoyée par `2449373`). Le use case, plus ancien (`72166bd`), appelle encore l'ancien nom.
- **Acteurs touchés** : `Team` uniquement (seul acteur qui passe par `Teams::DashboardController#index`). `/teams/setup` n'est pas touché (`get_setup_data` n'appelle pas le dépôt de cours).
- **Multi-appartenance** : sans objet, le tableau de bord Team n'est pas filtré par élève, classe ou école.
- **Données corrompues** : **non**. Chemin en lecture seule.

## Comportement attendu — source

`Ports::Catalog::CourseRepositoryPort#find_all` (`app/domain/ports/catalog/course_repository_port.rb:14`) est le contrat de lecture de la liste des cours. Le contrat de sortie documenté dans l'en-tête de `GetTeamsDashboard` promet `recent_courses: Array`, affiché par `app/views/teams/dashboard/_tab_academy.html.erb:57`.

## Hors périmètre

- La façade legacy `Repositories::CatalogRepository#find_courses` (`app/infrastructure/repositories/catalog_repository.rb:71`) délègue elle aussi à un `find_courses` inexistant → noté au journal, chantier de suivi.
- L'ordre « récents » : `find_all` n'impose pas de tri par date. On garde le comportement d'origine (les 10 premiers), sans introduire de tri → noté au journal.

## Portes de sortie (lot unique, pas de `plan.md`)

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [x] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [x] Test au vert · suite du contexte borné au vert
- [x] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [x] Données déjà corrompues : réparées, ou dette explicitement notée au journal
- [x] Challenger a rejoué les étapes de reproduction dans l'application *(par requête HTTP authentifiée en test d'intégration : extension Chrome non connectée, voir journal)*
- [x] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés

## Lot 0 — contrat d'exécution

1. Écrire `test/domain/use_cases/identity/get_teams_dashboard_test.rb` : `GetTeamsDashboard#execute` avec un faux dépôt de cours qui n'implémente **que** le port (`find_all`) → doit renvoyer `recent_courses` limité à 10.
2. Le lancer : il doit échouer sur `NoMethodError: undefined method 'find_courses'`.
3. Corriger `app/domain/use_cases/identity/get_teams_dashboard.rb:40` : appeler `find_all` (le contrat du port).
4. Relancer : vert. Puis `bin/rails test test/domain/use_cases/identity`.
5. Rejouer `/teams/dashboard` dans l'app (200) et vérifier le voisin `/teams/setup`.
