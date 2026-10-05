# Plan d'exécution — Organisation des écrans enseignant

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

Aucune migration, aucun port, aucune entité : le Lot 0 ne porte que les fichiers partagés. Les quatre lots sont petits ; un seul exécutant les enchaîne dans l'ordre A → D, dans la branche du chantier (pas de worktree).

## Graphe

```
Lot 0 — SOCLE (ordre de l'accueil, locales)
  ↓
  ├─► Lot A  accueil : bande des classes, annonces, exercices à suivre ┐
  ├─► Lot B  catalogue : portée de l'enseignant, recherche cachée     ├─ fichiers disjoints
  ├─► Lot C  fiche et page exercice : ligne compacte par classe       │
  └─► Lot D  page d'une classe : ordre, bande, « Voir plus », menu ⋮  ┘
```

---

## Lot 0 — Socle

- **Couche**       : ui (fichiers partagés)
- **Fichiers**     : `app/helpers/navigation_helper.rb` (`HOME_SECTIONS[:teacher]`)
                     `config/locales/classroom/teacher_homes.fr.yml` · `config/locales/catalog/courses.fr.yml`
                     `config/locales/classroom/assignments.fr.yml` · `config/locales/classroom/classrooms.fr.yml`
                     `test/helpers/navigation_helper_test.rb`
- **Dépend de**    : —
- **Test associé** : `test/helpers/navigation_helper_test.rb`
- **Done quand**   : l'ordre des sections de l'enseignant est classes, cours, annonces, activités

---

## Lot A — Accueil enseignant (CA-1 à CA-4)

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/classroom/teacher_follow_ups_query.rb` (nouveau)
                     `app/controllers/classroom/teacher_homes_controller.rb`
                     `app/views/classroom/teacher_homes/show.html.erb` · `_classroom_card.html.erb` · `_follow_ups.html.erb` (nouveau)
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/classroom/teacher_follow_ups_query_test.rb`
                     `test/controllers/classroom/teacher_homes_controller_test.rb`
- **Done quand**   : `/teachers` montre la bande des classes, le carrousel sans croix et les exercices à suivre, 3 puis « Voir plus »

---

## Lot B — Catalogue (CA-5, CA-6)

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/catalog/teacher_audience_query.rb` (nouveau)
                     `app/infrastructure/queries/catalog/course_catalog_query.rb`
                     `app/controllers/catalog/courses_controller.rb`
                     `app/views/catalog/courses/index.html.erb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/catalog/teacher_audience_query_test.rb`
                     `test/infrastructure/queries/catalog/course_catalog_query_test.rb`
                     `test/controllers/catalog/courses_controller_test.rb`
- **Done quand**   : l'enseignant ne voit que sa matière à ses niveaux ; la recherche est cachée sous 640 px pour tous

---

## Lot C — Ligne compacte par classe (CA-7)

- **Couche**       : delivery + ui
- **Fichiers**     : `app/views/classroom/assignments/_toggle.html.erb` · `create.turbo_stream.erb` · `archive.turbo_stream.erb` · `new.html.erb`
                     `app/controllers/classroom/assignments_controller.rb`
                     `app/views/catalog/essentials/_exercise_progress.html.erb`
                     `app/views/assessment/exercises/show.html.erb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/catalog/essentials_controller_test.rb`
                     `test/controllers/classroom/assignments_controller_test.rb`
- **Done quand**   : sur la fiche, une classe tient sur une ligne ; assigner et retirer remplacent la ligne entière, échéance comprise

---

## Lot D — Page d'une classe (CA-8)

- **Couche**       : ui
- **Fichiers**     : `app/views/classroom/classrooms/show.html.erb` · `_courses.html.erb` · `_assigned_exercises.html.erb` · `_roster.html.erb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/classroom/classrooms_controller_test.rb`
- **Done quand**   : cours en bande, 3 exercices puis « Voir plus », code de récupération dans le menu ⋮ de chaque élève

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `app/helpers/navigation_helper.rb` | Lot 0 |
| `config/locales/**` | Lot 0 |
| `app/views/classroom/assignments/**` | Lot C |
| `app/views/classroom/classrooms/**` | Lot D |
| `app/views/classroom/teacher_homes/**` | Lot A |
| `app/views/catalog/courses/index.html.erb` | Lot B |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît — sans objet (aucun)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md`
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
