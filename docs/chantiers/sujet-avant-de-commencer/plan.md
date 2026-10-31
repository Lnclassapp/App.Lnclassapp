# Plan d'exécution — Chaque feuille dans une case, lue avant de commencer

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — la leçon (catalogue) : cases, lecture, à remplir, retour du résultat
   │
   ▼
Lot B — la classe : page de la leçon dans la classe (enseignant) et « Ma classe » (devoirs reçus)
```

Pas de Lot 0 : aucune migration, aucun port, aucune entité. Les fichiers partagés (la case, la feuille en lecture, la feuille CSS, la locale des feuilles, la vérification et la page de résultat) appartiennent au Lot A ; le Lot B les **utilise** sans les modifier, et part une fois le Lot A commité. Séquentiel : B a besoin de la case et du mode lecture de A.

---

## Lot A — La leçon montre des cases ; chaque feuille se lit, puis se remplit

- **Couche**       : delivery + ui (requête de la leçon : choisir une feuille par son ancre)
- **Fichiers**     : `config/routes/catalog.rb` (`courses/:course_slug/feuilles/:sheet` et `…/remplir`)
                     `app/controllers/catalog/prepare_sheets_controller.rb` (nouveau : `show` lecture, `fill` à remplir ; policy de la leçon ; feuille inconnue → leçon + flash ; enseignant et équipe sur `fill` → lecture)
                     `app/infrastructure/queries/catalog/prepare_sheets_query.rb` (`Prepare#sheet(dom_id)`)
                     `app/views/catalog/prepare_sheets/show.html.erb` · `fill.html.erb` (nouveaux)
                     `app/views/catalog/courses/_prepare_sheets.html.erb` (des cases à la place des feuilles)
                     `app/views/catalog/courses/sheets/_card.html.erb` (nouveau)
                     `app/views/catalog/courses/sheets/_sheet.html.erb` · `_exercise.html.erb` (`mode: :reading` ; `sheet` posté avec la vérification)
                     `app/assets/stylesheets/prepare_sheet.css` (`.ps-cards`, `.ps-card`, `.ps-start`)
                     `config/locales/catalog/courses.fr.yml` (case, « Commencer / Continuer … », « Cette feuille n'existe plus. », retours)
                     `app/controllers/assessment/sheet_checks_controller.rb` · `app/views/assessment/sheet_checks/create.turbo_stream.erb` (transmettre `sheet`)
                     `app/controllers/assessment/session_results_controller.rb` · `app/views/assessment/session_results/show.html.erb` (retour à la feuille à remplir, `sheet` validé)
                     `app/controllers/assessment/exercise_copies_controller.rb` · `app/views/assessment/exercises/show.html.erb` (leurs liens `#sheet-exercise-…` vers la page à remplir)
                     tests existants qui passent par la feuille de la leçon : `test/controllers/catalog/courses_controller_test.rb`, `test/controllers/assessment/{sheet_checks,session_results,exercise_copies,exercises}_controller_test.rb`, `test/integration/catalog/prepare_interros_test.rb`, `test/integration/classroom/gaps_link_test.rb`, `test/system/catalog/{prepare_interros,prepare_sheets}_test.rb`, `test/system/assessment/{sheet_check,exercise_cards,remediation}_test.rb`, `test/system/boucle_pedagogique_test.rb`, `test/system/classroom/{catalog_assignment,assignment_toggle,assignment_batch}_test.rb`, `test/integration/classroom/assign_from_lesson_test.rb`
- **Dépend de**    : —
- **Test associé** : `test/controllers/catalog/prepare_sheets_controller_test.rb` (nouveau : lecture, à remplir, feuille inconnue, enseignant redirigé, leçon non publiée refusée)
                     `test/system/catalog/sheet_cards_test.rb` (nouveau : cases → lecture → Commencer → vérifier → retour à la feuille → « Continuer » et progrès sur la case)
                     `test/infrastructure/queries/catalog/prepare_sheets_query_test.rb` (`sheet(dom_id)`)
- **Done quand**   : sur Thalès, à 390 px, l'élève voit 8 cases ; « Prépare devoirs n°2 » montre le sujet en lecture, « Commencer » ouvre la feuille à remplir, la page de résultat y ramène ; la case dit « 1 / 4 » et le bouton « Continuer » ; l'enseignant (catalogue) lit le sujet avec ses bascules, sans « Commencer ».
- **Critères du PRD** : 1, 2, 3, 4, 5, 8 ; 6 pour la page du catalogue.

---

## Lot B — La classe : la leçon dans la classe et « Ma classe » en cases

- **Couche**       : delivery + ui (requête des devoirs reçus : choisir une feuille par son ancre)
- **Fichiers**     : `config/routes/classroom.rb` (`classrooms/:classroom_public_id/courses/:course_slug/feuilles/:sheet` ; `students/classroom/devoirs/:sheet` et `…/remplir`)
                     `app/controllers/classroom/classroom_prepare_sheets_controller.rb` (nouveau : lecture enseignant, policy de la classe)
                     `app/controllers/classroom/student_assigned_sheets_controller.rb` (nouveau : `show` lecture, `fill` à remplir, élève seulement ; devoir inconnu ou d'une autre classe → « Ma classe » + flash)
                     `app/infrastructure/queries/classroom/student_assigned_sheets_query.rb` (choisir une feuille par son ancre)
                     `app/views/classroom/classroom_prepare_sheets/show.html.erb` · `app/views/classroom/student_assigned_sheets/{show,fill}.html.erb` (nouveaux)
                     `app/views/classroom/classroom_courses/show.html.erb` (rend les cases, vers la feuille dans la classe)
                     `app/views/classroom/student_classrooms/_assigned_sheets.html.erb` (des cases à la place des feuilles)
                     `config/locales/classroom/classroom_courses.fr.yml` · `config/locales/classroom/student_classrooms.fr.yml` (libellés des cases et des retours)
                     tests existants : `test/controllers/classroom/{classroom_courses,student_classrooms}_controller_test.rb`, `test/system/classroom/assigned_sheets_test.rb`
- **Dépend de**    : Lot A
- **Test associé** : `test/controllers/classroom/classroom_prepare_sheets_controller_test.rb`, `test/controllers/classroom/student_assigned_sheets_controller_test.rb` (nouveaux : lecture, à remplir, devoir d'une autre classe refusé)
                     `test/system/classroom/assigned_sheet_cards_test.rb` (nouveau : case du devoir → lecture → Commencer → « Rendre à l'enseignant » → retour à la feuille)
- **Done quand**   : l'enseignant, dans sa classe, voit les cases et lit le sujet avec ses bascules limitées à cette classe ; l'élève voit dans « Ma classe » une case par devoir reçu, le lit, le commence, le rend, et la page de résultat le ramène à la feuille du devoir.
- **Critères du PRD** : 6 (page de la classe), 7, 9.

---

## Vérification de collision

Lots séquentiels : aucun fichier n'est modifié par les deux.

| Fichier | Lot propriétaire |
|---|---|
| `app/views/catalog/courses/sheets/_card.html.erb`, `_sheet.html.erb`, `_exercise.html.erb` | Lot A (B les rend sans les modifier) |
| `app/assets/stylesheets/prepare_sheet.css` | Lot A |
| `config/locales/catalog/courses.fr.yml` | Lot A |
| `app/controllers/assessment/sheet_checks_controller.rb`, `session_results_controller.rb` et leurs vues | Lot A (le retour `class` + `sheet` y est prévu pour B) |
| `config/routes/catalog.rb` | Lot A |
| `config/routes/classroom.rb` | Lot B |

Si le Lot B a besoin de changer un fichier du Lot A, il s'arrête et remonte.

## Dispatch

```
Vague 1 : Lot A → 1 agent (executant-lot)
Vague 2 : Lot B → 1 agent (executant-lot), après le commit du Lot A sur la branche du chantier
```

## Portes de sortie

- [ ] Tous les lots sont `Done`
- [ ] Un rôle distinct de l'auteur a **exécuté** le résultat (tests lancés, parcours refait dans l'application)
- [ ] Pureté du domaine, rubocop, tests, parcours système : au vert
- [ ] ADR et UDR à jour et indexés
- [ ] `journal.md` complété
- [ ] Captures envoyées au pilote : chaque écran modifié à 390 px et sur ordinateur

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Ici : il ouvre Thalès en élève, parcourt case → lecture → Commencer → vérifier → retour → « Continuer » ; ouvre `/courses/<thales>/feuilles/sujet-9` (message, pas d'erreur) ; ouvre en enseignant la page à remplir (redirigé vers la lecture) ; rend un devoir reçu depuis « Ma classe » ; mesure la hauteur de la page de Thalès à 390 px avant et après.
