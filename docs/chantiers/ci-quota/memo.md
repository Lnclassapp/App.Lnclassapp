# Memo — La CI épuise le quota de minutes GitHub Actions

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | en cours — repris le 2026-10-02 : **runner auto-hébergé abandonné**, la CI reste sur GitHub |
| **Ouvert le** | 2026-09-29 |
| **Branche** | `perf/ci-quota` |
| **Programme** | — |

> **Recadrage du 2026-10-02.** Le porteur abandonne le runner auto-hébergé (lots 0, A, C, D, E de la première version du plan) : « supprimons l'installation du runner en local, nous allons optimiser l'exécution des tests, et les running sur GitHub ». La méthode imposée est l'algorithme en cinq étapes : questionner les exigences, supprimer, simplifier, accélérer, automatiser, dans cet ordre. Nouvelle mesure ci-dessous ; décisions dans l'[ADR-0069](../../decisions/adr/0069-ci-en-un-job-sur-les-pr-et-promotions-par-preuve.md) réécrit ; lots dans le [plan](plan.md).

## Mesure avant (2026-10-02)

Le quota est remis à zéro le 2026-10-01 vers 00 h UTC (dernier refus : run 316, 2026-09-30 23 h 38 ; premier succès : run 317, 00 h 24). Méthode : horodatages des jobs (API `list_workflow_jobs`), `ceil` par job.

**Un run complet coûte 33 minutes facturées** (run 355, PR de chantier ; run 366, push sur `main`), pour 4 min 15 d'horloge :

| Bloc | Jobs | Minutes facturées | Travail utile (`bin/ci`, run 355) |
|---|---:|---:|---:|
| Système (299 tests) | 6 | 18 | 671 s |
| Performance + seeds | 3 | 8 | 275 s, dont ≈ 150 s pour le seul budget d'écrans (ADR-0067 l'exclut de la CI) |
| Unitaires (2 738 tests, couverture 100 %) | 1 | 3 | 131 s |
| Lint, sécurité et assets, `changes`, `ci` | 4 | 4 | 26 s |

**Les 50 runs du 2026-10-01 au 2026-10-02 9 h** (runs 317 à 366) : 43 complets, 4 « documents seulement » (2 minutes), 3 annulés. **≈ 1 500 minutes consommées** sur 2 000.

| Origine | Runs complets | Minutes | Part |
|---|---:|---:|---:|
| PR de chantier (code nouveau) | 9 | 297 | 21 % |
| Push de fusion sur `Develop` (5), PR de promotion (6), push sur `Staging` (4) et sur `main` (2) | 17 | 561 | 40 % |
| Dependabot : 8 PR ouvertes d'un coup sur `main`, 2 rebases, 7 fusions sur `main` | 17 | 561 | 40 % |

**Tests par étape, d'une feature à `main`** (avant ce chantier) :

| # | Étape | Où | Tests |
|---|---|---|---:|
| 1 | Chaque commit | hook pre-commit | 0 à ≈ 700 (les tests des fichiers touchés, jamais le système) |
| 2 | Avant fusion | local, règle « option A » | ≈ 3 040 (unitaires et système complets) |
| 3 | Chaque push sur la PR | GitHub | 3 063 × N |
| 4 à 8 | Push `Develop`, PR et push `Staging`, PR et push `main` | GitHub | 3 063 × 5, **le même arbre** que l'étape 3 |

Une feature poussée une fois sur sa PR : ≈ 21 400 exécutions de tests et 198 minutes facturées.

**Mesures locales, 2 CPU** (comme un runner GitHub) : unitaires 86 s, système 424 s (**1 échec et 1 erreur**, verts sur 4 CPU : instables sous charge, comme le run 326, part `system:3/6`, rouge entre deux runs verts du même arbre), performance 233 s dont 156 s pour le budget d'écrans.

### Les cinq étapes appliquées

| Étape | Ce qui a été fait | Effet attendu sur la journée du 2026-10-01 |
|---|---|---|
| 1. Questionner | « Toute la suite à chaque push sur chaque branche » venait de l'ADR-0064 ; « Dependabot sur `main` » de sa configuration par défaut ; « le budget d'écrans en CI » d'un glob trop large, contre l'ADR-0067. Aucune n'était une exigence du porteur. | — |
| 2. Supprimer | Runner auto-hébergé (scripts, guide, service de relance, bouton de secours) ; CI sur les pushes ; CI sur les brouillons ; rejeu d'un arbre déjà vert ; budget d'écrans dans `bin/ci` ; Dependabot sur `main` | 17 runs de fusion et de promotion → 6 à ≈ 1 min ; 17 runs Dependabot → ≈ 2 par semaine |
| 3. Simplifier | 14 jobs → **1** | Le démarrage et l'arrondi payés une fois : ≈ 13 minutes par run au lieu de 33 |
| 4. Accélérer | Rien de plus dans ce lot : la suite reste celle de `bin/ci`. Levier suivant noté : redescendre au niveau contrôleur une partie des 299 tests système | — |
| 5. Automatiser | Gardes dans `test/guards/ci_plan_test.rb`, rouges sur l'ancien workflow (5 échecs), vertes sur le nouveau | — |

**Projection : ≈ 150 minutes au lieu de ≈ 1 500 pour la même journée.** À mesurer sur de vrais runs : voir le [plan](plan.md).

### Décisions du porteur (2026-10-02)

| Question | Réponse |
|---|---|
| Runner auto-hébergé ? | Abandonné. |
| Désactiver la CI en attendant la fusion ? | Oui, par le porteur (*Actions → CI → Disable workflow*) : l'agent n'a pas d'outil pour le faire. |
| Dependabot ? | Vers `Develop`, une PR groupée par écosystème ; les 8 mises à jour déjà sur `main` reviennent dans `Develop` par une PR séparée. |
| Un job ou deux ? | Un. |
| CI sur les brouillons ? | Non : seulement sur les PR prêtes. |

---

## Historique : première version (2026-09-29 et 2026-09-30, runner auto-hébergé, abandonnée)

## Le problème

Depuis le 2026-09-28 à 10 h 44 UTC, **aucun job de CI ne démarre** : le quota de minutes GitHub Actions de l'organisation est épuisé. Chaque run échoue en quelques secondes, sans étape exécutée, sur toutes les branches. Les PR sont fusionnées sans verdict de la CI.

Le chantier [`ci-rapide`](../ci-rapide/memo.md) (ADR-0064) a fait passer l'horloge d'un run de 9 min 28 à environ 2 min 30 en découpant `bin/ci` en 14 jobs parallèles. Il avait prévenu : chaque job est facturé à la minute entamée et paie son propre démarrage, donc un run consomme environ 2,5 fois plus de minutes ([plan de `ci-rapide`, décisions à soumettre](../ci-rapide/plan.md#décisions-à-soumettre-au-porteur)).

Demande du porteur (2026-09-29) : « ouvre /optimize ci-quota pour amener à moins de 3 minutes ».

## Pour qui

L'équipe et les agents qui ouvrent des PR : sans quota, plus aucune PR n'a de verdict, et le passage `Staging` → `main` se fait à l'aveugle.

## Pourquoi maintenant

La CI est à l'arrêt complet. Tant que la consommation reste la même, la remise à zéro du quota ne fera que repousser la prochaine panne de quelques jours.

## Mesure avant

**Règle de facturation** : GitHub facture chaque job à la **minute entamée**, sur un runner `ubuntu-latest` à 2 vCPU (dépôt privé). Un job de 5 s coûte 1 minute, un job de 2 min 01 en coûte 3.

**Méthode** : horodatages `started_at` / `completed_at` de chaque job (API GitHub `list_workflow_jobs`). Minutes facturées = somme des `ceil(durée / 60)`. Le calcul est versionné : [`script/ci/billed_minutes`](../../../script/ci/billed_minutes) (`script/ci/billed_minutes <run-id> …`, lit les jobs avec `gh api`). *(L'API `get_workflow_run_usage` renvoie 0 ms pour tous les runs : elle ne sert pas.)*

### 1. Coût d'un run de PR qui touche du code

| Configuration | Run | Horloge | Temps de job cumulé | Minutes facturées |
|---|---|---:|---:|---:|
| **14 jobs** (ADR-0064, actuelle) | [36410838383](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36410838383) · push `Develop` | 2 min 36 | 20 min 15 | **27** |
| **14 jobs** (actuelle) | [36409044736](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36409044736) · PR `fix/bareme-classes-suivi` | 2 min 39 | 21 min 00 | **29** |
| 11 jobs (essai de `ci-rapide` : 4 système, 2 perf) | [36397112073](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36397112073) · PR `perf/ci-rapide` | 2 min 50 | 15 min 58 | **22** |
| 1 job (avant ADR-0064) | 4 runs du 2026-09-28 ([36405902635](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36405902635), [36406138472](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36406138472), [36406403139](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36406403139), [36405769057](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36405769057)) | 6 min 42 à 10 min 06, médiane 7 min 38 | médiane 7 min 38 | 7, 8, 9, 11 : **médiane 8,5** |
| PR qui ne touche que des documents | [36409216389](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36409216389), [36409206023](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36409206023) | 18 s | ≈ 8 s | **2** (`changes` + `ci`) |

**Seuls deux runs de la configuration actuelle ont réussi** avant l'épuisement du quota : la règle des trois exécutions ne peut pas être tenue pour eux. Le troisième point est la variante à 11 jobs, très proche.

Ce que le tableau dit :

- Le découpage a divisé l'horloge par 3 et **multiplié les minutes facturées par 3,3** (8,5 → 28).
- Dans un run à 14 jobs, **le travail utile (`bin/ci`) ne fait que 852 s sur 1 260 s** de job. Le reste est le plancher de chaque job : conteneur PostgreSQL (14 à 28 s), checkout, Ruby et Node (10 à 15 s).
- **L'arrondi à la minute ajoute 8 minutes par run** (29 facturées pour 21 réelles). Les jobs `changes` et `ci` durent 5 s et coûtent 1 minute chacun.
- Même en un seul job, **la suite complète coûte 7 à 11 minutes facturées** sur un runner à 2 vCPU : c'est le plancher de `bin/ci` sur les runners GitHub standard.

### 2. Nombre de runs

Le 2026-09-29, de 17 h 15 à 23 h 21 UTC (runs 241 à 280, tous tombés sur le quota épuisé, mais déclenchés) : **40 runs en 6 heures**.

| Déclencheur | Runs | Part | Ce qu'il teste |
|---|---:|---:|---|
| PR de chantier (dont 5 pour une seule PR, `fix/import-drenas-boutons-entete`) | 16 | 40 % | Du code nouveau |
| PR de promotion (`Develop` → `Staging`, `Staging` → `main`) | 6 | 15 % | Du code **déjà testé** sur `Develop` |
| Push sur `Develop`, `Staging`, `main` (fusion) | 18 | 45 % | Du code **déjà testé** dans sa PR ; 2 runs sur le **même commit** de `main` |

À 28 minutes par run, ces 40 runs auraient coûté **≈ 1 100 minutes facturées en une soirée**.

### 3. Le quota

L'offre gratuite d'une organisation GitHub donne **2 000 minutes par mois** sur les dépôts privés, soit **≈ 66 minutes par jour**. *À confirmer par le porteur : Settings → Billing de l'organisation.* Les runs 1 à 180 (du 2026-09-2x au 2026-09-28 10 h 44), environ 160 à 8,5 minutes puis une vingtaine à 28, font ≈ 1 900 à 2 000 minutes : c'est cohérent avec ce plafond.

### Écart avec la demande

| Métrique | Avant | Demandé | Budget du quota gratuit | Comment mesurée |
|---|---:|---:|---:|---|
| Horloge d'un run de PR de chantier | 2 min 36 – 2 min 39 | **< 3 min** (runner local) | — | création → fin du run |
| Minutes GitHub facturées par run de PR de chantier | 27 – 29 | **0** (runner local) | — | `ceil` par job hébergé, [`script/ci/billed_minutes`](../../../script/ci/billed_minutes) |
| Minutes GitHub facturées par run de promotion (PR et push `Staging`, `main`) | 27 – 29 | **< 3** | — | idem |
| Minutes facturées par jour de travail soutenu | ≈ 1 100 (40 runs) | — | **66** | idem, × runs du jour |

## Hors périmètre

*Validé par le porteur le 2026-09-30 (grill, question 6).*

- **Les tests** : aucun n'est supprimé, désactivé ni affaibli ; la couverture reste 100 % lignes et branches sur la suite complète (ADR-0024).
- **La liste des étapes de `bin/ci`** (`config/ci.rb`) : seuls changent la machine qui exécute et le moment où la CI se déclenche.
- **Les runners GitHub payants et le passage du dépôt en public** : écartés.
- **L'entretien de la machine du porteur** (mises à jour d'Ubuntu, de Docker, de Chrome) : à sa charge. Le chantier fournit une procédure d'installation et une commande qui vérifie que le runner est prêt.
- **Les déploiements Railway** : ils ne dépendent pas de la CI et ne changent pas.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| 1. « Moins de 3 minutes » : l'horloge d'un run, ou les minutes facturées par run ? | **Les deux, selon la branche.** Les PR de chantier : verdict en moins de 3 minutes d'horloge, sur un **runner auto-hébergé sur la machine du porteur** (minutes non décomptées du quota). Les promotions `Develop` → `Staging` et `Staging` → `main` : **moins de 3 minutes facturées** par run, sur les runners GitHub. | Deux métriques et deux cibles au lieu d'une (tableau *Écart avec la demande*). Le runner local devient une dépendance de la CI : sa disponibilité (machine éteinte), son système et sa sécurité sont à trancher dans les questions suivantes. Les promotions ne rejouent plus la suite complète sur GitHub : il faut une preuve que le code promu a déjà été testé (question 2). |
| 2. Sur une promotion, qu'est-ce qui remplace la suite complète ? | **La preuve que le code promu a déjà été testé.** Un seul job GitHub vérifie que l'arbre de fichiers du commit promu a déjà reçu un `ci` vert du runner local sur `Develop` ; si oui, la promotion est verte. Si cet arbre n'a jamais été testé (correctif poussé directement sur `Staging`, fusion qui crée un contenu nouveau), la suite complète part sur le runner local, **jamais** sur un runner GitHub. | Une promotion coûte 1 à 2 minutes facturées au lieu de 28. Risque accepté par le porteur : `Staging` et `main` ne sont plus retestés sur une machine GitHub propre, donc une différence d'environnement entre la machine du porteur et GitHub (Chrome, PostgreSQL) n'est plus rattrapée à la promotion. L'égalité d'arbre (`git rev-parse <commit>^{tree}`) est la clé de la preuve : elle ignore les messages et les commits de fusion, pas le contenu. Le statut attendu par les branches garde le nom `ci`. |
| 3. Sur quelle machine tourne le runner ? | **Ubuntu 22.04.5 LTS, 64 bits, 4 cœurs, Docker installé.** | Le conteneur `postgres:17` du workflow tourne tel quel (les conteneurs de service n'existent que sur un runner Linux avec Docker). Chrome, Ruby 3.4 et Node s'installent par les mêmes actions qu'aujourd'hui, ou restent en cache sur la machine. **« Moins de 3 minutes » n'est pas acquis sur 4 cœurs** : `bin/ci` coûte ≈ 390 s de travail sur les 2 vCPU de GitHub, dont 137 s de perf d'import en un seul processus. Il faudra plusieurs runners en parallèle sur la même machine, et la valeur réelle ne se connaîtra qu'en mesurant sur elle (premier lot). |
| 4. Que se passe-t-il quand la machine est éteinte ? | **La PR attend, jusqu'à 48 heures**, et un bouton manuel (« Run workflow ») lance la suite sur un runner GitHub en cas d'urgence. | GitHub **annule** tout job resté 24 h en file sans runner, et cette limite ne se règle pas ([docs GitHub](https://docs.github.com/en/actions/reference/runners/self-hosted-runners)). Les 48 h s'obtiennent côté machine : à son démarrage (puis à intervalle régulier), un service local **relance les runs annulés depuis moins de 48 h** dont la PR est encore ouverte et le commit inchangé. Au-delà de 48 h, un nouveau push ou le bouton manuel. Le bouton coûte ≈ 9 minutes facturées par clic (un seul job, pas la matrice de 14). Aucune bascule automatique vers GitHub : c'est elle qui a épuisé le quota. |
| 5. Avec quels droits le runner tourne-t-il ? | **Un utilisateur Linux dédié, `github-runner`, sans `sudo`**, sans accès au dossier personnel du porteur, membre du groupe `docker`. | Un test (ou un agent) qui dérape ne lit pas les clés SSH, jetons et fichiers du porteur. Risque résiduel accepté : le groupe `docker` équivaut à root pour qui le détourne exprès ; il est nécessaire au conteneur PostgreSQL. Le runner ne sert que ce dépôt privé (jamais un dépôt public, où n'importe qui pourrait lui faire exécuter du code). Le runner s'installe en service systemd sous cet utilisateur ; le service de relance (question 4) aussi, avec un jeton GitHub limité à ce dépôt et aux droits `actions: write`. |
| 6. Qu'est-ce que le chantier ne touche pas ? | La liste proposée, sans ajout ni retrait. | Section *Hors périmètre*. |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …
