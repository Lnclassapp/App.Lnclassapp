# Journal — Rapports de classe : la fiche d'un élève et ce qui reste du suivi enseignant

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-16 | Le chantier ne garde que ce qui manque : fiche élève (CL-13, AS-24), liens vers elle (fin d'AS-22), pagination (CL-15), prochain geste (AS-23) | Inventaire du code : AS-21, AS-25 et l'essentiel d'AS-22 livrés par `rapports-exercices` ; « Activités » de l'accueil par `interface-enseignant-organisation` ; aucun cache par ADR-0079 | Non (memo, Q1) |
| 2026-10-16 | Aucune policy nouvelle : la fiche suit `ReadClassroomPolicy` avec `show_roster` | Ceux qui lisent la liste lisent la fiche | ADR-0097 §4.2 |
| 2026-10-16 | « Fait », retard, catégorie et signe de la fiche viennent des mêmes queries que la page de suivi | Un seul chiffre par fait | ADR-0097 §4.3 |
| 2026-10-16 | **Décisions prises sur recommandation, à confirmer par le porteur (questions RAP-1 à RAP-8, memo Q1 à Q8).** Le porteur n'a pas répondu ; il a demandé de lancer les lots en autonomie. Le code applique la recommandation de chaque question : Q1 features livrées fermées ; Q2 fiche en deux sections (exercices de la classe, « fait seul » 30 jours) ; Q3 badges de la classe ; Q4 code de récupération et retrait sur la fiche ; Q5 trente puis « Voir les suivants » ; Q6 prochain geste en six cas ; Q7 **aucun chiffre de classe ajouté, CL-14 considérée livrée** ; Q8 `public_id` dans le HTML du suivi. ADR-0097 et UDR-0107 à 0109 restent « Proposé » | Consigne du porteur : avancer sans bloquer sur les questions | Non |
| 2026-10-16 | Lot 0 : deux contrats de plus que le plan, gelés au socle parce que la fiche les lit — `AssignmentScores.for(student_id:)` (scores d'un seul élève, même définition) et `ClassroomOverviewQuery.self_practice(today, days:)` (la fiche lit 30 jours, la liste 7, une seule définition) | Ne rien réinventer (ADR-0097 §2.3) : la fiche réutilise les définitions au lieu de les recopier | Non |
| 2026-10-16 | Lot A : la phrase d'aide du code de récupération (« Un élève qui a perdu son code secret… ») suit l'action sur la fiche, en tête de « Gérer » ; l'UDR-0107 §3.6 ne la mentionnait pas | Elle explique une action qui quitte la liste (Q4) | Non |
| 2026-10-16 | Lot A : « Fait le » d'un exercice fait est la date de la **première** session faite (`first_done`), comme le retard ; le score affiché est le meilleur | Une seule définition de la date, celle du suivi (ADR-0072 §4.4) | Non |
| 2026-10-16 | Lot 0 : les clés de `classroom_students.fr.yml` sont rangées par partial (`show`, `identity`, `summary`, `assignments`, `self_practice`, `manage`), et non toutes sous `show` comme l'écrit l'UDR-0107 §3.10 | Règle d'or I18n : `t(".clé")` dans chaque partial, dont la portée est celle du partial | Non |

## Ce qui a dérapé

- **Lot 0 — jeu de mesure de l'ADR-0067 cassé une deuxième fois (dette D4).** Sur une base neuve, `script/perf/dataset.rb` s'arrêtait à `teacher_profiles.joined_via` (non nul, sans défaut) ; `classroom_students.joined_via` aurait suivi. Réparé : `joined_via: "standard"` pour les deux. Il ne semait toujours aucune tentative de question : ajout de `seed_attempts` (une tentative par question répondue, juste pour les `correct_count` premières). Semé en 183 s : 312 065 sessions, **1 452 043 tentatives**, 40 000 élèves.
- **La page de la classe a encore grossi depuis `rapports-exercices`** : 403,6 Ko mesurés au Lot 0 (et non 231,6 Ko), dont **320,1 Ko pour la liste des élèves** (55 lignes, 58 `<dialog>`). Mesure « avant » ci-dessous.

## Mesures (ADR-0067, jeu `script/perf/dataset.rb`, mode production, 30 requêtes après 3 de chauffe)

| Écran | Moment | p50 ms | p95 ms | Requêtes | HTML Ko | gzip Ko |
|---|---|---|---|---|---|---|
| Page de la classe (55 élèves) | avant (Lot 0) | 92,2 | 138,6 | 23 | 402,2 | 25,2 |
| Page de suivi | avant (Lot 0) | 34,0 | 54,4 | 19 | 52,6 | 8,4 |
| Page de suivi, cadre « Fragile » | avant (Lot 0) | 25,5 | 36,1 | 15 | 21,9 | 3,5 |
| Fiche d'un élève (8 exercices actifs, 10 sessions ; 60 requêtes mesurées) | Lot A | 31,5 | 49,0 | 19 | 55,4 | 10,5 |

Le nombre de requêtes SQL de la fiche ne dépend pas du nombre d'assignations : vérifié par `student_file_query_test.rb` (même compte à 1 et à 10 assignations). Le jeu ne donne que 8 assignations actives à la classe mesurée (10 semées, dont 2 archivées).

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
