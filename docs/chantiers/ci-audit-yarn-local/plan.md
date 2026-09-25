# Plan — Audit Yarn conditionnel en local

Un seul lot, sans ADR : le changement reste local à `config/ci.rb` et ne touche aucun contrat.

## Lot 1 — Condition sur l'étape d'audit

- `config/ci.rb` calcule `yarn_audit = ENV["CI"] || !system("git diff --quiet origin/Develop -- package.json yarn.lock")`.
- Si `yarn_audit` est vrai, l'audit tourne. Sinon, l'étape s'affiche comme « skipped locally » et réussit.
- Par sécurité, l'audit tourne si git ne peut pas comparer (`origin/Develop` absent) : `system` renvoie alors `false`.

**Preuve** : les quatre cas (local inchangé, `CI=true`, `package.json` modifié, git indisponible) donnent le résultat attendu, et la durée de `bin/ci` est mesurée après le changement.
