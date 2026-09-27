# Journal — Une seule exécution des gardes dans `bin/ci`

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-26 | Garder les étapes « Guard: » et retirer les gardes de `bin/rails test`, plutôt que l'inverse | Les étapes séparées échouent en quelques dixièmes de seconde, avant Rubocop et les audits : c'est l'ordre « du moins cher au plus cher » de `config/ci.rb` | Non |
| 2026-09-26 | Exclure seulement dans `bin/ci`, pas dans la configuration de test | `bin/rails test` lancé seul, en local, garde les gardes | Non |

## Mesure après

| Métrique | Contexte / volume | Avant | Après | Comment mesurée |
|---|---|---|---|---|
| Tests des gardes dans « Tests: Rails » | `Develop` (7623dc53) | 6 | 0 | `bin/rails test -v` avec la variable de `config/ci.rb` |
| Suite Rails | Même base | verte | 960 tests verts, couverture 100 % en lignes et en branches | `bin/rails test` avec la variable |

## Ce qui a dérapé

- Rien.

## Ce qu'on a appris sur la codebase

- Le lanceur de tests de Rails lit `DEFAULT_TEST_EXCLUDE` ; sa valeur par défaut est `test/{system,dummy,fixtures}/**/*_test.rb`. La remplacer oblige à reprendre ces trois dossiers.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-09-26 |
| **PR** | [#18](https://github.com/Lnclassapp/App.Lnclassapp/pull/18) |
| **ADR produits** | aucun |
| **UDR produits** | aucun |
