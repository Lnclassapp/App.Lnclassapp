# Plan d'exécution — Rapports de classe : la fiche d'un élève et ce qui reste du suivi enseignant

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> **Écrit avec les recommandations du memo.** Si le porteur répond autrement à Q4 (actions sur la fiche), Q5 (pagination) ou Q6 (prochain geste), le lot concerné est amendé avant le Lot 0 ; les lignes concernées portent le numéro de la question.

## Graphe

```
Lot 0 — SOCLE (séquentiel, court)
  route GET de la fiche · locales · contrats des queries (Data, signatures) · signature de _roster
  ↓
  ├─► Lot A  Fiche d'un élève (CL-13, AS-24) + actions déplacées (Q4)   ┐
  ├─► Lot B  Liste des élèves : liens et trente par trente (CL-15)      ├─ en parallèle, fichiers disjoints
  └─► Lot C  Suivi : noms en liens et prochain geste (fin AS-22, AS-23) ┘
  ↓
Intégration — durées des tests système, mesures, recette (orchestrateur)
```

Trois lots verticaux après le socle : **trois agents** en parallèle.

---

## Lot 0 — Socle

- **Couche**       : delivery (route) + infrastructure (contrats) + i18n
- **Fichiers**     : `config/routes/classroom.rb` — GET `classrooms/:classroom_public_id/students/:student_public_id` → `classroom/classroom_students#show`, même nom `classroom_student` que le DELETE
                     `config/locales/classroom/classroom_students.fr.yml` *(nouveau : toutes les clés de l'UDR-0107 §3.10)*
                     `config/locales/classroom/classrooms.fr.yml` *(clés `roster.count_partial`, `roster.more` ; clés du menu ⋮ retirées après le Lot B : voir Intégration)*
                     `config/locales/assessment/comprehension.fr.yml` *(clés `next_step.*`, UDR-0109 §3.3)*
                     `app/infrastructure/queries/classroom/student_file_query.rb` *(squelette : constantes, `Data`, signature de `call` qui lève `NotImplementedError` — ADR-0097 §6)*
                     `app/infrastructure/queries/assessment/comprehension_detail_query.rb` *(`StudentRow` gagne `public_id`, lu par le même `pluck`)*
                     `app/infrastructure/queries/classroom/assignment_follow_up_query.rb` *(`LateStudent`, `PendingStudent` gagnent `public_id`)*
                     `app/infrastructure/queries/classroom/classroom_overview_query.rb` *(`Overview` gagne `students_total` ; `call` accepte `page:` — implémentation au Lot B ; au Lot 0, `page` est ignoré et `students_total` vaut la taille de la liste)*
                     `app/views/classroom/classrooms/_roster.html.erb` *(signature `locals:` seule, UDR-0108 §3.1 : `total:` et `page:` avec valeurs par défaut ; corps inchangé)*
- **Dépend de**    : — (réponses du porteur à Q1-Q8)
- **Test associé** : `test/infrastructure/queries/assessment/comprehension_detail_query_test.rb` et `test/infrastructure/queries/classroom/assignment_follow_up_query_test.rb` (le `public_id` est rendu) ; `test/i18n/locale_files_test.rb` (clés présentes, vocabulaire « session ») ; `bin/rails runner "puts Queries::Classroom::StudentFileQuery::File.members"`
- **Done quand**   : la suite passe sans changement de comportement ; les contrats `StudentFileQuery`, `Overview#students_total`, les `public_id` et la signature de `_roster` sont gelés ; la route de la fiche répond (action absente : `AbstractController::ActionNotFound` attendu jusqu'au Lot A). Vérifier aussi que `script/perf/dataset.rb` se sème sur une base neuve (dette D4 de `rapports-exercices`) : sinon, le noter au journal pour le Lot B

---

## Lot A — Fiche d'un élève dans sa classe (CL-13, AS-24)

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/classroom/student_file_query.rb` *(implémentation, ADR-0097 §4.1 à §4.5, §4.8)*
                     `app/controllers/classroom/classroom_students_controller.rb` *(`#show` ; `#destroy` : redirection 303 vers la page de la classe quand `params[:origin] == "file"`, Q4)*
                     `app/views/classroom/classroom_students/show.html.erb`
                     `app/views/classroom/classroom_students/_identity.html.erb`
                     `app/views/classroom/classroom_students/_summary.html.erb`
                     `app/views/classroom/classroom_students/_assignments.html.erb`
                     `app/views/classroom/classroom_students/_self_practice.html.erb`
                     `app/views/classroom/classroom_students/_manage.html.erb` *(Q4)*
                     `script/perf/measure_screens.rb` *(ajout de l'écran « fiche d'un élève »)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/classroom/student_file_query_test.rb` (présence, sessions de l'assignation seulement, remédiation, retard, badges sans `exercise_badges`, fenêtre de 30 jours aux bornes, 20 lignes et total, **même nombre de requêtes à 1 et à 10 assignations**, numéro masqué ; test croisé avec `AssignmentFollowUpQuery` et `ComprehensionDetailQuery`)
                     `test/controllers/classroom/classroom_students_controller_test.rb` (403 élève, autre enseignant, direction ; 404 absent, parti, anonymisé, classe archivée ; 200 enseignant, équipe ; destroy avec `origin=file` → 303 vers la page de la classe)
                     `test/system/classroom/student_file_test.rb` (parcours nominal à 390 px et à l'ordinateur, sans défilement horizontal ; code de récupération et retrait depuis la fiche)
- **Done quand**   : l'enseignant ouvre `/classrooms/<classe>/students/<élève>` et voit ses chiffres, ses badges de la classe, ses exercices avec état, score, catégorie et signe, son « fait seul », et peut émettre un code ou le retirer ; la fiche tient < 100 ms p95 et < 150 Ko sur le jeu de l'ADR-0067 (mesure au journal)

---

## Lot B — Liste des élèves : le nom mène à la fiche, trente par trente (CL-15)

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/classroom/classroom_overview_query.rb` *(pagination cumulative `PER_PAGE = 30`, `students_total`, lectures par élève sur les seules lignes rendues — ADR-0097 §4.7)*
                     `app/controllers/classroom/classrooms_controller.rb` *(lit `page`, entier ≥ 1, sinon 1 ; `@page`)*
                     `app/views/classroom/classrooms/_roster.html.erb` *(corps : lien vers la fiche, menu ⋮ et fenêtre retirés (Q4), compteur partiel, bouton « Voir les suivants » — UDR-0108)*
                     `test/system/classroom/classroom_roster_test.rb` · `test/system/classroom/student_removal_test.rb` *(adaptés : le retrait passe par la fiche)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/classroom/classroom_overview_query_test.rb` (30 lignes, cumul à `page: 2`, `students_total` avec et sans recherche, `page` invalide, nouveaux en tête, nombre de requêtes indépendant de la page)
                     `test/controllers/classroom/classrooms_controller_test.rb` (`page=-1`, `page=abc`, `page=0` → première page ; plus de menu ⋮ dans le HTML)
                     `test/system/classroom/classroom_roster_test.rb` (65 élèves : « 30 sur 65 », « Voir les 30 suivants », puis le bouton disparaît ; recherche + suivants ; lien vers la fiche ; 390 px)
- **Done quand**   : sur la page d'une classe de 65 élèves, l'enseignant voit 30 élèves, en ajoute 30 sans recharger la page, et ouvre la fiche d'un élève en touchant son nom ; la page de la classe mesurée par `rapports-exercices` passe sous 150 Ko (avant et après au journal)

---

## Lot C — Page de suivi : noms en liens et prochain geste (fin d'AS-22, AS-23)

- **Couche**       : domaine + ui
- **Fichiers**     : `app/domain/entities/assessment/next_step.rb` *(ADR-0097 §4.6, Q6)*
                     `app/helpers/assessment/comprehension_helper.rb` *(`comprehension_next_step(comprehension)` → `[symbole, options d'interpolation]` ou nil)*
                     `app/views/assessment/comprehension/_section.html.erb` *(noms en liens `_top`, prochain geste à la place de l'avertissement — UDR-0109)*
                     `app/views/classroom/assignment_follow_ups/show.html.erb` *(noms des rendus en retard et des pas encore faits en liens ; pas de lien sur une classe archivée)*
                     `test/system/classroom/classroom_page_test.rb` *(assertions sur les noms du suivi adaptées aux liens)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/entities/assessment/next_step_test.rb` (les sept lignes de l'ADR-0097 §4.6, bornes 4 et 5 faits, `pending` 0 et 1)
                     `test/helpers/assessment/comprehension_helper_test.rb` (interpolations `count` et `min`)
                     `test/controllers/classroom/assignment_follow_ups_controller_test.rb` (liens vers `classroom_student_path` pour les trois listes, `data-turbo-frame="_top"` dans le cadre, aucun lien sur une classe archivée, phrase attendue pour une lecture donnée)
                     `test/system/classroom/comprehension_test.rb` (un nom d'une catégorie ouvre la fiche en page entière)
- **Done quand**   : sur la page de suivi, l'enseignant touche le nom d'un élève en baisse et arrive sur sa fiche ; il lit en tête de la compréhension une phrase qui dit quoi faire, et la même phrase à chaque visite tant que la lecture ne change pas. Si Q6 = non : le lot se réduit aux liens, sans `next_step.rb` ni helper

---

## Intégration (orchestrateur, après A, B et C)

Pas un lot : les fichiers qu'aucun lot ne peut écrire seul.

- `script/ci/test_timings.yml` : durées des tests système nouveaux et modifiés (`bin/rails test <fichier> -v 2>&1 | script/ci/record_timings`), sinon `test/guards/system_budget_test.rb` échoue (défaut D5 de `rapports-exercices`).
- `config/locales/classroom/classrooms.fr.yml` : retrait des clés du menu ⋮ que plus rien ne lit (après le Lot B).
- Mesures ADR-0067 (fiche, page de la classe, page de suivi) et captures à 390 px et à l'ordinateur des trois écrans, envoyées au porteur.
- `bin/ci-quiet`, puis revue par sous-agents (une policy est lue et une route ajoutée).
- Commit de clôture : `script/docs/build_index`, `docs/chantiers/README.md`, cases de `docs/features-refonte.md` et de la feuille de route (CL-13, CL-14, CL-15, AS-21 à AS-25, parts V3 de TR-05 et TR-32), statut des ADR et UDR.

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/classroom.rb` | Lot 0 |
| `config/locales/classroom/classroom_students.fr.yml` | Lot 0 |
| `config/locales/classroom/classrooms.fr.yml` | Lot 0 (ajouts) · Intégration (retraits) |
| `config/locales/assessment/comprehension.fr.yml` | Lot 0 |
| `app/infrastructure/queries/classroom/student_file_query.rb` | Lot 0 (contrat) → Lot A (implémentation) |
| `app/infrastructure/queries/assessment/comprehension_detail_query.rb` | Lot 0 |
| `app/infrastructure/queries/classroom/assignment_follow_up_query.rb` | Lot 0 |
| `app/infrastructure/queries/classroom/classroom_overview_query.rb` | Lot 0 (contrat) → Lot B (implémentation) |
| `app/views/classroom/classrooms/_roster.html.erb` | Lot 0 (signature) → Lot B (corps) |
| `app/controllers/classroom/classroom_students_controller.rb` | Lot A |
| `app/views/classroom/classroom_students/*` (hors `destroy.turbo_stream.erb`, inchangé) | Lot A |
| `script/perf/measure_screens.rb` | Lot A |
| `app/controllers/classroom/classrooms_controller.rb` | Lot B |
| `test/system/classroom/classroom_roster_test.rb`, `student_removal_test.rb` | Lot B |
| `app/domain/entities/assessment/next_step.rb` | Lot C |
| `app/helpers/assessment/comprehension_helper.rb` | Lot C |
| `app/views/assessment/comprehension/_section.html.erb` | Lot C |
| `app/views/classroom/assignment_follow_ups/show.html.erb` | Lot C |
| `test/system/classroom/classroom_page_test.rb`, `comprehension_test.rb` | Lot C |
| `script/ci/test_timings.yml` | Intégration |

Contrat partagé à surveiller : `destroy.turbo_stream.erb` rend `_roster` ; il n'est modifié par personne et reste valide grâce aux valeurs par défaut de la signature gelée au Lot 0.

## Portes de sortie

- [ ] Q1 à Q8 répondues par le porteur, ADR-0097 et UDR-0107 à 0109 passés à « Accepté »
- [ ] Tous les lots sont `Done`
- [ ] Un rôle distinct de l'auteur a **exécuté** le résultat (tests lancés, parcours refait dans l'application, à 390 px et à l'ordinateur)
- [ ] Pureté du domaine, rubocop, tests, parcours système, brakeman : au vert (`bin/ci-quiet`, écrit dans la PR)
- [ ] Budgets mesurés et consignés au journal (fiche, page de la classe, suivi)
- [ ] ADR et UDR indexés au commit de clôture
- [ ] `journal.md` complété
