# Memo — Écrans de la direction dans leur budget

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | exécution : lot 1 (« Anciens élèves ») livré, ÷ 65 en p95 mais hors budget au protocole (136 ms) ; lots 2 et 3 à jouer ; challenger à passer |
| **Ouvert le** | 2026-10-04 |
| **Branche** | `perf/ecrans-direction-lents` |
| **Programme** | `refonte-application` — dette relevée par `remediation-comptee-faite` et `rapports-exercices` |

---

## Le problème

La direction ouvre « Anciens élèves » et attend **près de 9 secondes**. Sur un téléphone d'entrée de gamme et une connexion mobile, elle croit que la page est cassée et ne revient pas. « Travail des élèves » dépasse aussi son budget, de plus du double. L'ADR-0067 donne ces écrans comme tenus : ils ne le sont plus au volume de référence.

## Mesure avant

Mesures du 2026-10-04 (chantier `remediation-comptee-faite`) :
- base `app_lnclassapp_perf_remediation`, soit le jeu de l'ADR-0067 (312 283 sessions, dont 14 698 remédiations converties) ;
- établissement le plus grand : 77 classes, 4 235 élèves ;
- mode production, `script/perf/measure_screens.rb`, 30 mesures × 3 exécutions, médiane, sauf mention contraire ;
- machine partagée : un écran témoin non touché varie de 13 % en p95.

| Métrique | Contexte / volume | Valeur avant | Cible | Comment mesurée |
|---|---|---|---|---|
| p95 « Anciens élèves » (`admin_departed_students`) | établissement de référence | **9 158 ms** (p50 8 737 ms ; 5 mesures × 1 exécution) | < 100 ms | `measure_screens.rb` |
| p95 « Travail des élèves » | idem | **230,4 ms** (p50 156,7 ms) | < 100 ms | idem |
| HTML « Enseignants » | idem | **441,1 Ko** | < 150 Ko | idem |

D'après l'`EXPLAIN` de `remediation-comptee-faite`, le temps de « Anciens élèves » est dans la **requête de la liste** (`JOIN LATERAL` et `NOT EXISTS`), pas dans celle des totaux (6,4 ms). Pour « Travail des élèves », la lecture des sessions coûte environ 9 ms ; le reste est dans l'agrégat et le tri.

## Mesures (Avant / Cible / Après)

Lot 1 du [plan](plan.md), 2026-10-04. Base `app_lnclassapp_perf_direction`, copie du jeu de l'ADR-0067 où **303 élèves (7,2 %) ont quitté l'établissement mesuré**, dont 152 vers un autre établissement ; le jeu d'origine n'en avait aucun ([plan § Protocole](plan.md#protocole)). Mode production, `measure_screens.rb`, 3 chauffes, 30 mesures × 3 exécutions, médiane. Pour la mesure avant : 10 mesures × 3, vu leur durée.

| Métrique | Avant | Cible | Après | |
|---|---|---|---|---|
| p95 « Anciens élèves » | **8 821,2 ms** | < 100 ms | **136,1 ms** | ❌ au protocole ; **78,0 ms** une fois la page chaude (après 60 requêtes) |
| p50 « Anciens élèves » | 8 276,1 ms | — | **57,7 ms** | |
| SQL « Anciens élèves » (p50) | 8 175,2 ms | — | **23,7 ms** | liste : 17 454 → 13,0 ms sous `EXPLAIN` |
| Requêtes · HTML | 8 · 110,4 Ko | ≤ 150 Ko | 8 · 110,4 Ko | ✅ inchangés |
| p95 « Travail des élèves » | 229,0 ms (série *après*, écran non touché) | < 100 ms | — | lot 2 |
| HTML « Enseignants » | 441,1 Ko (non touché) | < 150 Ko | — | lot 3 |

Le SQL a cessé d'être le coût. Le p95 restant vient de la compilation YJIT et du GC : avec seulement 3 chauffes, ils tombent dans les 30 mesures du protocole. Voir [plan § Où part le temps restant](plan.md#où-part-le-temps-restant-p95-non-atteint).

## Pour qui

La **direction** (SchoolStaff), sur les pages de son établissement (ADR-0065). Les élèves et les enseignants ne sont pas touchés.

## Pourquoi maintenant

Un écran de 9 secondes empêche la direction d'utiliser l'espace qu'on vient de lui ouvrir (V2). L'ADR-0067 impose un chantier `optimize` à tout écran hors budget.

## Hors périmètre

- La **page classe de l'enseignant** (hors budget, liste des élèves de 147,7 Ko) : chantier `page-classe-legere`, consigné par `rapports-exercices`.
- Tout changement de ce qui est affiché ou compté. C'est une optimisation : le comportement observable reste strictement identique.
- Le cache, sauf en dernier recours et par ADR (ADR-0062 : index, puis requête, puis cache).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quel écran d'abord ? | « Anciens élèves » : 90 fois son budget. Les deux autres viennent ensuite, un levier par lot (cycle optimisation). | Lot 1 : la requête de la liste des anciens élèves. Lot 2 : l'agrégat de « Travail des élèves ». Lot 3 : le poids de « Enseignants ». |
| Le jeu de mesure est-il fiable ? | Non, pas tel quel. `script/perf/dataset.rb` ne sème ni tentative de question ni remédiation, et l'établissement mesuré n'a aucun ancien élève. | Lot 0 : rendre le jeu représentatif (anciens élèves, remédiations), puis mesurer à nouveau « avant ». |

## Cas limites identifiés

- Un établissement sans ancien élève : la liste est vide, et elle doit le rester vite.
- Le plus grand établissement du jeu (4 235 élèves).

## Questions encore ouvertes

- Aucune : décisions déléguées par le porteur (2026-10-04).
