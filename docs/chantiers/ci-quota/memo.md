# Memo — La CI épuise le quota de minutes GitHub Actions

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | cadrage |
| **Ouvert le** | 2026-09-29 |
| **Branche** | `perf/ci-quota` |
| **Programme** | — |

---

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

- Le contenu des tests : aucun test n'est supprimé, désactivé ni affaibli ; la couverture reste 100 % lignes et branches sur la suite complète (ADR-0024).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| 1. « Moins de 3 minutes » : l'horloge d'un run, ou les minutes facturées par run ? | **Les deux, selon la branche.** Les PR de chantier : verdict en moins de 3 minutes d'horloge, sur un **runner auto-hébergé sur la machine du porteur** (minutes non décomptées du quota). Les promotions `Develop` → `Staging` et `Staging` → `main` : **moins de 3 minutes facturées** par run, sur les runners GitHub. | Deux métriques et deux cibles au lieu d'une (tableau *Écart avec la demande*). Le runner local devient une dépendance de la CI : sa disponibilité (machine éteinte), son système et sa sécurité sont à trancher dans les questions suivantes. Les promotions ne rejouent plus la suite complète sur GitHub : il faut une preuve que le code promu a déjà été testé (question 2). |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …
