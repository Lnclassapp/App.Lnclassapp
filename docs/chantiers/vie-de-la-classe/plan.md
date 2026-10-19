# Plan d'exécution — La vie de la classe

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
>
> **Aucun lot ne démarre avant les réponses du porteur aux questions Q1 à Q8 du [memo](memo.md).** Le plan suit les recommandations ; une réponse contraire le modifie d'abord (Q6 = « non » retire le Lot B ; Q8 = « non » retire le Lot C).

## Graphe

```
Lot 0 — SOCLE (séquentiel, court)          Lot C — Sous-pages d'une classe archivée
  nom de classe · DTO · port · routes          (aucun fichier partagé : part tout de suite)
  · locales
  ↓
  ├─► Lot A — Modifier une classe (équipe, direction)   ┐
  └─► Lot B — Chiffres de la classe (enseignant, équipe) ┘ en parallèle, fichiers disjoints
```

Trois agents au plus en même temps : Lot 0 et Lot C, puis Lot A, Lot B et Lot C s'il n'est pas fini.

---

## Lot 0 — Socle

- **Couche**       : domaine (contrats) + fichiers partagés
- **Fichiers**     : `app/domain/entities/classroom/classroom_numbering.rb` *(`full_name`, `suffix_of`, ADR-0098 §6)*
                     `app/domain/dtos/classroom/classroom_settings_input.rb` *(suffix, max_students, school_public_id, classroom_public_id ; suffixe exigé, plafond entier 1 à 150)*
                     `app/domain/ports/classroom/classroom_repository_port.rb` *(`update_settings(id:, name:, max_students:)`, contrat de l'ADR-0098 §4)*
                     `config/routes/teams.rb` *(`resources :classroom_settings, only: %i[edit update], path: "classroom-settings", param: :public_id` sous `schools`)*
                     `config/routes/school_admin.rb` *(même ressource sous `scope "school"`)*
                     `config/locales/shared/classroom_settings.fr.yml` *(formulaire, aides, erreurs, toasts — UDR-0110)*
                     `config/locales/shared/classroom_archival.fr.yml` *(entrée « Modifier la classe » — UDR-0111)*
                     `config/locales/teams/classroom_settings.fr.yml` · `config/locales/school_admin/classroom_settings.fr.yml` *(titres, flash)*
                     `config/locales/classroom/classrooms.fr.yml` *(titre « Chiffres de la classe » — UDR-0112)*
                     `test/domain/entities/classroom/classroom_numbering_test.rb`
                     `test/domain/dtos/classroom/classroom_settings_input_test.rb`
- **Dépend de**    : réponses du porteur (Q1 à Q4, Q6)
- **Test associé** : `test/domain/entities/classroom/classroom_numbering_test.rb` (`full_name` compacte, `suffix_of` d'un nom d'un autre préfixe rend `""`) ; `test/domain/dtos/classroom/classroom_settings_input_test.rb` (suffixe vide, 0, 151, « abc » refusés)
- **Done quand**   : `bin/rails runner "puts Dtos::Classroom::ClassroomSettingsInput.name"` répond ; `bin/rails routes -g classroom_setting` liste les quatre routes ; tests verts ; le port est gelé

---

## Lot A — Modifier une classe (équipe et direction)

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/classroom/update_classroom.rb`
                     `app/infrastructure/repositories/classroom/classroom_repository.rb` *(`update_settings` sous verrou)*
                     `app/controllers/teams/classroom_settings_controller.rb`
                     `app/controllers/school_admin/classroom_settings_controller.rb` *(établissement = `current_actor.school_id`, jamais un paramètre)*
                     `app/views/shared/_classroom_settings_form.html.erb`
                     `app/views/teams/classroom_settings/edit.html.erb` · `update.turbo_stream.erb`
                     `app/views/school_admin/classroom_settings/edit.html.erb` · `update.turbo_stream.erb`
                     `app/views/shared/_classroom_archive_menu.html.erb` *(entrée « Modifier la classe », local `edit_path:`)*
                     `app/views/teams/schools/_classroom_group.html.erb` · `app/views/school_admin/levels/_classroom_card.html.erb` *(passent `edit_path:`)*
                     `test/domain/use_cases/classroom/update_classroom_test.rb`
                     `test/infrastructure/repositories/classroom/classroom_repository_test.rb`
                     `test/infrastructure/repositories/classroom/classroom_settings_concurrency_test.rb`
                     `test/controllers/teams/classroom_settings_controller_test.rb`
                     `test/controllers/school_admin/classroom_settings_controller_test.rb`
                     `test/system/school/classroom_settings_test.rb` · `script/ci/test_timings.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/classroom/update_classroom_test.rb` (droits, année passée, archivée, rien de changé sans audit) ; repository (`below_headcount`, `archived`, `taken` contre une archivée) ; concurrence (adhésion et baisse du plafond au 80ᵉ siège) ; système (renommer « 6ème 3 » en « 6ème A », puis « + » ajoute « 6ème 3 »)
- **Done quand**   : l'équipe sur la fiche d'un établissement et la direction sur la page d'un niveau ouvrent ⋮ → « Modifier la classe », changent suffixe et plafond, voient la carte mise à jour et le toast ; l'élève voit le nouveau nom ; captures 390 px et ordinateur (menu ouvert, modale, erreur sous le champ) envoyées au porteur

---

## Lot B — Chiffres de la classe (enseignant et équipe)

*Retiré si Q6 = « laisser CL-14 à `rapports-de-classe` ».*

- **Couche**       : infrastructure (lecture) + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/school/student_work_query.rb` *(`figures(public_id:)`, mêmes définitions que `classroom`)*
                     `app/controllers/classroom/classrooms_controller.rb`
                     `app/views/classroom/classrooms/show.html.erb`
                     `app/views/classroom/classrooms/_figures.html.erb`
                     `test/infrastructure/queries/school/student_work_query_test.rb`
                     `test/controllers/classroom/classrooms_controller_test.rb`
- **Dépend de**    : Lot 0 (locale du titre)
- **Test associé** : `student_work_query_test.rb` (`figures` égale les chiffres de `classroom` pour la même classe ; moyenne `nil` sous 5 élèves ; nombre de requêtes fixe pour 1 et 30 élèves) ; `classrooms_controller_test.rb` (enseignant et équipe voient `#classroom_figures`, élève 403)
- **Done quand**   : l'enseignant ouvre sa classe et lit les trois tuiles, aux mêmes valeurs que la page de la direction ; le nombre de requêtes de la page est mesuré avant et après (PRD §7) ; captures 390 px et ordinateur envoyées

---

## Lot C — Une classe archivée n'a plus aucune page

*Retiré si Q8 = « non ». Aucune vue nouvelle : la page 404 existe.*

- [x] **Done** le 2026-10-16, branche `fix/classe-archivee-sous-pages`. Ajouté au périmètre : `app/controllers/classroom/assignments_controller.rb` (`new`, la modale des jours, seule autre page `GET` sous `/classrooms/:id/…`) et les tests qui exigeaient l'ancienne lecture (`classroom_courses`, `classroom_essentials`, `assignment_follow_ups`, `session_days`, `assignments`). Les écritures gardent leur 403 « classe archivée » (journal, menace du Lot C).

- **Couche**       : delivery
- **Fichiers**     : `app/controllers/classroom/classroom_courses_controller.rb`
                     `app/controllers/classroom/classroom_essentials_controller.rb`
                     `app/controllers/classroom/assignment_follow_ups_controller.rb`
                     `app/controllers/classroom/session_days_controller.rb`
                     `test/controllers/classroom/archived_classroom_reads_test.rb`
- **Dépend de**    : —
- **Test associé** : `archived_classroom_reads_test.rb` : pour chacune des quatre sous-pages, enseignant et équipe reçoivent 404 sur la classe archivée, 200 après restauration (test écrit d'abord, rouge)
- **Done quand**   : aucune adresse sous `/classrooms/<classe archivée>/…` ne répond autre chose que 404 ; la dette est rayée du journal d'`archivage-classes` à la clôture

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/teams.rb`, `config/routes/school_admin.rb` | Lot 0 |
| `config/locales/**` | Lot 0 |
| `app/domain/ports/classroom/classroom_repository_port.rb` | Lot 0 |
| `app/domain/entities/classroom/classroom_numbering.rb` | Lot 0 |
| `app/infrastructure/repositories/classroom/classroom_repository.rb` | Lot A |
| `app/views/shared/_classroom_archive_menu.html.erb` | Lot A |
| `script/ci/test_timings.yml` | Lot A *(seul lot à ajouter un test système)* |
| `app/infrastructure/queries/school/student_work_query.rb` | Lot B *(Lot A en lit `level` et `classroom` sans les modifier)* |
| `app/controllers/classroom/classrooms_controller.rb`, `app/views/classroom/classrooms/*` | Lot B |
| `app/controllers/classroom/{classroom_courses,classroom_essentials,assignment_follow_ups,session_days}_controller.rb` | Lot C |

Aucun fichier n'apparaît dans deux lots parallèles.

## Portes de sortie

- [ ] Tous les lots sont `Done`
- [ ] Un rôle distinct de l'auteur a **exécuté** le résultat : parcours refait en équipe, en direction (son établissement et un autre), en enseignant, en élève
- [ ] Pureté du domaine, rubocop, tests, parcours système, brakeman : `bin/ci-quiet` au vert, verdict écrit dans la PR
- [ ] Sous-agents de revue (`security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`) une fois, sur le diff final : use case, policy et routes touchés
- [ ] ADR-0098 et UDR-0110 à 0112 passés à `Accepté` ; index régénérés par `script/docs/build_index` au commit de clôture
- [ ] Feuille de route et `features-refonte.md` : CL-02, CL-03, CL-14, CL-15 cochées selon Q6 ; Q5, Q6 et Q8 de la feuille de route marquées répondues ; dette des codes rayée ; `rentree-scolaire` inscrite (Q7)
- [ ] `journal.md` complété
