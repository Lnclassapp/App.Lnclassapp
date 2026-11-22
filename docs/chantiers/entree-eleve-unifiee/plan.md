# Plan — Une seule entrée pour l'élève : numéro et code secret

Un seul lot : aucun port, aucune table, aucune migration ; les vues touchées (entrée, inscription élève, question enseignant) dépendent du même stockage de l'entrée en session. Un découpage aurait fait trois PR sur les mêmes contrôleurs le même jour.

## Lot A — Entrée élève, inscription en mode entrée, question enseignant

| Champ | Valeur |
|---|---|
| **Objectif** | CA-1 à CA-12 du [PRD](prd.md) |
| **Fichiers** | `app/domain/dtos/identity/student_entry_input.rb`, `app/domain/use_cases/identity/enter_as_student.rb`, `app/controllers/concerns/student_entry_session.rb`, `app/controllers/identity/student_entries_controller.rb`, `app/controllers/classroom/{student_registrations,joins}_controller.rb`, `app/controllers/identity/teacher_registrations_controller.rb`, `config/routes/identity.rb`, vues `identity/student_entries/`, `identity/teacher_registrations/confirm`, `classroom/student_registrations/`, `homepage/_role_modal`, `identity/sessions/new`, locales |
| **Dépend de** | — |
| **Tests** | domaine `enter_as_student_test`, contrôleurs `student_entries`, `student_registrations`, `joins`, `teacher_registrations`, `homepage`, `sessions` ; système `homepage`, `join`, `student_signup_steps`, `pin_reveal`, `error_paths`, `finitions/public_pages`, `boucle_pedagogique` |

## Tableau de collision

| Fichier | Chantier en parallèle | Risque | Parade |
|---|---|---|---|
| `classroom/student_registrations/_form.html.erb`, `new.html.erb` | `recherche-etablissement` (sélecteur DRENA → établissement) | Conflit de texte | Le sélecteur n'est pas touché ; seuls l'étape « Toi », le compteur et le panneau changent. Fusion de cette PR en premier (ordre de l'orchestrateur). |
| `classroom/student_registrations_controller.rb` (débits) | `inscription-classe-meme-wifi` (livré) | Débit d'une classe sur un wifi | Compteur propre à l'inscription qui suit l'entrée (60/min), ADR-0141 §4.2 |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle (sans objet : pas de port, un seul lot)
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur (revues de la PR, captures)
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert (ligne de preuve `bin/ci-quiet` dans la PR)
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [x] `journal.md` clos (dérapages, dette, chantiers de suivi)
