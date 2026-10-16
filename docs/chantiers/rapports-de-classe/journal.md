# Journal — Rapports de classe : la fiche d'un élève et ce qui reste du suivi enseignant

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-16 | Le chantier ne garde que ce qui manque : fiche élève (CL-13, AS-24), liens vers elle (fin d'AS-22), pagination (CL-15), prochain geste (AS-23) | Inventaire du code : AS-21, AS-25 et l'essentiel d'AS-22 livrés par `rapports-exercices` ; « Activités » de l'accueil par `interface-enseignant-organisation` ; aucun cache par ADR-0079 | Non (memo, Q1) |
| 2026-10-16 | Aucune policy nouvelle : la fiche suit `ReadClassroomPolicy` avec `show_roster` | Ceux qui lisent la liste lisent la fiche | ADR-0097 §4.2 |
| 2026-10-16 | « Fait », retard, catégorie et signe de la fiche viennent des mêmes queries que la page de suivi | Un seul chiffre par fait | ADR-0097 §4.3 |
| 2026-10-16 | **Décisions prises sur recommandation, à confirmer par le porteur (questions RAP-1 à RAP-8, memo Q1 à Q8).** Le porteur n'a pas répondu ; il a demandé de lancer les lots en autonomie. Le code applique la recommandation de chaque question : Q1 features livrées fermées ; Q2 fiche en deux sections (exercices de la classe, « fait seul » 30 jours) ; Q3 badges de la classe ; Q4 code de récupération et retrait sur la fiche ; Q5 trente puis « Voir les suivants » ; Q6 prochain geste en six cas ; Q7 **aucun chiffre de classe ajouté, CL-14 considérée livrée** ; Q8 `public_id` dans le HTML du suivi. ADR-0097 et UDR-0107 à 0109 restent « Proposé » | Consigne du porteur : avancer sans bloquer sur les questions | Non |
| 2026-10-16 | **Réponses du porteur (memo, f8dfce89)** : recommandations acceptées, **sauf Q5** ; Q7 confirmée (pas de moyenne de classe). La décision « sur recommandation » ci-dessus est donc confirmée pour Q1-Q4, Q6-Q8 ; ADR et UDR restent « Proposé » jusqu'à la clôture | Réponse transmise en cours de Lot B ; Develop fusionnée dans la branche | Non |
| 2026-10-16 | **Lot B, Q5 amendée par le porteur** : la liste des élèves se découpe **par note sur 20** (0–10, 11–15, 16–20, « Pas encore de note »), note = moyenne des meilleurs scores aux exercices assignés actifs de la classe, `Grading.grade_on_20` ; sélecteur à liens (`?note=0-10`), premier groupe non vide par défaut ; trente puis « Voir les suivants » dans un groupe ; recherche sur toute la classe. Règle `Entities::Classroom::RosterGrade` ; notes lues en une requête | Décision du porteur du 2026-10-16 | UDR-0108 §3.8, ADR-0097 §4.7 (amendements), PRD |
| 2026-10-16 | Lot B : une colonne « Note » (12/20) sur chaque ligne de la liste | Le groupe ne dit qu'un intervalle ; la note de l'élève dit où il en est | UDR-0108 §3.8 |
| 2026-10-16 | Lot B : la phrase d'aide du code de récupération quitte la liste (elle est sur la fiche) | L'action n'est plus sur la liste | Non |
| 2026-10-16 | Lot B : les clés du menu ⋮ et de la fenêtre de retrait de la liste sont supprimées (`actions_label`, `issue_code`, `issue_code_hint`, `remove*`, `cancel`), avec `open_file`, jamais lue ; `removed` (toast) reste | Plus rien ne les lit ; l'Intégration n'a plus à le faire | UDR-0108 §3.7 |
| 2026-10-16 | Lot 0 : deux contrats de plus que le plan, gelés au socle parce que la fiche les lit — `AssignmentScores.for(student_id:)` (scores d'un seul élève, même définition) et `ClassroomOverviewQuery.self_practice(today, days:)` (la fiche lit 30 jours, la liste 7, une seule définition) | Ne rien réinventer (ADR-0097 §2.3) : la fiche réutilise les définitions au lieu de les recopier | Non |
| 2026-10-16 | Lot A : la phrase d'aide du code de récupération (« Un élève qui a perdu son code secret… ») suit l'action sur la fiche, en tête de « Gérer » ; l'UDR-0107 §3.6 ne la mentionnait pas | Elle explique une action qui quitte la liste (Q4) | Non |
| 2026-10-16 | Lot A : « Fait le » d'un exercice fait est la date de la **première** session faite (`first_done`), comme le retard ; le score affiché est le meilleur | Une seule définition de la date, celle du suivi (ADR-0072 §4.4) | Non |
| 2026-10-16 | Lot 0 : les clés de `classroom_students.fr.yml` sont rangées par partial (`show`, `identity`, `summary`, `assignments`, `self_practice`, `manage`), et non toutes sous `show` comme l'écrit l'UDR-0107 §3.10 | Règle d'or I18n : `t(".clé")` dans chaque partial, dont la portée est celle du partial | Non |
| 2026-10-16 | Lot C : le nom d'un élève du suivi passe par un seul helper, `comprehension_student_name(student, classroom)`, pour les trois listes (catégorie, rendus en retard, pas encore faits) : lien `_top` vers la fiche, texte seul dans une classe archivée | Une règle (UDR-0109 §3.1, §3.4) écrite une fois ; la vue ne teste pas le statut de la classe | Non |
| 2026-10-16 | Lot C : la clé `assessment.comprehension.unreliable` est supprimée ; le prochain geste `:remind` / `:look_at_each` dit la borne à sa place | Plus rien ne la lit (UDR-0109 §3.3) | Non |

## Ce qui a dérapé

- **Lot 0 — jeu de mesure de l'ADR-0067 cassé une deuxième fois (dette D4).** Sur une base neuve, `script/perf/dataset.rb` s'arrêtait à `teacher_profiles.joined_via` (non nul, sans défaut) ; `classroom_students.joined_via` aurait suivi. Réparé : `joined_via: "standard"` pour les deux. Il ne semait toujours aucune tentative de question : ajout de `seed_attempts` (une tentative par question répondue, juste pour les `correct_count` premières). Semé en 183 s : 312 065 sessions, **1 452 043 tentatives**, 40 000 élèves.
- **La page de la classe a encore grossi depuis `rapports-exercices`** : 403,6 Ko mesurés au Lot 0 (et non 231,6 Ko), dont **320,1 Ko pour la liste des élèves** (55 lignes, 58 `<dialog>`). Mesure « avant » ci-dessous.
- **Lots B et C — durées des tests système mesurées sur une machine chargée** (charge de 17 à 30 pour 4 cœurs, une dizaine d'agents). Au Lot B, les six fichiers relancés ont pris 2,47 fois leur durée enregistrée (155 s contre 62,7 s, nouveau test exclu) : `script/ci/test_timings.yml` reçoit les durées mesurées divisées par 2,47 (croissance : + 3,8 s). Au Lot C, `comprehension_test.rb` gagne un clic et une page (la fiche) : 7,9 → 8,5 s estimés. `boucle_pedagogique_test.rb` a échoué deux fois sous cette charge, à deux endroits différents et antérieurs au passage modifié (inscription de l'enseignant, publication d'un cours) : sa durée reste celle de `Develop`, à confirmer par `bin/ci-quiet`.

## Mesures (ADR-0067, jeu `script/perf/dataset.rb`, mode production, 30 requêtes après 3 de chauffe)

| Écran | Moment | p50 ms | p95 ms | Requêtes | HTML Ko | gzip Ko |
|---|---|---|---|---|---|---|
| Page de la classe (55 élèves) | avant (Lot 0) | 92,2 | 138,6 | 23 | 402,2 | 25,2 |
| Page de suivi | avant (Lot 0) | 34,0 | 54,4 | 19 | 52,6 | 8,4 |
| Page de suivi, cadre « Fragile » | avant (Lot 0) | 25,5 | 36,1 | 15 | 21,9 | 3,5 |
| Fiche d'un élève (8 exercices actifs, 10 sessions ; 60 requêtes mesurées) | Lot A | 31,5 | 49,0 | 19 | 55,4 | 10,5 |
| Page de la classe, groupe ouvert par défaut (10 élèves) | Lot B (machine chargée, charge ≈ 16) | 80,0 | 151,8 | 25 | 114,2 | 15,3 |

Lot B : la liste des élèves passe de 320,1 Ko (55 lignes, 58 `<dialog>`) à 33,2 Ko (un groupe de 10 lignes), la page de 402,2 à 114,2 Ko ; les allocations de 97 485 à 36 248, le temps de vue p50 de 54,3 à 28,5 ms. La requête des notes coûte 0,4 ms (`EXPLAIN ANALYZE`, index `index_classroom_assignments_on_classroom_id` puis `index_exercise_sessions_handed_in`). Les p95 de cette session sont faussés par la charge de la machine partagée (autres agents) : à re-mesurer au calme.

Le nombre de requêtes SQL de la fiche ne dépend pas du nombre d'assignations : vérifié par `student_file_query_test.rb` (même compte à 1 et à 10 assignations). Le jeu ne donne que 8 assignations actives à la classe mesurée (10 semées, dont 2 archivées).

Lot C : la page de suivi passe de 52,6 à 60,5 Ko (noms en liens, prochain geste), le cadre « Fragile » de 21,9 à 28,7 Ko, au même nombre de requêtes (19 et 15). Les temps de cette mesure (charge ≈ 30 pour 4 cœurs) ne sont pas lisibles : suivi p50 116,5 / p95 184,0 ms, cadre 64,4 / 87,7 ms, et la page de la classe, inchangée par le lot, mesurée en même temps à 102,6 / 178,2 ms contre 80,0 / 151,8 au Lot B.

## Ce qu'on a appris sur la codebase

- `script/ci/record_timings` ne lit pas la durée du premier test système d'un lancement : la bannière de Puma s'imprime sur la même ligne que son nom. Durée du nouveau `student_file_test.rb` (4,2 s) inscrite à la main.
- La suite unitaire complète exige 100 % de lignes et de branches (`test/test_helper.rb`) : tout Ruby nouveau de `app/` est couvert par les tests unitaires et de contrôleur, jamais par les tests système (`COVERAGE=0`).

- `ClassroomHeaderQuery::Row` n'expose pas l'`id` de la classe : une query qui en part prend le `public_id`.
- `ClassroomStudentsController` admet aussi la direction (`school_admin`) pour le retrait ; `#show` doit la refuser par la policy, pas par `allow_roles`.
- La liste d'une catégorie vit dans le Turbo Frame `comprehension_frame` : tout lien vers une autre page y demande `data-turbo-frame="_top"`.
- La fenêtre de retrait de chaque ligne de la liste est rendue même fermée : elle pèse sur chaque ligne de la page de la classe.
- `exercise_badges` garde le record d'un élève toutes classes confondues (index unique `student_id, exercise_id`) : il ne peut pas servir une lecture par classe.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Lacunes et remédiations d'un élève sur sa fiche | V5 (AS-17) | `remediation` |
| Retour de la page de résultat vers la fiche | La page de résultat a un seul lien de retour (UDR-0023) | — |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | ADR-0097 (Proposé) |
| **UDR produits** | UDR-0107, UDR-0108, UDR-0109 (Proposé) |
