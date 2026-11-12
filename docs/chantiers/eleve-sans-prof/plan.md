# Plan d'exécution — L'élève sans enseignant a quelque chose à faire dès l'accueil

Un seul lot : la règle (une query), l'accueil (contrôleur, deux vues, une locale) et leurs tests se tiennent ; les découper créerait une collision sur les mêmes fichiers.

## Lot A — L'élève sans classe voit son dernier niveau

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/catalog/student_audience_query.rb` · `app/infrastructure/queries/assessment/daily_exercise_query.rb` · `app/infrastructure/queries/classroom/student_home_query.rb` · `app/controllers/classroom/student_homes_controller.rb` · `app/views/classroom/student_homes/{show,_subjects,next_step/_no_classroom}.html.erb` · `config/locales/classroom/student_homes.fr.yml`
- **Dépend de**    : —
- **Test associé** : `test/infrastructure/queries/catalog/student_audience_query_test.rb` · `test/infrastructure/queries/assessment/daily_exercise_query_test.rb` · `test/controllers/classroom/student_homes_controller_test.rb` · `test/controllers/classroom/archived_classroom_reads_test.rb`
- **Done quand**   : un élève retiré de sa classe voit les matières et l'exercice du jour de son niveau, ouvre une leçon et finit un exercice corrigé

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît (amendement d'ADR-0035 : la règle de lecture change)
- [x] UDR écrite pour **chaque** vue créée ou modifiée (amendement d'UDR-0132)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli (un seul lot)
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle (sans objet : aucun port)
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/` (aucun fichier créé ; en-têtes mis à jour)
- [x] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur (parcours Playwright sur le jeu standard, voir la PR)
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [x] `journal.md` clos (dérapages, dette, chantiers de suivi)
