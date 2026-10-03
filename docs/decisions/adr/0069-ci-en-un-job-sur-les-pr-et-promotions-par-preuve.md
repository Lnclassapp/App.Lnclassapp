# ADR-0069 : La CI tourne en un seul job, sur les PR prêtes ; une promotion prouve que son code a déjà été testé

| | |
|---|---|
| **Statut** | Accepté *(par le porteur le 2026-10-02 : runner auto-hébergé abandonné, quatre décisions validées)* — *amendé le 2026-10-02 : preuves des sessions cloud, §8 ; amendé les 2026-10-02 et 2026-10-03 : dix minutes par feature, deux jobs, budget de croissance, §9* |
| **Date** | 2026-10-02 *(première version proposée le 2026-09-30 : runner auto-hébergé)* |
| **Chantier** | `docs/chantiers/ci-quota` |
| **Remplace** | — *(amende l'[ADR-0064](./0064-ci-parallele-par-groupes-de-bin-ci.md) : la matrice de 14 jobs, §4 précision 6 et §5 « plus de minutes facturées »)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le dépôt est privé, sur l'offre gratuite d'une organisation GitHub : **2 000 minutes de runner par mois**, chaque job facturé **à la minute entamée**. L'[ADR-0064](./0064-ci-parallele-par-groupes-de-bin-ci.md) a découpé `bin/ci` en 14 jobs. Le quota s'est épuisé le 2026-09-28. Après sa remise à zéro, le 2026-10-01, il a perdu **≈ 1 500 minutes en une journée** ([memo, mesure du 2026-10-02](../../chantiers/ci-quota/memo.md#mesure-avant-2026-10-02)) :

- un run complet coûte **33 minutes facturées** (runs 355 et 366) pour 4 min 15 d'horloge ;
- sur 43 runs complets, **9 seulement** (21 %) testaient du code nouveau. **17** (40 %) retestaient un arbre déjà testé : push de fusion sur `Develop`, `Staging`, `main`, PR de promotion. **17** (40 %) venaient de Dependabot : 8 PR ouvertes d'un coup **sur `main`**, puis leurs fusions ;
- le test des budgets d'écrans (ADR-0067, 2 min 30) tournait à chaque run, alors que l'ADR-0067 l'a exclu de la CI.

La première version de cet ADR (2026-09-30) déplaçait les jobs sur un runner auto-hébergé, sur la machine du porteur. Le porteur l'a abandonnée le 2026-10-02 : la CI reste sur GitHub, et c'est sa consommation qu'on réduit.

## 2. Moteurs de décision

1. **Tenir dans le quota gratuit** sans payer de minutes ni rendre le dépôt public.
2. **Le filet ne faiblit pas** : mêmes étapes (`config/ci.rb`), même couverture à 100 % (ADR-0024), mêmes tests système dans un vrai Chrome, avant chaque fusion dans `Develop`.
3. **Ne rien tester deux fois** : un arbre de fichiers déjà vert ne se rejoue pas.
4. **Pas de machine à entretenir.**

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Runner auto-hébergé (première version de cet ADR) | 0 minute facturée sur les PR de chantier | Écartée par le porteur le 2026-10-02 : une machine à installer, entretenir et sécuriser, une CI qui s'arrête quand elle s'éteint |
| B — Garder 14 jobs, supprimer seulement les runs en double | Horloge de 4 min conservée | 33 minutes par run de chantier : le quota tient ≈ 60 runs par mois |
| C — Deux jobs (« unitaires et reste », « système ») | Horloge ≈ 9 min | ≈ 15 minutes par run au lieu de ≈ 13 : écartée par le porteur le 2026-10-02, **retenue le 2026-10-03** (§9 : dix minutes d'horloge sur n'importe quel runner) |
| **D — Un seul job, sur les PR prêtes seulement, preuve d'arbre, Dependabot par `Develop`** ✅ | ≈ 13 minutes par run de chantier, ≈ 1 par promotion, rien sur les pushes | Retenue |

## 4. Décision

> **La CI GitHub ne tourne que sur les pull requests prêtes (pas les brouillons), en un seul job nommé `ci` qui joue tout `bin/ci`. Un arbre de fichiers qui a déjà reçu un `ci` vert ne se rejoue pas : une promotion coûte une minute. Dependabot ouvre une PR groupée par écosystème et par semaine, vers `Develop`.**

Précisions qui font partie de la décision :

1. **Plus de CI sur les pushes.** Un push sur `Develop`, `Staging` ou `main` fusionne un arbre que sa PR vient de tester. Les branches protégées attendent toujours le statut `ci`, posé sur la PR.
2. **Un brouillon attend.** Le job ne démarre pas sur une PR en brouillon. Il démarre quand elle passe « prête » (`ready_for_review`), puis à chaque push. Un nouveau push annule le run qu'il rend obsolète (`concurrency`).
3. **La preuve est l'arbre, pas le commit.** Le job lit l'arbre du commit testé (pour une PR, le commit de fusion que GitHub teste) et cherche l'artefact `ci-tree-<arbre>` (`script/ci/tested_tree`). S'il existe et n'a pas expiré, le job est vert sans rien rejouer. Sinon il joue `bin/ci`, et s'il est vert, il publie cet artefact, conservé 30 jours. Tout doute (API en erreur, arbre illisible) répond « non testé » : la suite tourne.
4. **Documents seulement.** Une PR qui ne touche que `docs/` ou des `.md` est verte sans vérification, et ne publie aucune preuve.
5. **Un seul job.** Le démarrage (checkout, Ruby, Node, PostgreSQL, compilation des assets) se paie une fois, et l'arrondi à la minute une fois. Les groupes et les parts de `config/ci.rb` restent, pour jouer un sous-ensemble à la main (`CI_GROUP`). *Amendé le 2026-10-03 (§9) : deux jobs côte à côte, `unit` et `system`.*
6. **Les budgets d'écrans restent hors de `bin/ci`** (ADR-0067) : `test/performance/**/*_budget_test.rb` est exclu du groupe `perf`.
7. **Dependabot suit le chemin de tout changement** : `target-branch: Develop`, une PR groupée par écosystème (`bundler`, `github-actions`), au plus deux ouvertes.

## 5. Conséquences

### 🟢 Positives

- La journée du 2026-10-01 aurait coûté **≈ 150 minutes au lieu de ≈ 1 500** : 9 runs de chantier à ≈ 13 minutes, 6 promotions à ≈ 1 minute, aucun push.
- Les mises à jour de dépendances passent par `Develop` et `Staging` avant la production.
- Plus de matrice à équilibrer pour la CI : `script/ci/test_timings.yml` ne sert plus qu'à un découpage manuel.

### 🔴 Coûts consentis

- **L'horloge d'un run de chantier remonte de ≈ 4 min à ≈ 13 min.**
- **`Staging` et `main` ne sont plus retestés après la fusion.** Une PR testée sur une base dépassée peut fusionner un arbre jamais testé. La promotion suivante ne trouve alors pas de preuve et rejoue la suite : le trou se referme à la promotion, pas à la fusion.
- **Une preuve à faire confiance** : qui peut pousser sur le dépôt peut publier un artefact `ci-tree-…` sans tester. C'est le même niveau de confiance que celui qui lui permet déjà de modifier le workflow.
- **Un brouillon n'a pas de verdict.** C'est voulu : la règle locale (pre-commit et vérification complète avant fusion) couvre le travail en cours.

## 6. Notes d'implémentation

| Fichier | Rôle |
|---|---|
| `.github/workflows/ci.yml` | `pull_request` seul ; job `ci` : preuve d'arbre, documents seulement, `bin/ci`, publication de `ci-tree-<arbre>` |
| `script/ci/tested_tree` | La preuve : arbre de `GITHUB_SHA` par l'API, artefact cherché par son nom ; tout doute répond `false` |
| `config/ci.rb` | Le groupe `perf` exclut `*_budget_test.rb` (ADR-0067) |
| `.github/dependabot.yml` | `target-branch: Develop`, `groups` par écosystème |
| `script/ci/billed_minutes` | Minutes facturées d'un run, à partir des horodatages des jobs |

## 7. Comment vérifier que la décision est respectée

- `test/guards/ci_plan_test.rb` (groupe `lint`) refuse :
  - un second job, une matrice ou un `CI_GROUP` dans le workflow ;
  - un autre déclencheur que `pull_request`, ou un job qui démarre sur un brouillon ;
  - une suite lancée avant la preuve d'arbre, ou une preuve publiée par un run qui n'a rien joué ;
  - un budget d'écran dans `bin/ci` ;
  - un Dependabot qui ne vise pas `Develop` ou ne groupe pas ses mises à jour.
- `test/config/ci_tested_tree_test.rb` : un arbre inconnu, une preuve expirée ou une API en erreur répondent « non testé ».
- `script/ci/billed_minutes <run-id>` : ≈ 13 minutes pour une PR de chantier, 1 pour une promotion prouvée ou une PR de documents.

---

## 8. Amendement du 2026-10-02 : les preuves des sessions Claude cloud

**Décision du porteur.** Une PR vers `Develop` peut être prouvée par une session Claude cloud, sans que GitHub rejoue la suite : la session joue `bin/ci` en entier, puis `script/ci/prove` publie le fichier `arbres/<arbre>` sur la branche `ci/preuves`. Le job `ci` le lit et passe au vert en ≈ 1 minute.

**Ce que la preuve garantit, et ce qu'elle ne garantit pas.** Elle est **déclarative** : la session est pilotée par l'agent dont on vérifie le travail, et rien n'empêche techniquement d'écrire une preuve sans avoir joué la suite. Ce choix de confiance a été pris par le porteur lui-même, après un refus de l'outil de l'agent qui l'a classé « contournement de la CI ». Le code qui fait accepter la preuve (`script/ci/tested_tree`, `LOCAL_PROOF` dans le workflow) est appliqué par le porteur, pas par l'agent.

**Les contrôles qui l'encadrent :**

| Contrôle | Où | Ce qu'il garantit |
|---|---|---|
| **Tirage 1 PR sur 5** | PR vers `Develop` | GitHub rejoue la suite quelle que soit la preuve. Le tirage est fixé par PR (empreinte du secret `CI_DRAW_SALT` et du numéro de PR) : un nouveau push ne retire pas au sort, et personne ne peut le prévoir. Sans le secret, toutes les PR vers `Develop` rejouent la suite. |
| **Suite complète à chaque promotion vers `Staging`** | PR vers `Staging` | Les PR fusionnées depuis la promotion précédente sont toutes dans cet arbre : **aucun code non vérifié par GitHub n'arrive sur `Staging`**, ni donc en production. |
| **Preuve GitHub seulement vers `main`** | PR vers `main` | `LOCAL_PROOF` est faux : seule la preuve publiée par le run complet de `Staging` (même arbre) compte. |
| **Preuve détaillée** | `ci/preuves` | Commit, base, date, machine, session et résumé de `bin/ci` : un audit reste possible après coup. |

**Alarme.** Une PR tirée au sort, rouge alors que sa session l'avait prouvée verte, invalide les preuves de cet environnement : on enquête avant d'en accepter d'autres.

**Coût attendu.** Une PR de chantier ≈ 1 minute, ou 14 si tirée (≈ 4 en moyenne) ; une promotion vers `Staging` 14 ; une release vers `main` ≈ 1.

**Vérification.** `test/config/ci_prove_test.rb` (vrais dépôts git : une preuve publiée par run vert ; rien sur un arbre sale, une base absente, un run rouge, un HEAD qui bouge), `test/config/ci_tested_tree_test.rb` et `test/guards/ci_plan_test.rb` (tirage avant la preuve, `Staging` toujours rejoué, preuve cloud pour `Develop` seulement).

---

## 9. Amendement des 2026-10-02 et 2026-10-03 : dix minutes par feature, sur n'importe quel runner

**Exigence du porteur (2026-10-02).** « 10 min max pour les runners est acceptable par feature. » L'horloge d'un run complet, pas seulement les minutes facturées.

**Mesure.** Run 407 (PR #136, un job) : `bin/ci` 8 min 09, dont système 5 min 55, unitaires 1 min 09, performance d'import 45 s, conteneur PostgreSQL 23 s. Run 472 (PR #148, même suite sans la performance, PostgreSQL de l'image) : `bin/ci` 8 min 52, dont système **7 min 04** pour les mêmes 338 tests, job de 9 min 27, **10 minutes facturées, sans marge**. Deux faits commandent la suite : **les runners varient de 1,5×** d'un run à l'autre (8 min 09 contre 12 min 40 pour la même suite, 2026-10-02), et **la suite système fait 70 % du temps et a grandi de 13 % en un jour** (299 → 338 tests le 2026-10-02).

**Décisions, dans l'ordre de l'algorithme** (questionner, supprimer, simplifier, accélérer, automatiser) :

1. **Supprimer (2026-10-02, PR #148).** Les tests de performance d'import (ADR-0039 : « avant la recette ») ne tournent que dans les **runs complets** : promotion vers `Staging`, PR tirée au sort. Un run qui rejoue la suite sans être tiré joue tout le reste. Le groupe `perf` reste dans `bin/ci` en local.
2. **Supprimer (2026-10-02, PR #148).** Le conteneur `postgres:17` (23 s à tirer et démarrer) est remplacé par le **PostgreSQL de l'image** `ubuntu-latest`, déjà installé : 6 s, mêmes identifiants, boucle locale seulement.
3. **Simplifier et accélérer (2026-10-03).** `bin/ci` se joue en **deux jobs côte à côte** : `unit` (lint, sécurité, unitaires avec couverture 100 %, seeds, assets, et `perf` en run complet) et `system` (les tests système seuls). Deux jobs courts les encadrent : `plan` (tirage, preuve d'arbre, règle « documents seulement », quelques secondes) et `ci`, **le verdict que les branches attendent**, qui publie la preuve `ci-tree-<arbre>` seulement quand les deux jobs sont verts. Remplace la précision 5 du §4 et renverse l'option C du §3. Coût consenti : un run complet ≈ 13 minutes facturées au lieu de 10 (`plan` 1, `unit` ≈ 3, `system` ≈ 8, `ci` 1), une PR prouvée ou de documents ≈ 2 au lieu de 1, soit ≈ 100 minutes de plus par mois. Horloge : celle du job `system`, ≈ 7 min 30 sur le runner du run 472, **≈ 11 min sur un runner 1,5× plus lent** : les dix minutes tiennent alors par le budget (point 4) et par le chantier de sélection (point 5). Levier suivant, si cela ne suffit pas : couper le groupe `system` en deux parts (`system:1/2`, `system:2/2`), un job chacune : mêmes minutes facturées (deux jobs de 4 minutes), horloge divisée par deux.
4. **Automatiser (2026-10-03).** **Budget de croissance de la suite système : 15 secondes par chantier** (décision du porteur ; l'agent proposait 20 s). La durée de référence est celle de `script/ci/test_timings.yml` (secondes par fichier, sommées depuis la sortie `-v` ; réenregistrées depuis le journal GitHub du run complet, à chaque promotion : `script/ci/record_timings`). La garde `test/guards/system_budget_test.rb` (groupe `lint`, pre-commit) refuse une PR dont les fichiers système ajoutés, modifiés ou retirés font grandir la suite de plus de 15 s par rapport à `origin/Develop`, et refuse tout fichier système sans durée enregistrée (il ne pèserait rien). Dépasser le budget est une décision du porteur : relever `SystemBudget::BUDGET` dans `script/ci/system_budget.rb`, avec un amendement ici. Les 82 fichiers système ont leur durée depuis le run 472 (37 n'en avaient pas).
5. **Chantier ouvert (2026-10-03)** : [`selection-par-carte-de-couverture`](../../chantiers/selection-par-carte-de-couverture/memo.md), pour ne jouer que les tests système que les fichiers touchés concernent, là où la suite complète n'est pas exigée par le §8.

**Coût attendu, révisé.** Une PR de chantier prouvée ≈ 2 minutes, ou ≈ 13 si tirée (≈ 4 en moyenne) ; une promotion vers `Staging` ≈ 13 ; une release vers `main` ≈ 2.

**Vérification.** `test/guards/ci_plan_test.rb` : quatre jobs sans matrice ; `unit` et `system` jouent chaque groupe de `bin/ci` une fois, `perf` en run complet seulement ; la preuve n'est publiée que par `ci`, quand les deux jobs sont verts ; un brouillon n'a pas de verdict ; PostgreSQL de l'image avant `bin/ci` dans chaque job, aucun conteneur de service. `test/guards/system_budget_test.rb` : budget 15 s, seuls les fichiers touchés comptent, un test retiré rend ses secondes, un fichier sans durée est refusé.
