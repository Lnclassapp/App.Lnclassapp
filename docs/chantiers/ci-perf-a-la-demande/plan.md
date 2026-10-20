# Plan — Perf des imports à la demande, une CI complète par PR

Deux leviers, deux lots, sans ADR : rien ne change de contrat ; la promotion vers `Staging` rejoue toujours la perf.

## Lot A — La perf des imports ne tourne en local que si la PR touche ses chemins

**Fichiers** : `config/ci.rb`, `test/guards/ci_plan_test.rb`, `docs/chantiers/ci-perf-a-la-demande/journal.md`.

- L'étape « Tests: Import performance » tourne si `CI` est posé (GitHub), **ou** si `git diff --quiet origin/Develop -- <chemins>` ne répond pas 0 : un écart, **ou** une comparaison impossible (fail-safe, comme l'audit Yarn).
- Sinon elle réussit en disant qu'elle est sautée, et pourquoi, sans lancer Rails.
- Chemins : `app/domain`, `app/infrastructure`, `app/jobs`, `db`, `lib`, `Gemfile.lock`, `config/database.yml`, `config/ci.rb`, `script/ci`, `test/performance`, `test/test_helper.rb`. Une liste large : on préfère jouer la perf pour rien que la manquer.
- La commande garde les fichiers de perf (la garde « les budgets d'écran restent hors de `bin/ci` » les y cherche) ; la condition peut vivre dans la commande shell.
- Garde : un test vérifie que l'étape joue toujours sous `CI`, que ses chemins couvrent au moins `app/domain`, `app/infrastructure`, `app/jobs`, `db`, `test/performance`, et que l'échec de la comparaison la fait jouer.

**Done quand** : sur `feature/renommage-fiche-revision` (#237), la condition saute la perf (< 1 s) ; sur un arbre qui touche `app/infrastructure`, elle la joue ; sous `CI=true`, elle la joue ; sans `origin/Develop`, elle la joue. Chiffres dans le journal.

## Lot B — Une CI complète par PR, sur son head final

**Fichiers** : `CLAUDE.md`, `docs/workflows/README.md`, `.claude/agents/executant-lot.md`, `.claude/agents/verificateur-ci.md`, `docs/chantiers/ci-perf-a-la-demande/journal.md`.

- Règle : entre deux lots, on prouve par les tests des fichiers touchés et `bin/system-changed` (tests système liés aux fichiers changés) ; `bin/ci-quiet` se joue **une seule fois par PR**, sur le head final, après les revues et leurs corrections. Une CI rouge corrigée se rejoue, bien sûr.
- `CLAUDE.md` (Sobriété de tokens) en porte le raccourci ; `docs/workflows/README.md` la règle complète, là où il parle de la preuve par `bin/ci`.
- `executant-lot` lance `bin/system-changed` en plus des tests touchés quand son lot touche une vue, un contrôleur, un composant, du CSS ou du Stimulus.
- `verificateur-ci` : rien à changer dans sa méthode ; seulement, s'il le faut, la mention qu'il est appelé sur le head final.

**Done quand** : les quatre fichiers disent la même règle, sans contradiction avec `docs/guide/onboarding.md` §4.
