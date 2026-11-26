# Plan d'exécution — Accueil enseignant tourné vers l'action

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

Pas de Lot 0 : aucun port, aucune table, aucune route. Les lots touchent des fichiers disjoints sauf les locales, tenues par fichier de contexte. Exécutés à la suite dans la même session (un commit par lot), une PR vers `Develop`.

```
Lot A « À suivre » ─┐
Lot B « barre »     ├─ indépendants, une seule PR
Lot C « liste »     │
Lot D « relance »  ─┘
```

---

## Lot A — Accueil : « À suivre », ronds nommés, pas de section vide (CA-1 à CA-5)

- **Couche**       : domaine + infrastructure + ui
- **Fichiers**     : `app/domain/entities/classroom/level_short_name.rb`, `app/domain/entities/classroom/follow_up_priority.rb`
                     `app/infrastructure/queries/classroom/teacher_home_query.rb`
                     `app/views/classroom/teacher_homes/{show,_to_follow,_to_follow_row,_course_levels,_add_classroom_card}.html.erb` (retrait de `_classroom_card`)
                     `app/views/components/_subject_bubble.html.erb`, `app/helpers/components_helper.rb`
                     `config/locales/classroom/teacher_homes.fr.yml`
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/classroom/{level_short_name,follow_up_priority}_test.rb`, `test/infrastructure/queries/classroom/teacher_home_query_test.rb`, `test/controllers/classroom/teacher_homes_controller_test.rb`
- **Done quand**   : l'enseignant `0500000011` voit la Tle D en tête de « À suivre » et les ronds « 6e … Tle D » colorés

## Lot B — Barre du haut sur l'accueil seulement, retours manquants (CA-6)

- **Couche**       : ui
- **Fichiers**     : `app/views/layouts/shell.html.erb`, `app/views/communication/inboxes/show.html.erb`, `app/views/communication/authored_messages/index.html.erb`, `app/views/school/teacher_school_joins/new.html.erb`
- **Dépend de**    : —
- **Test associé** : `test/controllers/classroom/teacher_shell_header_test.rb`
- **Done quand**   : aucune page enseignant sauf l'accueil n'a l'en-tête ; chacune a un retour

## Lot C — Page de la classe : code, liste par état (CA-7, CA-8)

- **Couche**       : infrastructure + ui
- **Fichiers**     : `app/infrastructure/queries/classroom/classroom_overview_query.rb`, `app/views/classroom/classrooms/{_link,_roster}.html.erb`, `config/locales/classroom/classrooms.fr.yml`
- **Dépend de**    : —
- **Test associé** : `test/infrastructure/queries/classroom/classroom_overview_query_test.rb`, `test/controllers/classroom/classrooms_controller_test.rb`, `test/system/classroom/classroom_roster_test.rb`
- **Done quand**   : la Tle D dit « 38 en retard · 2 à jour », dix lignes, « Voir plus (30) » ; le code se copie

## Lot D — Suivi d'un devoir : « Relancer sur WhatsApp » (CA-9)

- **Couche**       : ui
- **Fichiers**     : `app/views/classroom/assignment_follow_ups/show.html.erb`, `app/views/assessment/comprehension/_section.html.erb`, `config/locales/assessment/comprehension.fr.yml`
- **Dépend de**    : —
- **Test associé** : `test/controllers/classroom/assignment_follow_ups_controller_test.rb`
- **Done quand**   : le bouton ouvre wa.me avec le message prérempli, et disparaît quand tous ont fait le devoir

---

## Décisions ouvertes

- [x] Toutes tranchées par le porteur le 2026-11-26 (sur maquettes). Les points réversibles restants sont dans `journal.md` § À trancher.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/locales/classroom/teacher_homes.fr.yml` | Lot A |
| `config/locales/classroom/classrooms.fr.yml` | Lot C |
| `config/locales/assessment/comprehension.fr.yml` | Lot D |
| `app/views/layouts/shell.html.erb` | Lot B |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît (aucun : écrit dans `prd.md` §6)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md`
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle (sans objet : pas de Lot 0)
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
