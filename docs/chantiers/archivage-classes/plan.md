# Plan d'exécution — Archiver une classe

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Contexte borné porteur de la règle : `classroom` (les écrans touchent `school`, `identity`). Pas de migration : `status` et `archived_at` existent. Un commit par lot (CLAUDE.md, sobriété de tokens).

## Graphe

```
Lot 0 — SOCLE (séquentiel) : entité, port, repository, 3 cas d'usage, routes, menus et locale partagés
  ↓
  ├─► Lot A  Écran équipe (fiche établissement)     ┐
  ├─► Lot B  Écran direction (niveau et classes)    ├─ en parallèle
  └─► Lot C  Ce que voient élèves et enseignants    ┘
```

Vagues de dispatch :

```
Vague 1 : Lot 0              → 1 agent, séquentiel
Vague 2 : Lot A ‖ B ‖ C      → 3 agents, worktrees isolés (branches <type>/<slug>-lot-a, -lot-b, -lot-c)
```

Le Lot 0 est plus gros qu'un socle habituel : les trois cas d'usage servent deux écrans, ils ne peuvent appartenir à aucun des deux sans les faire dépendre l'un de l'autre. Il reste de la logique sans écran propre.

---

## Lot 0 — Socle

- **Couche**       : domaine + infrastructure + delivery (routes) + ui (partiels partagés)
- **Fichiers**     : app/domain/entities/classroom/classroom.rb
                     app/domain/ports/classroom/classroom_repository_port.rb
                     app/infrastructure/repositories/classroom/classroom_repository.rb
                     app/domain/use_cases/classroom/archive_classroom.rb
                     app/domain/use_cases/classroom/restore_classroom.rb
                     app/domain/use_cases/classroom/archive_level_classrooms.rb
                     config/routes/teams.rb · config/routes/school_admin.rb
                     app/views/shared/_classroom_archive_menu.html.erb
                     app/views/shared/_level_archive_menu.html.erb
                     app/views/shared/_archives_toggle.html.erb
                     config/locales/shared/classroom_archival.fr.yml
- **Dépend de**    : —
- **Test associé** : test/domain/use_cases/classroom/archive_classroom_test.rb
                     test/domain/use_cases/classroom/restore_classroom_test.rb
                     test/domain/use_cases/classroom/archive_level_classrooms_test.rb
                     test/infrastructure/repositories/classroom/classroom_repository_test.rb
- **Done quand**   : un cas d'usage archive une classe peuplée sans toucher adhésions ni assignations, la restaure à l'identique, archive les classes actives d'un niveau en un événement d'audit, et refuse l'étranger, le double archivage et la classe d'une autre année ; les routes et les trois partiels (menu de classe, menu de niveau, bouton d'archives) existent et se rendent dans les tests des lots

Contrats gelés : `archive(id:, at:)`, `restore(id:)`, `archive_level(school_id:, school_year:, level_id:, at:)` (→ nombre de classes) sur le port ; routes `PATCH …/classroom-archivals/:public_id/archive|restore` et `POST …/level-archivals` côté équipe (sous la fiche) et côté direction (sous `/school-admin/school`) ; partiels à locals explicites (chemins, noms, effectifs).

---

## Lot A — Écran équipe : fiche d'un établissement

- **Couche**       : delivery + ui + infrastructure (query de lecture)
- **Fichiers**     : app/controllers/teams/classroom_archivals_controller.rb
                     app/controllers/teams/level_archivals_controller.rb
                     app/controllers/teams/schools_controller.rb
                     app/views/teams/classroom_archivals/update.turbo_stream.erb
                     app/views/teams/level_archivals/create.turbo_stream.erb
                     app/views/teams/schools/_classroom_group.html.erb
                     app/views/teams/schools/show.html.erb
                     app/infrastructure/queries/school/school_detail_query.rb
                     config/locales/teams/classroom_archivals.fr.yml
- **Dépend de**    : Lot 0
- **Test associé** : test/controllers/teams/classroom_archivals_controller_test.rb
                     test/controllers/teams/level_archivals_controller_test.rb
                     test/infrastructure/queries/school/school_detail_query_test.rb
                     test/system/teams/classroom_archival_test.rb
- **Done quand**   : l'équipe ouvre la fiche d'un établissement, archive une classe peuplée depuis son menu ⋮ après la confirmation chiffrée, archive un niveau, restaure ; la classe reste visible 7 jours puis ne paraît que sous « Afficher les archives » ; les compteurs du niveau et de l'établissement ne comptent pas les archivées

---

## Lot B — Écran direction : niveau et classes

- **Couche**       : delivery + ui + infrastructure (query de lecture)
- **Fichiers**     : app/controllers/school_admin/classroom_archivals_controller.rb
                     app/controllers/school_admin/level_archivals_controller.rb
                     app/controllers/school_admin/levels_controller.rb
                     app/views/school_admin/classroom_archivals/update.turbo_stream.erb
                     app/views/school_admin/level_archivals/create.turbo_stream.erb
                     app/views/school_admin/levels/show.html.erb
                     app/views/school_admin/levels/_classroom_card.html.erb
                     app/infrastructure/queries/school/student_work_query.rb
                     config/locales/school_admin/classroom_archivals.fr.yml
- **Dépend de**    : Lot 0
- **Test associé** : test/controllers/school_admin/classroom_archivals_controller_test.rb
                     test/controllers/school_admin/level_archivals_controller_test.rb
                     test/infrastructure/queries/school/student_work_query_test.rb
                     test/system/school_admin/classroom_archival_test.rb
- **Done quand**   : la direction archive et restaure une classe (carte restructurée avec son menu ⋮) et un niveau depuis la page du niveau, sur son seul établissement actif ; un autre établissement ou un établissement inactif est refusé ; les archivées de plus de 7 jours se masquent derrière « Afficher les archives » ; les effectifs de l'accueil ne les comptent pas

---

## Lot C — Ce que voient les élèves et les enseignants

- **Couche**       : infrastructure (lectures) + ui
- **Fichiers**     : app/infrastructure/queries/identity/shell_user_query.rb
                     app/infrastructure/queries/classroom/join_preview_query.rb
                     app/views/classroom/joins/_classroom_preview.html.erb
                     config/locales/classroom/joins.fr.yml
- **Dépend de**    : Lot 0
- **Test associé** : test/infrastructure/queries/identity/shell_user_query_test.rb
                     test/infrastructure/queries/classroom/join_preview_query_test.rb
                     test/controllers/classroom/archived_classroom_reads_test.rb
- **Done quand**   : un élève dont l'unique classe est archivée voit « Choisis ta classe » et son en-tête ne nomme plus la classe ; un élève multi-classes garde l'autre ; un enseignant ne voit plus la classe archivée ni ses échéances et ne peut plus y assigner ; le lien d'une classe archivée refuse l'élève avec un message qui parle d'archivage, et refonctionne après restauration

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/teams.rb` · `config/routes/school_admin.rb` | Lot 0 |
| `config/locales/shared/classroom_archival.fr.yml` | Lot 0 |
| `app/views/shared/_classroom_archive_menu.html.erb` · `_level_archive_menu.html.erb` · `_archives_toggle.html.erb` | Lot 0 |
| `app/infrastructure/repositories/classroom/classroom_repository.rb` · le port · l'entité | Lot 0 |
| `app/views/teams/schools/_classroom_group.html.erb` | Lot A |
| `app/infrastructure/queries/school/school_detail_query.rb` | Lot A |
| `app/infrastructure/queries/school/student_work_query.rb` | Lot B |
| `app/views/school_admin/levels/_classroom_card.html.erb` | Lot B |
| `app/infrastructure/queries/identity/shell_user_query.rb` | Lot C |
| `config/locales/classroom/joins.fr.yml` | Lot C |

Aucun fichier dans deux lots (contrôle `awk`/`uniq -d` vide). Un lot qui a besoin d'un fichier d'un autre s'arrête et remonte : Lot 0 rouvre.

## Couverture des critères d'acceptation (PRD §4)

| Critère | Lot |
|---|---|
| Archiver une classe peuplée · Restaurer · Droits · Double archivage | 0 (domaine), A et B (delivery) |
| Archiver un niveau | 0, A, B |
| La confirmation chiffre l'impact | A, B (les effectifs sont déjà dans les cartes ; pas de query d'impact) |
| Visibilité de 7 jours · Effectifs de la direction | A (équipe), B (direction) |
| L'élève · L'élève multi-classes · L'enseignant · Lien d'inscription | C |

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md`
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md`
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
> Ici : archiver une classe peuplée puis restaurer (nominal) ; refus de la direction d'un autre établissement et double archivage (erreur) ; contrôle de ce que voit un élève.
