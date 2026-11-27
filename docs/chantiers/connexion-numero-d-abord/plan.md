# Plan — Connexion et inscription « numéro d'abord »

Lots séquentiels, une seule session, une branche, une PR (les quatre lots touchent `StudentEntrySession` et les mêmes locales : pas de parallèle utile).

```
Lot 0 — socle : EnterByNumber, NumberEntryInput, NumberEntryLimit, entrée gardée avec `known`
  ↓
Lot A — /login numéro d'abord (CA-1, 2, 5, 6, 7, 8, 13)
  ↓
Lot B — /student numéro d'abord, code une fois (CA-3, 9, 10)
  ↓
Lot C — inscription enseignant en trois étapes (CA-4, 11, 12)
```

| Lot | Objectif | Fichiers | Tests | Fini quand |
|---|---|---|---|---|
| 0 | Use case et DTO numéro seul / numéro + code ; compteurs partagés | `app/domain/use_cases/identity/enter_by_number.rb`, `app/domain/dtos/identity/number_entry_input.rb`, `student_entry_input.rb`, `app/controllers/concerns/{number_entry_limit,student_entry_session}.rb` | `test/domain/use_cases/identity/enter_by_number_test.rb` | tests du domaine verts |
| A | `/login` en trois écrans | `identity/sessions_controller.rb`, `sessions/new.html.erb`, `sessions.fr.yml`, `test/support/system_authentication_helper.rb` | `sessions_controller_test.rb`, `sign_in_test.rb` | CA-1, 2, 5 à 8, 13 |
| B | `/student` numéro d'abord, pavé « Entre ton code secret » | `student_entries_controller.rb`, `student_entries/new.html.erb`, `student_entries.fr.yml`, `classroom/joins_controller.rb`, `pin_pad_controller.js`, `test/support/student_entry_helper.rb` | `student_entries_controller_test.rb`, `student_entry_pin_pad_test.rb` | CA-3, 9, 10 |
| C | Enseignant : numéro, code, profil | `teacher_registrations_controller.rb`, `teacher_registrations/{new,_form,_school_fields}.html.erb`, `teacher_registrations.fr.yml`, `signup_steps_controller.js` | `teacher_registrations_controller_test.rb`, système enseignant | CA-4, 11, 12 |

## Vérification de collision

Séquentiel : sans objet.

## Décisions ouvertes

Aucune avant lancement (décisions 1 à 4 du porteur, correction du code d'établissement).

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
