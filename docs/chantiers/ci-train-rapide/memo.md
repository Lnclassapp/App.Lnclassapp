# Memo — Un train plus rapide sur GitHub

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-05 (ouverture validée par le porteur) |
| **Branche** | `perf/ci-train-rapide` (lot A), `perf/ci-train-rapide-lecons` (lot B), `docs/ci-train-rapide-deploiement` (lot C) |
| **Programme** | — |

---

## Le problème

La CI d'un train `Develop → Staging` dure 4 min 20 à 6 min 48 d'horloge (médiane 4 min 53) alors que la plus longue tâche dure moins de 4 min. Deux causes :

1. **Le chemin critique** passe par `unit unit:1/2` (214 à 226 s, dont 172 s de tests sur 4 processus), puis `coverage` (16 à 18 s), puis `ci`.
2. **La file d'attente** : le run compte 25 tâches (`plan`, 5 `unit`, `coverage`, 6 `system`, 12 `lecons`, `ci`), dont 23 prêtes en même temps après `plan`. GitHub n'en lance que **20 à la fois** sur ce compte : 3 attendent qu'une autre finisse (+64 à +114 s). Quand la file prend une part unitaire, elle allonge d'autant le chemin critique (run 41916186112 : `unit:1/2` démarre à +188 s, horloge 408 s).

## Pour qui

Le porteur et chaque session qui pousse un train : la promotion attend le statut `ci`.

## Pourquoi maintenant

Deux trains par jour en moyenne ; chaque minute de file ou de chemin critique se paie à chaque train, et la suite grandit (contenus).

## Mesure avant

Runner `ubuntu-latest`, suite unitaire 8 133 tests, 498 fichiers de leçons, tirage `full`. Méthode : `list_workflow_jobs` du run, horloge = dernier `completed_at` − premier `created_at` ; durée d'une tâche = `completed_at − started_at` ; départ = `started_at` − premier `created_at`.

| Run | Arbre | Horloge | `unit:1/2` (départ / durée) | `coverage` | Tâches en file (départ) |
|---|---|---|---|---|---|
| 41921296454 (train #476) | `07c3735` | **293 s** | +17 s / 226 s | 16 s | `perf:1/2` +80, `lecons 9/12` +82, `system 5/6` +130 |
| 41917971824 (preuve #480) | `878c667` | **260 s** | +18 s / 214 s | 18 s | `perf:2/2` +81, `lecons 5/12` +119, `perf:1/2` +124 |
| 41916186112 (preuve #480) | `53432fe` | **408 s** | +188 s / 193 s | 17 s | 20 tâches en file, autre run en cours |

Médiane : **293 s**. Détail d'une tâche (run 41921296454) :

| Tâche | Mise en place (checkout, PostgreSQL, setup) | `bin/setup` + `test:prepare` | Tests | Total |
|---|---|---|---|---|
| `unit unit:1/2` | 23 s | 24 s | 172 s (2 937 tests, 4 processus) | 226 s |
| `lecons 1/12` | 22 s | 29 s | 27 s de démarrage + 72 s (36 leçons, ≈ 2,1 s chacune) | 155 s |
| `system 5/6` | 23 s | ≈ 22 s | ≈ 107 s | 157 s |

Somme des 12 étapes `lecons` du run : 1 291 s, dont ≈ 56 s fixes par part : ≈ 620 s de leçons à partager.

## Cible

| Métrique | Avant | Cible |
|---|---|---|
| Horloge d'un train (médiane de ≥ 3 runs, tirage `full`) | 293 s | **< 210 s** |
| Plus longue tâche | 226 s | ≤ 300 s (ADR-0107), visé < 180 s |
| Tâches en file | 3 sur 25 | 0 |
| Couverture de la suite entière | 100 % / 100 % | 100 % / 100 %, inchangée |
| Tests joués | tous | tous : aucun sauté, désactivé ni en quarantaine |

Protocole après : PR de preuve temporaire vers `Staging` (comme #480), fermée ensuite ; ≥ 3 exécutions (tentatives relancées), même méthode, médiane.

## Leviers

- **A** : la suite unitaire en trois parts (`UNIT_PARTS = 3`). Estimation : (172 + 150) / 3 ≈ 107 s de tests + 47 s fixes ≈ 155 s par part.
- **B** : `lecons` en 7 parts au lieu de 12 : 620 / 7 ≈ 89 s de leçons + 78 s fixes ≈ 167 s par part ; 6 `unit` + 6 `system` + 7 `lecons` = **19 tâches** prêtes ensemble, sous la limite de 20 (une place libre pour un autre run). 6 parts (proposition initiale) donneraient ≈ 181 s et feraient de `lecons` le chemin critique ; 8 parts rempliraient exactement les 20 places.
- **C** (processus) : documenter que la fusion dans `main` du 2026-11-04 (#474, `c015125d`) n'a déclenché aucun déploiement Railway.
- **D** (seulement si A + B manquent la cible) : préparer les assets une fois et les partager par artefact.

## Hors périmètre

- Accélérer les tests eux-mêmes (fixtures, démarrage de Chrome, import des leçons).
- `bin/ci` / `bin/ci-quiet` en local : rien ne change.
- La promotion `Staging → main` (≈ 30 s, arbre déjà prouvé).
- Relever le plafond de 5 minutes ou la limite de 20 tâches (plan GitHub : décision du porteur).
- Les décisions du chantier `crm-ecoles` (#465).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| La file d'attente vient-elle d'autres runs ? | Non pour #476 et #480 (`878c667`) : 20 tâches partent à +16 s, les autres attendent dans le même run. Oui pour `53432fe`, où un autre run occupait des places. | Garder une place libre : 19 tâches, pas 20. |
| Six parts de leçons suffisent-elles ? | Non pour la cible : ≈ 181 s, chemin critique. | 7 parts. |
| Trois parts unitaires équilibrées ? | Oui : 370 s enregistrées chacune (`CI_PLAN.split("unit", 3)`, perf des imports hors poids). | `UNIT_PARTS = 3`. |

## Cas limites identifiés

- Un run concurrent (autre PR vers `Staging` ou `main`) reprend des places : la file revient, le verdict reste juste.
- Les leçons grandissent (chantiers de contenus) : à ≈ 2,1 s la leçon, une part de 7 reste sous 5 min jusqu'à ≈ 1 000 fichiers.

## Questions encore ouvertes

- Aucune.
