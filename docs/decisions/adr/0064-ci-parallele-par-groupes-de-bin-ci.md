# ADR-0064 : La CI GitHub joue les groupes de `bin/ci` en parallèle, une seule liste d'étapes
<!-- index
titre: La CI GitHub joue les groupes de `bin/ci` en parallèle, une seule liste d'étapes
statut: Accepté *(2026-09-28)*
problematique: `config/ci.rb` range ses étapes en groupes ; chaque job lance `CI_GROUP=<groupe>` ou une part (`system:k/n`) ; job final `ci` ; tests unitaires découpés sur GitHub depuis le 2026-11-04, couverture fusionnée et seuil vérifié sur la suite entière (ADR-0024).
-->

| | |
|---|---|
| **Statut** | Accepté *(par le porteur le 2026-09-28, défauts compris)* — *amendé par l'[ADR-0069](./0069-ci-en-un-job-sur-les-pr-et-promotions-par-preuve.md) (accepté le 2026-10-02) : un seul job sur les PR prêtes, promotions par preuve d'arbre* — *§4.1 amendé le 2026-11-04 (chantier `ci-unit-en-parts`) : la suite unitaire en deux parts sur GitHub, couvertures fusionnées* |
| **Date** | 2026-09-28 |
| **Chantier** | `docs/chantiers/ci-rapide` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Depuis l'amorçage du dépôt, la CI GitHub est **un seul job** qui lance `bin/ci`, et `bin/ci` joue en série les étapes de `config/ci.rb`. Ce choix appliquait le garde-fou n° 4 de la [feuille de route](../../chantiers/refonte-application/feuille-de-route.md#2-phase-0--amorçage-du-dépôt) et évitait un piège vécu : un `bin/ci` local et un workflow GitHub qui déclarent chacun leurs étapes finissent par diverger.

Le 2026-09-28, un run durait 9 min 28 (médiane de 5 runs, [memo du chantier](../../chantiers/ci-rapide/memo.md)), dont 82 % pour trois étapes indépendantes : les tests système (4 min 19), la perf d'import (2 min 17) et les tests unitaires (1 min 10). Les runners d'un dépôt privé ont 2 vCPU : la seule façon de raccourcir l'attente est de répartir ces étapes sur plusieurs runners.

## 2. Moteurs de décision

- **Une seule liste d'étapes.** Le workflow ne déclare aucune commande de vérification ; `bin/ci` local reste la référence.
- **Le filet de sécurité ne faiblit pas.** Même étapes, même seuil de couverture (100 % lignes et branches sur la suite complète, ADR-0024), mêmes tests système dans un vrai Chrome.
- **Un statut unique et fiable** pour la PR, qui ne peut pas être vert si un morceau a échoué, a été annulé ou n'a pas tourné.
- **Le temps d'horloge** d'un run de PR, pas le temps cumulé.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Garder un job, accélérer les étapes | Aucune complexité ajoutée | Les étapes lentes sont déjà parallélisées sur les 2 vCPU du runner ; le gain possible est de quelques secondes |
| B — Un workflow qui déclare ses propres jobs et commandes | Le plus courant | Deux listes d'étapes : c'est exactement la divergence que le garde-fou n° 4 interdit |
| C — Groupes déclarés dans `config/ci.rb`, choisis par `CI_GROUP` ✅ | Une seule liste ; chaque job lance `bin/ci` ; une garde vérifie que les jobs redonnent la liste complète | Retenue |
| D — Découper aussi les tests unitaires et fusionner la couverture (`SimpleCov.collate`) dans un job final | Raccourcit le job unitaire | Mesuré : un job de fusion coûte environ 30 s de plancher et arrive après les parts ; l'horloge ne baisse pas tant que les parts système et perf durent autant. Réévaluable si le job unitaire devient seul le plus long |

## 4. Décision

> **Nous rangeons les étapes de `config/ci.rb` en groupes (`lint`, `security`, `unit`, `system`, `seeds`, `perf`, `assets`). `bin/ci` sans `CI_GROUP` joue tous les groupes dans l'ordre de déclaration. Sur GitHub, chaque job joue `CI_GROUP=<groupe>[,<groupe>]` ou une part d'un groupe découpé (`system:k/n`, `perf:k/n`), et un job final nommé `ci` n'est vert que si tous les jobs le sont.**

Précisions qui font partie de la décision :

1. ~~**Les tests unitaires ne sont jamais découpés**~~ *(amendé le 2026-11-04, voir §8)* : le seuil de couverture de l'ADR-0024 s'applique à la suite complète. En local, elle tourne en un seul processus parent qui fusionne ses workers ; sur GitHub, elle tourne en parts dont les couvertures sont fusionnées avant le seuil.
2. **Le découpage est déterministe** : les fichiers sont répartis par durée décroissante dans la part la plus légère, à partir de `script/ci/test_timings.yml` (versionné, régénéré par `script/ci/record_timings` depuis la sortie `-v` d'un run). Un fichier absent de la liste pèse la médiane : il tourne quand même.
3. **La garde `test/guards/ci_plan_test.rb`** lit le workflow et vérifie que ses jobs jouent chaque groupe une fois, chaque part une fois, et chaque fichier de test dans exactement une part. Elle tourne dans le groupe `lint`.
4. **Un `CI_GROUP` inconnu fait échouer `bin/ci`** : une faute de frappe ne donne jamais un job vert qui n'a rien lancé.
5. **Le job `ci` garde son nom** : c'est le contexte que la protection des branches exigera le jour où l'offre du dépôt la permettra ([journal d'amorçage §5](../../chantiers/amorcage-depot/journal.md)).
6. **Une PR qui ne touche que `docs/` ou des fichiers `.md`** saute les jobs de vérification ; `ci` est vert quand même. Un push sur `Develop`, `Staging` ou `main` joue toujours tout.

## 5. Conséquences

### 🟢 Positives

- L'horloge d'un run de PR passe de 9 min 28 à environ 2 min 30 (mesures dans le [journal](../../chantiers/ci-rapide/journal.md)).
- Un échec se lit dans le nom du job qui l'a produit (`tests (system:3/6)`), et les autres jobs vont au bout (`fail-fast: false`).
- `bin/ci` local ne change pas pour le développeur : même commande, mêmes étapes, même ordre.

### 🔴 Coûts consentis

- **Plus de minutes facturées.** Chaque job paie son plancher (conteneur PostgreSQL, checkout, Ruby, Node, `bin/setup` : environ une minute) et est facturé à la minute entamée : environ 24 minutes par run au lieu de 10. Sur l'offre gratuite d'une organisation (quota mensuel de minutes pour les dépôts privés), c'est à surveiller.
- **Plus de jobs simultanés.** 14 jobs par run ; l'offre gratuite plafonne le nombre de jobs simultanés de l'organisation. Deux PR poussées en même temps peuvent attendre un runner.
- **Une liste de durées à entretenir.** Des durées périmées ne font sauter aucun test, mais déséquilibrent les parts. Les régénérer quand une part dépasse nettement les autres.
- **Un fichier de plus à comprendre** (`script/ci/plan.rb`) entre `config/ci.rb` et `ActiveSupport::ContinuousIntegration`.

## 6. Notes d'implémentation

- `config/ci.rb` : `CiPlan.define { group … ; sharded … }`, puis `CI.run` joue `CI_PLAN.steps_for(ENV["CI_GROUP"])`.
- Une part système lance `bin/rails test:prepare` (la compilation des assets, que `bin/rails test <fichiers>` saute) et fixe `PARALLEL_WORKERS` au nombre de CPU (sous 50 tests, Rails resterait sur un seul processus).
- `.github/actions/setup` prépare Ruby, Node et Yarn pour tous les jobs ; `libpq-dev` n'est installé que s'il manque à l'image.
- `bin/setup --skip-db` sert aux groupes sans base (`lint`, `security`, `assets`).

## 8. Amendement du 2026-11-04 — la suite unitaire en parts, la couverture fusionnée

Décision du porteur, chantier [`ci-unit-en-parts`](../../chantiers/ci-unit-en-parts/memo.md).

**Constat.** La tâche `unit unit` (8 127 tests, seuil 100 % / 100 %) a dépassé le plafond de 5 minutes de l'ADR-0107 : trois coupures le 2026-11-04 (trains #468 et #476), 316 s et 317 s de tâche, dont 253 s et 295 s de `bin/ci`. Le train #476 n'était bloqué que par elle.

**Décision.**

1. Sur GitHub, la suite unitaire tourne en **deux parts** (`unit:1/2`, `unit:2/2`) — **trois** depuis le 2026-11-05 ([ADR-0107 §9](./0107-la-preuve-d-une-pr-suit-ce-qu-elle-touche.md#9-amendement-du-2026-11-05--un-train-plus-court)) —, découpées comme `system` : chaque fichier dans une part et une seule, équilibrées sur `script/ci/test_timings.yml`. Aucun test n'est sauté.
2. Une part mesure sa couverture sous son propre nom (`COVERAGE_PART=k/n`, `command_name "unit k/n"`) **sans seuil**, et garde son `.resultset.json`.
3. La tâche **`coverage`** télécharge les résultats des parts, exige exactement autant de résultats que de parts, les fusionne (`script/ci/coverage_collate`, `SimpleCov.collate`) et applique **le même seuil, 100 % lignes et branches, sur la suite entière**. Le verdict `ci` l'attend.
4. Le réglage de SimpleCov vit dans un seul profil (`test/coverage_profile.rb`), lu par le test et par la fusion : le seuil ne peut pas diverger entre les deux.
5. En local, `bin/ci` et `bin/ci-quiet` gardent la suite entière en un seul passage, seuil compris.

**Garde.** `test/guards/ci_plan_test.rb` vérifie que les parts jouent exactement les fichiers de la suite entière, que chaque part mesure sans seuil, que `coverage` fusionne `UNIT_PARTS` résultats avec le seuil, et que `ci` l'attend.

