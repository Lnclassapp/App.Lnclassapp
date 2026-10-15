# Plan d'exécution — Page Ma classe de l'élève aux couleurs Wave et Djamo

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Décisions : [PRD](prd.md) · [UDR-0086](../../decisions/udr/0086-page-ma-classe-eleve-redessinee-et-invitation-de-l-enseignant.md). Pas d'ADR (PRD §6).
> **Prérequis** : la PR [`accueil-eleve`](../accueil-eleve/plan.md) est fusionnée (en-tête, menu de l'avatar, `_invite_teacher`). Une seule PR, un commit par lot (3 commits). Petit chantier : il peut se coder dans la même session que `cours-eleve`, dans une PR distincte.

## Graphe

```
Lot 0 — SOCLE ──► Lot A — PAGE ──► Lot B — PREUVE ET CLÔTURE
```

---

## Lot 0 — Socle

- **Couche**       : infrastructure (query) + config
- **Fichiers**     : `app/infrastructure/queries/classroom/student_classroom_query.rb` *(`Row#has_teacher`, `EXISTS` sur `teacher_classrooms`)*
                     `config/locales/classroom/student_classrooms.fr.yml` *(clés de la carte « Aucun enseignant »)*
                     `test/infrastructure/queries/classroom/student_classroom_query_test.rb`
- **Dépend de**    : PR `accueil-eleve` fusionnée
- **Test associé** : `test/infrastructure/queries/classroom/student_classroom_query_test.rb` : `has_teacher` vrai et faux
- **Done quand**   : `has_teacher` est juste ; les requêtes de `GET /students/classroom` sont mesurées et notées dans `prd.md` §7

---

## Lot A — Page Ma classe (CA-1 à CA-7)

- **Couche**       : UI
- **Fichiers**     : `app/views/classroom/student_classrooms/show.html.erb` · `_course_card.html.erb` · `_assigned_exercise.html.erb` · `_treated_exercise.html.erb`
                     `app/views/classroom/student_classrooms/_no_teacher.html.erb` *(nouveau)*
                     `test/system/classroom/student_classroom_test.rb` · `test/controllers/classroom/student_classrooms_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/system/classroom/student_classroom_test.rb` (CA-1, CA-5, CA-7 à 390 et 1 280 px) · `test/controllers/classroom/student_classrooms_controller_test.rb` (CA-2, CA-3, CA-4, CA-6)
- **Done quand**   : la page correspond aux maquettes au téléphone, sur tablette et sur ordinateur, en clair et en sombre, avec et sans enseignant

---

## Lot B — Preuve et clôture

- **Couche**       : docs + preuve
- **Fichiers**     : `journal.md` · `prd.md` *(§7 « Après »)* · `docs/chantiers/README.md` *(une ligne)* · index UDR *(par `script/docs/build_index`)* · statut d'UDR-0086
- **Dépend de**    : Lot A
- **Test associé** : `bin/ci-quiet` vert, verdict copié dans la PR ; `pr-test-analyzer` seulement si le diff dépasse 150 lignes
- **Done quand**   : captures envoyées (390 px et ordinateur : avec travail, sans enseignant, « Voir plus » ouvert, menu ouvert, sombre), PR ouverte prête

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `app/infrastructure/queries/classroom/student_classroom_query.rb` · `config/locales/classroom/student_classrooms.fr.yml` | Lot 0 |
| `app/views/classroom/student_classrooms/**` · leurs tests | Lot A |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît *(aucun : PRD §6)*
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md` *(UDR-0086 écrite ; index à la clôture)*
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé avant le Lot A
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
