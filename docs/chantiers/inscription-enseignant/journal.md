# Journal — Amélioration du parcours d'inscription des enseignants

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-07 | Lot 0 élargi : 5 fichiers (faux dépôts des tests de use case, `models_test`, deux seeds) puis l'adaptateur des liens d'invitation et `registration_repository_test` | `joined_via` NOT NULL sans défaut et la nouvelle signature de `create_teacher` cassaient ces appelants ; `test/architecture/port_contracts_test.rb` exige un adaptateur pour chaque port | Non (plan.md) |
| 2026-10-07 | Lot C : le frame `schools` de l'écran d'attente est servi par l'écran lui-même, pas par `/drenas/:id/schools` | `School::DrenaSchoolsController` écrit le préfixe `teacher_registration` en dur ; le local `scope` du Lot 0 ne suffisait pas | À régler au Lot D (paramètre `scope` du contrôleur), sinon amender l'ADR-0082 §4.5 |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Le Lot 0 s'est arrêté deux fois sur des fichiers hors liste : l'exploration de la phase 2 n'avait pas cherché tous les appelants de `create_teacher` ni les tests d'architecture. Parade pour les prochains plans : `grep` de chaque méthode de port modifiée et lecture de `test/architecture/` avant d'écrire le Lot 0.
- Le local `scope` du frame DRENA a été posé dans la vue sans vérifier que le contrôleur qui la rend seul (`School::DrenaSchoolsController`) pouvait le recevoir.
- Lot D : `test/system/teams/blog_management_test.rb:71` (hors chantier) a échoué une fois dans `bin/rails test:system` complet (texte d'image tronqué : « Une élève révise à ») et passe seul à la relance : test instable sous charge, à surveiller.
- Lot D : deux retraits ont laissé des appelants hors liste (`test/system/teams/school_code_test.rb`, `test/routing/school_admin_routes_test.rb`) : le `grep` de la phase 3 doit aussi couvrir les chemins d'URL (`/school-admin/school/link`) et les tests de `test/routing/`, pas seulement les helpers et les constantes.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `test/architecture/port_contracts_test.rb` exige un adaptateur pour chaque port : un port ne peut pas être gelé seul au Lot 0.
- `test/db/growth_migrations_test.rb` rejoue les migrations de `LATER` déjà appliquées : une migration qui touche ces tables doit être idempotente (`if_not_exists`, reprise limitée aux lignes non encore reprises).
- `bin/rails db:schema:dump` avec la version locale de PostgreSQL réécrit une cinquantaine de CHECK existants : `db/schema.rb` a été édité à la main pour ne garder que l'ajout.
- `config/database.yml` donne une base par worktree : des lots parallèles peuvent lancer leurs tests en même temps.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Barre latérale d'un enseignant sans établissement : « Content missing » à 1280 px (le frame différé est redirigé vers l'écran d'attente) | Antérieur au chantier, relevé par le Lot C | bugfix à ouvrir |
| Code d'établissement et « Régénérer le code » encore présents pour la direction | Périmètre (Q8) | `inscription-direction-sans-code` |
| `SchoolRepositoryPort#find_by_national_code` et son adaptateur : plus d'appelant après la suppression de `RegisterPendingTeacher` | Retirer une méthode de port sort du Lot D ; l'entité `NationalCode` sert encore à l'import | refactor à ouvrir (ou `inscription-direction-sans-code`) |
| Code de classe des élèves | Périmètre (Q20) | `inscription-eleve-sans-code` (branche ouverte) |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
