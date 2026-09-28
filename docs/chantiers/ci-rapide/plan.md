# Plan d'exécution — La CI GitHub dure près de 10 minutes

> Cycle optimisation : **un lot = un levier = un chiffre**, dans l'ordre gain/risque décroissant. Un levier sans gain mesuré est annulé ([`optimisation.md`](../../workflows/optimisation.md)).
> Mesures : [`memo.md`](memo.md) (avant) et [`journal.md`](journal.md) (après). Décision d'architecture : [ADR-0064](../../decisions/adr/0064-ci-parallele-par-groupes-de-bin-ci.md).

## Graphe

```
Lot 0 — Groupes dans config/ci.rb + garde (socle, séquentiel)
  ↓
  ├─► Lot A  Jobs parallèles (checks, tests en matrice, job final « ci »)
  │     ↓
  │     ├─► Lot B  Parts équilibrées sur les durées réelles (6 système, 3 perf)
  │     └─► Lot C  Seeds hors du job unitaire
  ├─► Lot D  Concurrency : annuler le run obsolète d'une PR
  ├─► Lot E  PR « docs seulement » : jobs sautés, « ci » vert
  └─► Lot F  Petits leviers d'installation (libpq-dev, cache Rubocop, santé PostgreSQL)
Leviers évalués et annulés : G (unitaire découpé + fusion de couverture), H (4 workers), I (caches yarn/bootsnap/assets), J (tests unitaires lents)
```

---

## Lot 0 — Socle : groupes et garde

- **Couche**       : outillage CI
- **Fichiers**     : `config/ci.rb` · `script/ci/plan.rb` · `bin/setup` (`--skip-db`) · `test/guards/ci_plan_test.rb`
- **Dépend de**    : —
- **Test associé** : `test/guards/ci_plan_test.rb` (8 tests : les jobs du workflow redonnent `bin/ci`, chaque part une fois, chaque fichier une fois, groupe inconnu refusé)
- **Done quand**   : `bin/ci` sans `CI_GROUP` joue les mêmes étapes, dans le même ordre, qu'avant ; `CI_GROUP=lnit bin/ci` échoue

## Lot A — Jobs parallèles

- **Couche**       : workflow
- **Fichiers**     : `.github/workflows/ci.yml` · `.github/actions/setup/action.yml`
- **Dépend de**    : Lot 0
- **Test associé** : le run GitHub de la PR #53, et les erreurs volontaires de la branche jetable
- **Done quand**   : horloge d'un run de PR < 3 min ; une offense Rubocop, une couverture < 100 % et un test système cassé rendent `ci` rouge

## Lot B — Parts équilibrées

- **Fichiers**     : `script/ci/test_timings.yml` · `script/ci/record_timings`
- **Dépend de**    : Lot A (les durées viennent d'un run GitHub en `-v`)
- **Test associé** : `test/guards/ci_plan_test.rb` (découpage déterministe, fichier sans durée = médiane)
- **Done quand**   : l'écart entre la part système la plus longue et la plus courte est < 20 s

## Lot C — Seeds hors du job unitaire

- **Fichiers**     : `.github/workflows/ci.yml`
- **Dépend de**    : Lot B
- **Done quand**   : le job unitaire perd la durée des seeds (2 à 4 s) sur le chemin critique

## Lots D, E, F

- **D** `concurrency` avec `cancel-in-progress` pour les PR seulement : un push rend le run précédent inutile ; les pushes sur `Develop`, `Staging`, `main` vont toujours au bout.
- **E** job `changes` + job final `ci` : une PR docs seule donne `ci` vert en moins de 30 s, sans workflow ignoré (un workflow ignoré ne rapporte aucun statut).
- **F** `libpq-dev` installé seulement s'il manque (il est dans l'image : − 7 s), cache `tmp/rubocop`, santé PostgreSQL vérifiée chaque seconde.

## Leviers évalués et annulés

| Levier | Mesure | Décision |
|---|---|---|
| **G** Découper les tests unitaires, fusionner la couverture dans un job final | Suite unitaire : 64 à 67 s de tests sur GitHub. Un job de fusion ajoute son plancher (≈ 30 s) **après** les parts | Annulé : l'horloge ne baisse pas. À rouvrir si le job unitaire dépasse seul de 30 s les autres |
| **H** `PARALLEL_WORKERS=4` sur les runners | Runners à **2 vCPU**. Essai jetable, 2 runs chacun : 2 workers 67 s / 64 s, 4 workers 76 s / 60 s | Annulé : pas de gain. `number_of_processors` reste |
| **I** Caches yarn / `node_modules`, bootsnap, assets compilés | `yarn install` 2 s ; `bin/setup` vide `tmp/cache` (bootsnap effacé) ; build des assets < 2 s | Annulés : rien à gagner |
| **J** Réécrire les tests unitaires lents | Profil GitHub : 1 898 tests, 123 s de temps cumulé, médiane ≈ 0,06 s. Les 7 tests qui démarrent l'application en production ou en développement dans un processus enfant pèsent 17 s (14 %) ; aucun autre test ne dépasse 0,8 s. `BCrypt` est déjà au coût minimal (`$2a$04$`), aucun `sleep` inutile (les deux pauses de 0,5 s prouvent un verrou concurrent), les tests de perf sont hors de la suite (`PERF=1`) | Annulé : fusionner deux démarrages enfants gagnerait ≈ 1,5 s d'horloge sur 65 s, sans toucher le chemin critique de façon mesurable. Détail dans le journal |

---

## Décisions à soumettre au porteur

**Aucune n'est activée.** Elles sont le seul chemin vers « ÷ 10 » (57 s), et chacune a un prix.

| # | Option | Horloge attendue d'une PR de code | Ce qu'on perd ou ce que ça coûte |
|---|---|---:|---|
| 1 | **Rien de plus** (livré par cette PR) | ≈ 2 min 20 | Rien sur le filet ; ≈ 2,5 × plus de minutes facturées |
| 2 | **Tests système et perf seulement sur `Develop`, `Staging`, `main`** (pas sur les PR) | ≈ 2 min (le job unitaire reste le plus long) | Un test système cassé n'est vu **qu'après la fusion** dans `Develop`. Le gain est faible : le job unitaire tient déjà le chemin critique. **Déconseillé.** |
| 3 | **Tests système « affectés » seulement sur les PR** (choisis d'après les fichiers modifiés) | ≈ 2 min | Le même défaut que 2, en partiel : la sélection rate les effets indirects (layout, CSS, JS partagé). Déconseillé |
| 4 | **PostgreSQL de l'image du runner** au lieu du conteneur `postgres:17` | − 15 à 20 s par job | L'image fournit PostgreSQL 16, pas 17 : la CI ne tournerait plus sur la version de production |
| 5 | **Runners plus gros** (4 à 16 vCPU, payants, « larger runners ») | ≈ 1 min 30 à 2 min | Budget ; le plancher d'un job (≈ 60 s) ne baisse pas |
| 6 | **Runner auto-hébergé** gardé chaud (outils, gems, base, Chrome déjà là) | **≈ 1 min** : seul chemin vers ÷ 10 | Une machine à administrer et à sécuriser (un runner auto-hébergé sur un dépôt privé n'exécute que le code de l'équipe, mais reste une surface d'attaque) |
| 7 | **Moins de parts** (4 système, 2 perf) pour économiser des minutes | ≈ 2 min 30 | ≈ 20 % de minutes en moins |

Deux points à vérifier par le porteur, quelle que soit l'option :

- **Le quota de minutes** GitHub Actions de l'organisation (Settings → Billing). 145 runs en 4 jours ; ≈ 24 minutes facturées par run au lieu de ≈ 10. Si le quota s'épuise, **toute** la CI s'arrête.
- **Les jobs simultanés** : 14 jobs par run ; l'offre gratuite plafonne l'organisation (20 jobs simultanés). Deux PR poussées ensemble se partagent les runners.

---

## Portes de sortie

- [x] `memo.md` : métrique nommée, valeur avant chiffrée (5 runs, médiane), volume précisé, cible chiffrée
- [x] Protocole de mesure écrit et reproductible (API GitHub : horodatages des jobs et lignes « passed in »)
- [x] Explorer coût rendu : où part le temps (memo, tableau par étape)
- [x] ADR écrit : [ADR-0064](../../decisions/adr/0064-ci-parallele-par-groupes-de-bin-ci.md)
- [x] Tests de non-régression : la suite complète verte, couverture 100 % lignes et branches, avant et après
- [x] Un lot = un levier = un chiffre ; leviers sans gain annulés (G, H, I, J)
- [x] Bench après : même méthode, ≥ 3 runs, médiane (journal)
- [x] Erreurs volontaires refusées par la CI (journal)
- [ ] **Challenger a relancé la mesure lui-même** — rôle distinct, à faire sur la PR #53
- [ ] ADR-0064 accepté par le porteur
