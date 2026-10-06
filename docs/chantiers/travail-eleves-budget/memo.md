# Memo — « Travail des élèves » de la direction sous son budget

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | livré (#173, fusionnée dans `Develop` le 2026-10-05 ; lot 1) — lot 2 retiré à la fusion de #167 |
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

### Ce qui est livré : lot 1, sur la base de `Develop` après #167

Pendant le chantier, #167 (`accueil-direction`) a transformé l'écran : le tableau des classes de « Travail des élèves » est devenu **l'accueil de la direction**, dont les chiffres sont **gardés 5 minutes** par établissement (ADR-0065, amendement du 2026-10-04), et une **page par niveau**, lue en direct. `StudentWorkQuery` sert ces deux écrans et la page d'une classe. Le lot 2 a été retiré à la fusion (#167 compte les élèves présents autrement) ; seul le lot 1 est livré.

Mesure finale, 2026-10-05 : `f75011c7` (`Develop` juste avant #173) contre la branche, seul le fichier de la query changeant ; même base, protocole de l'ADR-0067, **2 séries alternées × 3 exécutions × 30 mesures, médiane des 6**. La page d'un niveau est mesurée sur le niveau le plus fourni de l'établissement (« 1ère », 24 classes) ; l'accueil, cache vidé avant chaque requête (`PERF_COLD=1`).

| Écran | Avant p50 / p95 / SQL | Après p50 / p95 / SQL | Écart p50 / SQL | Budget p95 < 100 ms |
|---|---|---|---|---|
| Accueil de la direction, **cache vide** (1 lecture toutes les 5 minutes par établissement) | 115,3 / 167,0 / 75,1 ms | **85,8 / 141,8 / 47,0 ms** | **−26 % / −37 %** | non (avant non plus) ; ces requêtes ne sont qu'une sur cinq minutes |
| Accueil de la direction, cache chaud (les autres visites) | 28,0 / 82,1 ms | inchangé (la query n'est pas appelée) | — | **oui** |
| Page d'un niveau (24 classes), en direct | 60,0 / 112,3 / 27,2 ms | **53,2 / 106,7 / 19,5 ms** | **−11 % / −28 %** | non (avant non plus) |
| Chiffres affichés | — | **identiques** : 38 485 aperçus, pages de niveau et pages de classe du jeu, octet pour octet | | |

### Historique : lots 1 et 2, sur l'ancien écran (`Develop` `d65938c8`, avant #167)

| Métrique | Avant | Après (lots 1 et 2) | Challenger (12 exécutions par côté) |
|---|---|---|---|
| p50 « Travail des élèves » | 102,5 ms | 61,7 ms | 97,8 → 53,8 ms (−45 %) |
| p95 | 160,4 ms | 132,6 ms | 152,4 → 101,5 ms |
| SQL p50 | 67,3 ms | 29,6 ms | 64,6 → 26,8 ms (−59 %) |
| Requête des totaux (`EXPLAIN ANALYZE`) | 73,4 ms | 27,9 ms | 74,4 → 33,8 ms |

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
