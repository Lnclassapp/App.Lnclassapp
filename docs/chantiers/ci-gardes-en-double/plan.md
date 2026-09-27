# Plan — Une seule exécution des gardes dans `bin/ci`

Un seul lot, sans ADR : le changement reste local à `config/ci.rb` et ne touche aucun contrat.

## Lot 1 — Exclure les gardes de l'étape « Tests: Rails »

- `config/ci.rb` lance `bin/rails test` avec `DEFAULT_TEST_EXCLUDE`, la variable que lit le lanceur de tests de Rails. Sa valeur reprend l'exclusion par défaut de Rails (`system`, `dummy`, `fixtures`) et y ajoute `test/guards/` et `test/domain/domain_purity_test.rb`.
- Les deux étapes « Guard: » restent en tête de `bin/ci`, inchangées : elles échouent vite, sans démarrer Rails.

**Preuve** : avec la variable, `bin/rails test -v` ne lance aucun test des gardes, la suite reste verte et la couverture reste à 100 % en lignes et en branches. Sans la variable, `bin/rails test` lance toujours les 6 tests des gardes.
