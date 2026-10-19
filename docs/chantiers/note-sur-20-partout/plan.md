# Plan d'exécution — La note sur 20 décide partout

> Deux lots, séquentiels : le second lit ce que le premier pose (`Grading.reaches?`). Format des lots : [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot 1 — La règle, dans le domaine
  ↓
Lot 2 — Les écrans et leurs textes
```

---

## Lot 1 — La règle, dans le domaine

- **Couche**       : domaine + infrastructure (une query)
- **Fichiers**     : `app/domain/entities/assessment/grading.rb` (`reaches?`, `perfect?`, `badge_for`, `mastery_for`)
                     `app/domain/entities/assessment/gap_decision.rb`
                     `app/domain/entities/assessment/comprehension.rb`
                     `app/infrastructure/queries/classroom/classroom_essential_query.rb`
                     `docs/decisions/adr/0106-…`, `0033-…`, `0101-…`, `README.md` des ADR · `docs/chantiers/note-sur-20-partout/{memo,prd,plan}.md`
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/assessment/{grading,gap_decision,comprehension}_test.rb`
                     `test/infrastructure/queries/classroom/classroom_essential_query_test.rb`
                     `test/infrastructure/queries/assessment/{comprehension_summary,comprehension_detail,exercise_progress,session_result}_query_test.rb`
- **Done quand**   : aux bornes (47/48, 67/68, 72/73, 77/78, 98/99/100 %) badge, maîtrise, « à revoir », « stable » et élèves en réussite suivent la note sur 20 ; aucune règle de `app/` ne compare un score brut à un seuil, hors `Grading.perfect?`

---

## Lot 2 — Les écrans et leurs textes

- **Couche**       : ui
- **Fichiers**     : `app/helpers/assessment/badges_helper.rb` (`badges_tip`, `mastery_tip`)
                     `app/views/assessment/exercises/_student_progress.html.erb` · `app/views/assessment/session_results/{show,_badge}.html.erb`
                     `app/views/classroom/student_archives/_result_row.html.erb` · `app/views/classroom/student_homes/_recent_activity.html.erb` · `app/views/classroom/student_classrooms/_treated_exercise.html.erb`
                     `app/views/communication/help/show.html.erb`
                     `config/locales/shared/layouts.fr.yml` · `config/locales/communication/help.fr.yml`
                     `docs/decisions/udr/0131-…` · `docs/chantiers/note-sur-20-partout/journal.md` · index ADR / UDR (`script/docs/build_index`) · index des chantiers (une seule fois, à la clôture)
- **Dépend de**    : Lot 1
- **Test associé** : `test/helpers/assessment/badges_helper_test.rb` · `test/controllers/communication/help_controller_test.rb` · `test/system/finitions/catalog_and_student_test.rb` · `test/system/assessment/session_result_test.rb`
- **Done quand**   : les infobulles « Badge » et « Maîtrise » et la FAQ disent des notes sur 20 calculées depuis `Grading` ; aucune vue ne recopie `grade_on_20(x) >= grade_on_20(seuil)` ; captures à 390 px et sur ordinateur montrées au porteur

---

## Vérification de collision

Aucun fichier n'est listé dans les deux lots.

## Portes de sortie

- [x] Les deux lots sont `Done`
- [ ] `bin/ci-quiet` vert via la file commune, verdict écrit dans la PR
- [x] ADR-0106 et UDR-0131 indexés par `script/docs/build_index`
- [ ] `journal.md` complété
