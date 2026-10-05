# Memo — « Travail des élèves » de la direction sous son budget

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-05 |
| **Branche** | `perf/travail-eleves-budget` |
| **Programme** | — *(suite du lot 2 de [`ecrans-direction-lents`](../ecrans-direction-lents/memo.md))* |

---

## Le problème

La direction ouvre « Travail des élèves » (`/school-admin/classrooms`) pour voir, classe par classe, combien de devoirs sont rendus et la moyenne obtenue. Sur l'établissement de référence (77 classes, 4 235 élèves), la page dépasse son budget de 100 ms p95 (ADR-0067) : **157 ms p95**. Le chantier `ecrans-direction-lents` l'avait mesurée à 230 ms sur une machine plus chargée, et avait reporté ce lot jusqu'à la fusion de #169, qui modifiait la même requête.

## Pour qui

La direction (SchoolStaff), au moment où elle fait le point sur le travail des classes : c'est l'écran qui lui dit quelles classes suivre. Sur un téléphone d'entrée de gamme et une connexion mobile, chaque milliseconde serveur s'ajoute à une attente déjà longue.

## Pourquoi maintenant

#169 (`remediation-comptee-faite`) est fusionnée le 2026-10-05 : la requête n'a plus d'autre chantier en cours dessus. Le budget de l'ADR-0067 est un engagement, pas une cible lointaine.

## Hors périmètre

- **Ce qui est affiché** : mêmes classes, mêmes taux de rendu, mêmes moyennes, même ordre. Rien ne change à l'écran.
- La page d'une classe (`/school-admin/classrooms/:id`) : déjà sous son budget (44 ms p95). Elle partage la requête et en profite, sans être la cible.
- Le décompte des élèves présents (7 ms) et le poids HTML (73,5 Ko, sous les 150 Ko).
- Tout cache : le coût est dans une requête, on corrige la requête (ADR-0067, règle du cycle).

## Mesure avant

- Base `app_lnclassapp_perf_travail` : copie de `app_lnclassapp_perf_remediation`, le jeu de l'ADR-0067 (312 283 sessions, dont 14 698 remédiations), migrée au schéma de `Develop` (`d65938c8`).
- Établissement mesuré : celui du compte de direction de mesure (`0720000001`) — 77 classes actives, 4 235 élèves présents, 754 devoirs, 29 283 sessions rendues.
- Mode production, `script/perf/measure_screens.rb`, `PERF_ONLY=admin_classrooms,admin_classroom`, protocole de l'ADR-0067 : 3 chauffes, 30 mesures, 3 exécutions, médiane des 3.
- Machine partagée de 4 cœurs : le témoin non touché (`admin_classroom`) varie de 31 % en p95 d'une exécution à l'autre.

| Métrique | Contexte / volume | Valeur avant | Cible | Comment mesurée |
|---|---|---|---|---|
| p95 « Travail des élèves » (`admin_classrooms`) | établissement de référence ci-dessus | **156,9 ms** (exécutions : 156,9 / 157,8 / 142,3) | < 100 ms | `measure_screens.rb`, 30 × 3, médiane |
| p50 « Travail des élèves » | idem | **113,3 ms** (113,3 / 96,8 / 114,8) | — | idem |
| Temps de la requête des totaux (`totals_by`) | idem | **73,4 ms** (`EXPLAIN ANALYZE`) ; 56–85 ms dans les mesures | < 35 ms | `EXPLAIN (ANALYZE, BUFFERS)` |
| Témoin : p95 page d'une classe (`admin_classroom`) | une classe de l'établissement | 54,4 ms (54,4 / 43,3 / 56,9) | inchangé ou mieux | `measure_screens.rb` |

## Mesures (Avant / Cible / Après)

Chaque levier est mesuré dans la même série que `Develop` rejoué juste avant lui ([plan § Protocole](plan.md#protocole)). Médiane de 3 exécutions × 30 mesures ; entre parenthèses, les 3 exécutions.

| Métrique | `Develop` (même série) | Cible | Après lot 1 | Après lot 2 |
|---|---|---|---|---|
| p95 « Travail des élèves » | 146,7 ms (148,7 / 143,7 / 146,7) | < 100 ms | 118,8 ms (96,1 / 127,4 / 118,8) | |
| p50 « Travail des élèves » | 103,6 ms (108,2 / 95,2 / 103,6) | — | 64,7 ms (64,7 / 69,6 / 58,6) | |
| SQL p50 de l'écran | 68,6 ms | — | 31,7 ms | |
| Requêtes SQL de l'écran | 11 | — | 11 | |
| Témoin : p95 page d'une classe | 47,2 ms (38,0 / 57,6 / 47,2) | inchangé | 45,0 ms (54,0 / 41,8 / 45,0) | |
| Chiffres affichés | — | identiques | identiques (35 035 aperçus et pages, octet pour octet) | |

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quelle métrique ? | Le p95 serveur de l'écran, celle du budget de l'ADR-0067. Le temps SQL de la requête des totaux sert à localiser et à juger chaque levier. | Deux colonnes dans les mesures : page et requête. |
| Où part le temps ? | Dans **une** requête, celle des totaux (`StudentWorkQuery#totals_by`) : 56 à 85 ms sur 98 à 115 ms. Détail dans le [journal](journal.md). | Un seul fichier à changer : `app/infrastructure/queries/school/student_work_query.rb`. |
| Pourquoi 157 ms et non 230 ms ? | Même écran, même base, même code : la machine était plus chargée le 2026-10-04 (le témoin y valait aussi plus). | La valeur avant est celle d'aujourd'hui ; la mesure après se prend dans la même série que l'avant rejoué. |
| Le résultat peut-il changer ? | Non. Le nombre d'élèves ayant rendu passe de `COUNT(DISTINCT élève)` à `COUNT(*)` : l'index unique `(classroom_id, student_id)` de `classroom_students` garantit une seule adhésion par élève et par classe. | Les tests de `StudentWorkQuery` et la comparaison ligne à ligne sur le jeu de référence le prouvent. |
| Un ADR ? | Non : levier local à une requête de lecture, aucun contrat, aucun cache, aucun callback. | — |

## Cas limites identifiés

- Un élève qui a rendu plusieurs sessions d'un même devoir (dont des remédiations) : le devoir compte une fois, toutes ses sessions comptent dans la moyenne (ADR-0072 §4.4, complément ter).
- Un élève parti de la classe ou anonymisé : ni ses devoirs ni ses scores ne comptent.
- Une classe sans aucune session rendue : absente des totaux, affichée avec 0 % et « — ».

## Questions encore ouvertes

- Aucune.
