# Plan d'exécution — Supprimer une leçon qui n'a jamais servi à un élève

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — « supprimer une leçon sans activité » (vertical, seul)
```

Un seul cas d'usage, un seul contrôleur, un seul port touché : le socle (port, action d'audit, routes, libellés) tient dans le lot. Aucun parallélisme possible ni utile.

---

## Lot A — Supprimer une leçon sans activité d'élève

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/entities/catalog/student_activity.rb` · `app/domain/ports/catalog/course_repository_port.rb`
                     `app/domain/use_cases/catalog/delete_course.rb` · `app/domain/entities/identity/audit_action.rb`
                     `app/infrastructure/repositories/catalog/course_repository.rb` · `app/infrastructure/repositories/classroom/assignment_repository.rb`
                     `app/controllers/teams/courses_controller.rb` · `config/routes/teams.rb` · `config/locales/*.fr.yml`
                     `app/views/catalog/courses/_role_actions.html.erb` · `app/views/teams/courses/{deletion.html.erb,_deletion_dialog.html.erb}`
- **Dépend de**    : —
- **Test associé** : `test/domain/use_cases/catalog/delete_course_test.rb` (CA-01, CA-02 domaine) ·
                     `test/infrastructure/repositories/catalog/course_repository_deletion_test.rb` (CA-02 par source, CA-03, CA-04) ·
                     `test/domain/use_cases/catalog/import_course_tree_test.rb` (CA-05) · `test/infrastructure/repositories/catalog/course_deletion_concurrency_test.rb` ·
                     `test/controllers/teams/course_deletions_test.rb` (CA-01, CA-06, CA-07) · `test/system/teams/course_deletion_test.rb` ·
                     `test/infrastructure/repositories/classroom/assignment_repository_test.rb` (CA-08)
- **Done quand**   : depuis la page d'une leçon sans activité, « Supprimer » → confirmer renvoie au catalogue et la leçon se réimporte ; sur une leçon avec activité, la modale refuse et propose « Modifier la leçon ».

---

## Décisions ouvertes

- [x] Règle de suppression, refus et confirmation — tranchées par le porteur (2026-11-14), voir le memo.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/teams.rb` | Lot A |
| `config/locales/*.fr.yml` | Lot A |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle (sans objet : lot unique)
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
