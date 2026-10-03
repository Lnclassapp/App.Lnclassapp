# Plan d'exécution — Validation des enseignants en pause

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — inscription sans code validée aussitôt (seul lot, vertical)
```

Le chantier tient en un cas d'usage et ne change aucune signature de port : un seul lot, sans socle séparé.

---

## Lot A — Inscription sans code validée aussitôt

- **Couche**       : migration → domaine → contrôleur → locales
- **Fichiers**     : `db/migrate/20261003120000_pause_teacher_join_request_review.rb` · `db/schema.rb`
                     `app/domain/entities/school/join_request.rb` · `app/domain/ports/school/join_request_repository_port.rb`
                     `app/domain/use_cases/identity/register_pending_teacher.rb`
                     `app/controllers/identity/pending_teacher_registrations_controller.rb`
                     `config/locales/identity/pending_teacher_registrations.fr.yml`
- **Dépend de**    : —
- **Test associé** : `test/domain/use_cases/identity/register_pending_teacher_test.rb` · `test/controllers/identity/pending_teacher_registrations_controller_test.rb` · `test/db/pause_teacher_join_request_review_test.rb` · `test/system/identity/cold_start_test.rb`
- **Done quand**   : les cinq critères du PRD §4 ont leur test vert, couverture à 100 %

## Vérification de collision

Un seul lot : sans objet.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md`
- [x] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md`
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle *(sans objet : un seul lot)*
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
