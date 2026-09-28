# Plan d'exécution — Ajuster le nombre de classes par niveau d'un établissement

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot 0 — socle : port ClassroomRepositoryPort (2 méthodes), ClassroomNumbering, Placement, route, locales, query du bloc
  ↓
Lot A — ajouter la classe suivante ‖ Lot B — retirer la dernière classe
```

Les deux lots verticaux partagent le contrôleur, la vue du bloc et le test système : ils sont menés **en séquence dans une seule branche** (un seul agent), Lot A puis Lot B, ce qui évite de faire remonter ces fichiers au Lot 0.

---

## Lot 0 — Socle

- **Couche**       : domaine + infrastructure + delivery (partagés)
- **Fichiers**     : `app/domain/ports/classroom/classroom_repository_port.rb`
                     `app/domain/entities/classroom/classroom_numbering.rb` · `app/domain/entities/classroom/placement.rb`
                     `app/domain/use_cases/classroom/create_classroom.rb` (utilise `Placement`, comportement inchangé)
                     `app/infrastructure/queries/school/level_classrooms_query.rb`
                     `config/routes/teams.rb` · `config/locales/teams/level_classrooms.fr.yml`
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/classroom/{classroom_numbering,placement}_test.rb` · `test/domain/use_cases/classroom/create_classroom_test.rb` (inchangé, vert)
                     `test/infrastructure/queries/school/level_classrooms_query_test.rb`
- **Done quand**   : les lignes du bloc (CN-01) sont lues, les ports gelés, « Ajouter une classe » inchangé

## Lot A — L'équipe ajoute la classe suivante d'un niveau

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/classroom/add_level_classroom.rb`
                     `app/infrastructure/repositories/classroom/classroom_repository.rb` (`names_in_level`)
                     `app/controllers/teams/level_classrooms_controller.rb` (`create`)
                     `app/views/teams/schools/_level_classrooms.html.erb` · `app/views/teams/schools/show.html.erb` · `app/controllers/teams/schools_controller.rb`
                     `app/views/teams/level_classrooms/update.turbo_stream.erb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/classroom/add_level_classroom_test.rb` · `test/controllers/teams/level_classrooms_controller_test.rb`
                     `test/system/school/classrooms_by_level_test.rb`
- **Done quand**   : « + » sur « 6ème » crée « 6ème 5 » et la fiche se met à jour sans rechargement (CN-02 à CN-04)

## Lot B — L'équipe retire la dernière classe d'un niveau

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/classroom/remove_level_classroom.rb`
                     `app/infrastructure/repositories/classroom/classroom_repository.rb` (`delete_if_unused`)
                     `app/controllers/teams/level_classrooms_controller.rb` (`destroy`)
                     (réponse Turbo Stream commune au Lot A)
- **Dépend de**    : Lot A (fichiers partagés, en séquence)
- **Test associé** : `test/domain/use_cases/classroom/remove_level_classroom_test.rb`
                     `test/infrastructure/repositories/classroom/classroom_repository_test.rb`
                     `test/controllers/teams/level_classrooms_controller_test.rb` · `test/system/school/classrooms_by_level_test.rb`
- **Done quand**   : « − » retire une classe vide après confirmation, et refuse une classe qui a un élève (CN-05 à CN-08)

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/teams.rb`, `config/locales/teams/level_classrooms.fr.yml`, port des classes | Lot 0 |
| contrôleur, `_level_classrooms`, test système, `classroom_repository.rb` | Lot A puis Lot B, en séquence dans la même branche |

Chantiers parallèles (code d'établissement, barème modifiable, cycles en radio, photo de profil) : l'en-tête de la fiche (`_header`), `SchoolDetailQuery`, `DefaultClassroomPlan` et `AuditAction` ne sont **pas** touchés ; `show.html.erb` ne reçoit qu'une ligne de rendu ; `schools_controller.rb#show` une ligne.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR-0059 écrit et indexé
- [x] UDR-0046 écrite et indexée
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 posé et ports gelés avant les lots verticaux
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur *(à faire par le challenger, sur la PR)*
- [x] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop` *(ouverte par le coordinateur)*
- [x] `journal.md` complété
