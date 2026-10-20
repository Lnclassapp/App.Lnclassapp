# ADR-0107 : La preuve d'une PR suit ce qu'elle touche ; la CI complète tourne une fois par train, avant `Staging`
<!-- index
titre: CI par niveau, complète par train
statut: Accepté
problematique: Une CI complète par PR fait jouer la suite entière à chaque fusion (17 PR le 2026-10-19). `bin/ci-quiet` choisit le niveau d'après le diff (doc, pr, train), ne rejoue pas un code déjà vert, et la suite complète ne tourne plus qu'une fois sur `Develop`, avant chaque promotion vers `Staging`.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-20 |
| **Chantier** | [`docs/chantiers/ci-par-train`](../../chantiers/ci-par-train/memo.md) |
| **Remplace** | la règle « une CI complète par PR » (`docs/workflows/README.md` §5.3, chantier `ci-perf-a-la-demande`) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

La CI GitHub est coupée (ADR-0069) : la preuve de chaque PR est un `bin/ci-quiet` local, en entier, sur le head final. Le 2026-10-19, 17 PR ont été fusionnées sur `Develop`, soit au moins 17 suites complètes (10 min 17 s pour celle de la PR #262, plus longtemps sur un poste 4 cœurs chargé). Une PR qui ne touche que de la documentation payait le même prix qu'une migration. Le porteur demande de réduire drastiquement le nombre de suites complètes.

## 2. Moteurs de décision

1. Ne prouver dans une PR que ce qu'elle peut casser, et le prouver vite.
2. Ne jamais rejouer un code déjà vert.
3. Aucun code non prouvé par la suite complète n'arrive sur `Staging`, donc en production.
4. Appliqué par l'outil : l'agent lance `bin/ci-quiet` comme avant, l'outil choisit.
5. **Aucune preuve, aucun test, aucune tâche de CI ne dépasse 5 minutes**, la suite complète comprise (décision du porteur, 2026-10-20).

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Garder une CI complète par PR | La régression est vue avant la fusion | 17 suites par jour |
| B — Niveau doc et verdict réutilisé seulement | Sans risque | Les PR de code, la majorité, paient toujours la suite entière |
| C — **Trois niveaux, verdict réutilisé, suite complète par train** ✅ | Une suite par promotion ; les PR prouvent leur périmètre en minutes | Une régression hors périmètre reste sur `Develop` jusqu'au train |

## 4. Décision

> **`bin/ci-quiet` choisit le niveau de preuve d'après les fichiers changés depuis `origin/Develop`. Un code (arbre sans son Markdown) déjà vert à ce niveau ou au-dessus ne se rejoue pas. La suite complète ne tourne qu'au niveau train : sur `Develop`, avant chaque promotion vers `Staging`.**

| Niveau | Quand | Ce qui tourne |
|---|---|---|
| **doc** | Seulement du Markdown hors du code (`docs/`, `.claude/`, la racine) | Les gardes du groupe `lint` |
| **pr** | Tout autre changement sur une branche de chantier | Les gardes, Rubocop sur les fichiers changés (tout l'arbre si `.rubocop.yml` ou `Gemfile.lock` change), le groupe `security`, les tests unitaires du périmètre, `bin/system-changed` ; sans installation ni seuil de couverture. **Moins de 5 minutes.** |
| **train** | `Develop`, `Staging`, `main`, `--full`, ou un changement des dépendances ou du socle de test (`test_helper.rb`, `application_system_test_case.rb`) | Tout `bin/ci`, couverture à 100 % |

Le périmètre d'une PR (`script/ci/scope.rb`) comprend les tests modifiés, le miroir de chaque fichier Ruby (la correspondance du pre-commit), et tout test qui nomme ce qui a changé : la constante d'un fichier Ruby, les méthodes d'une aide de `test/support/`, le jeu d'une fixture (`users(:`), le nom de tout autre fichier ou l'un de ses dossiers (`docs/contenus/lecons-traitees`).

**La promotion.** La PR `Develop → Staging` est prouvée par la CI GitHub (variable `CI_ENABLED`, réactivée le 2026-10-20), qui ne tourne plus que sur les PR vers `Staging` et `main`. La suite y est découpée en tâches parallèles de **5 minutes au plus** (`timeout-minutes: 5`, garde `test/guards/ci_plan_test.rb`) : `unit` en trois parts (la suite unitaire et sa couverture ; lint, sécurité, seeds et assets ; la perf des imports) et `system` en six parts équilibrées (≈ 167 s de tests enregistrés chacune). Sans `ci` vert, elle ne fusionne pas. `bin/ci-quiet --full` reste possible en local, mais il n'est plus la preuve d'une promotion : sur un poste 4 cœurs, il dure 10 à 25 minutes. Un train rouge ne se rejoue pas en entier : on rejoue les seuls tests en échec sur chaque fusion du train (`git log --first-parent --merges`) jusqu'à trouver la PR fautive, qui est corrigée par une nouvelle PR.

## 5. Conséquences

### 🟢 Positives

- Sur les 28 dernières PR fusionnées (rejouées par `script/ci/scope.rb`) : 1 au niveau doc, 25 au niveau pr, 2 en train (dépendances, socle des tests système). Une suite complète par promotion au lieu d'une par PR.
- Une PR de documentation se prouve en quelques secondes.
- Une fusion de `Develop` qui n'apporte que du Markdown, ou une phrase corrigée après revue, ne rejoue rien.

### 🔴 Coûts consentis

- **Une régression hors du périmètre ou une couverture tombée sous 100 % se découvre au train**, pas à la PR. Elle peut rester quelques heures sur `Develop`, jamais atteindre `Staging`.
- Le verdict gardé est local (`tmp/ci-verdicts/`) : il ne vaut que sur la machine qui l'a produit. La preuve qui compte reste la ligne écrite dans la PR.
- Une aide de test partagée (fabriques) sélectionne une grande partie des tests unitaires : la suite système, les seeds, la perf et le budget des assets restent au train.
- Le train joue sur GitHub en tâches parallèles : le dépôt est public, les minutes sont gratuites. Si GitHub n'attribue plus de runner (constat du 2026-10-04, ADR-0069), la promotion attend : la suite locale ne tient pas en 5 minutes.
- Une part qui grossit au-delà de 5 minutes rend la CI rouge : il faut alors ajouter une part (`SYSTEM_PARTS`) ou alléger les tests, jamais relever le plafond sans décision du porteur.
- Les niveaux doc et pr ne jouent pas `bin/setup` : une machine qui n'est pas installée doit lancer `bin/setup` d'abord.

## 6. Notes d'implémentation

- `script/ci/scope.rb` : niveau, périmètre, empreinte, verdicts. Tests : `test/config/ci_scope_test.rb`.
- `bin/ci-quiet` : `--plan` affiche le niveau et les commandes sans rien jouer ; `--full` force le train ; `CI_GROUP=…` joue un sous-ensemble, comme avant, sans niveau ni verdict.
- Un arbre de travail sale se joue mais ne laisse pas de verdict.
- `script/ci/test_timings.yml`, réenregistré à chaque promotion, n'est pas un changement de CI.

## 7. Comment vérifier que la décision est respectée

`bin/ci-quiet --plan` sur la branche dit ce qu'elle doit. Chaque PR porte une ligne `Preuve : bin/ci-quiet niveau … vert sur <sha>`, et chaque PR vers `Staging` une ligne de niveau **train**.
