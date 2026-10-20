# Plan d'exécution — Accélération du flux

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot 0 — Règles (memo, plan, conventions §2 et §7)       ← ce commit
  ↓
  ├─► Lot A  numéros posés à la fusion (build_index --number)   ┐
  ├─► Lot B  garde des migrations en deux temps                 ├─ en parallèle
  └─► Lot C  plan de retour arrière                             ┘
  ↓
Clôture — build_index, journal.md, ligne de docs/chantiers/README.md
```

---

## Lot 0 — Règles

- **Couche**       : documentation
- **Fichiers**     : `docs/chantiers/acceleration-du-flux/memo.md`
                     `docs/chantiers/acceleration-du-flux/plan.md`
                     `docs/guide/conventions.md` *(fichier partagé : §2 numérotation, §7 migrations en deux temps)*
- **Dépend de**    : —
- **Test associé** : —
- **Done quand**   : les deux règles sont écrites dans les conventions, et les lots A, B et C peuvent démarrer sans toucher le même fichier

---

## Lot A — Un numéro d'ADR et d'UDR posé à la fusion

- **Couche**       : outillage
- **Fichiers**     : `script/docs/build_index`
                     `test/config/build_index_test.rb`
                     `.claude/skills/feature/SKILL.md`
                     `.claude/skills/bugfix/SKILL.md`
                     `.claude/skills/refactor/SKILL.md`
                     `.claude/skills/optimize/SKILL.md`
- **Dépend de**    : Lot 0
- **Test associé** : `test/config/build_index_test.rb` (dans un dossier temporaire, au style de `test/config/ci_scope_test.rb`)
  - deux décisions `XXXX-` d'un même run reçoivent deux numéros libres, distincts et consécutifs ;
  - `git mv` vers `NNNN-<slug>.md`, et les références `ADR-XXXX-<slug>`, `UDR-XXXX-<slug>` et les liens `XXXX-<slug>.md` sont réécrits dans `docs/`, `app/`, `config/`, `db/`, `test/`, `CLAUDE.md` et `.claude/` ;
  - une décision déjà numérotée ne bouge pas ;
  - `--check` refuse un `XXXX-` sur `Develop`, `Staging` et `main`, et l'accepte sur une branche de chantier.
- **Done quand**   : un chantier crée `docs/decisions/adr/XXXX-mon-choix.md`, lance `script/docs/build_index --number`, et obtient `NNNN-mon-choix.md`, toutes ses références réécrites et l'index à jour. Les skills ne demandent plus de chercher « le dernier numéro ».

---

## Lot B — Garde des migrations en deux temps

- **Couche**       : outillage (test de garde)
- **Fichiers**     : `test/guards/migration_rules_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : le fichier lui-même. La règle se vérifie sur `db/migrate/` réel, et ses cas sur un dépôt git temporaire, comme `run_perf` dans `test/guards/ci_plan_test.rb` :
  - ajout ou recopie, puis suppression de la même colonne dans la même livraison → refus ;
  - suppression seule → accepté ;
  - commentaire `# migration-en-deux-temps: <raison>` → accepté ;
  - git ne peut pas comparer → toutes les migrations sont contrôlées.
  - Une livraison = les migrations absentes de `origin/main`. Les opérations contrôlées : `remove_column`, `remove_columns`, `drop_table`, `remove_reference`, `rename_column`, `rename_table`.
- **Done quand**   : une branche qui refait la #268 (recopie de `material_id` et `remove_column` dans la même livraison) est refusée par `bin/rails test test/guards/migration_rules_test.rb`, avec un message qui cite la règle de `docs/guide/conventions.md` §7

---

## Lot C — Plan de retour arrière

- **Couche**       : documentation
- **Fichiers**     : `docs/guide/retour-arriere.md`
- **Dépend de**    : Lot 0
- **Test associé** : —
- **Done quand**   : le guide dit :
  - comment revenir à l'image précédente ;
  - quand c'est sans risque (migrations seulement additives) ;
  - quand c'est impossible (suppression déjà jouée, d'où le lot B) ;
  - que faire quand Railway met les déploiements en pause.
  
  Ce qui est propre à Railway s'appuie sur `railway.json` et ADR-0052. Toute commande non vérifiée est marquée « à vérifier par le porteur ».

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `docs/guide/conventions.md` | Lot 0 |
| `script/docs/build_index`, `.claude/skills/*/SKILL.md` | Lot A |
| `test/guards/migration_rules_test.rb` | Lot B |
| `docs/guide/retour-arriere.md` | Lot C |
| `docs/chantiers/acceleration-du-flux/journal.md`, `docs/chantiers/README.md` | Clôture |

## Portes de sortie

- [x] Les lots A, B et C sont `Done`
- [x] Un rôle distinct de l'auteur a **exécuté** `build_index --number` sur un ADR `XXXX-`, et la garde B sur une branche qui refait la #268
- [x] `bin/ci-quiet` (niveau pr) vert, ligne de preuve dans la PR
- [x] `silent-failure-hunter` et `pr-test-analyzer` une fois sur le diff final
- [x] `script/docs/build_index` relancé, `journal.md` complété, ligne du chantier ajoutée à `docs/chantiers/README.md`
