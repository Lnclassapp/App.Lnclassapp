# Plan — Deux outils de CI en retard sur leurs règles

Un seul lot, sans ADR : les deux outils rejoignent les règles déjà décidées (ADR-0114, ADR-0069 §9).

## Lot 1 — Plafond à 61 Ko et durées lues en entier

- `bin/check-asset-budget` : 61 Ko pour `application.js`. `test/javascript_bundle_test.rb` vérifie que le script porte le même plafond que lui.
- `script/ci/timing_log.rb` : la lecture des journaux `-v`, sortie de `record_timings` pour être testée. Une ligne « Classe#test_… = » suivie d'une sortie quelconque ouvre le test ; la ligne « 1.23 s = . » le ferme.
- `test/guards/system_budget_test.rb` : un journal avec Puma, une ligne entière, une sortie [PERF] et un préfixe GitHub.

**Preuve** : les deux nouveaux tests échouent sur l'ancien code (plafond 60, première durée perdue) et passent après.
