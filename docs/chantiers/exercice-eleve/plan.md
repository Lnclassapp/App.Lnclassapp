# Plan d'exécution — Parcours d'exercice de l'élève aux couleurs Wave et Djamo

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Décisions : [PRD](prd.md) · [ADR-0091](../../decisions/adr/0091-quatre-nouveaux-types-de-questions-sur-les-tables-existantes.md) · [UDR-0087](../../decisions/udr/0087-parcours-d-exercice-eleve-mode-concentre-et-nouveaux-types-de-questions.md).
> **Prérequis** : la PR [`accueil-eleve`](../accueil-eleve/plan.md) est fusionnée (en-tête, menus). Le plus gros chantier de la série : une session à lui seul, une seule PR, un commit par lot (9 commits).

## Graphe

```
Lot 0 — SOCLE (séquentiel : schéma, domaine, queries, import, formulaire équipe)
  ↓
  ├─► Lot A  Séance en mode concentré ┐
  ├─► Lot B  Page de l'exercice        ├─ en parallèle
  └─► Lot C  Résultat                  ┘
  ↓ (A et C)
  ├─► Lot D  Texte à trous   ┐
  ├─► Lot E  Nombre          ├─ en parallèle
  ├─► Lot F  Ordre           │
  └─► Lot G  Relier          ┘
  ↓
Lot H — PREUVE ET CLÔTURE
```

---

## Lot 0 — Socle

- **Couche**       : infrastructure (schéma, queries, import) + domaine (contrats) + delivery (paramètres) + config
- **Fichiers**     : `db/migrate/…_add_question_kinds.rb` · `db/schema.rb`
                     `app/domain/entities/assessment/question.rb` *(délégation au type ; `TYPES` = 8)*
                     `app/domain/entities/assessment/question_kinds/choice.rb` *(les 4 types actuels, comportement identique)*
                     `app/domain/entities/assessment/question_kinds/{fill_blank,numeric,ordering,matching}.rb` *(squelettes : `structure_errors` rend `:not_available`, donc rien ne se crée avant leur lot)*
                     `app/domain/entities/assessment/answer_shuffle.rb` *(mélange déplacé de `SessionPlayQuery`, gelé)*
                     `app/domain/dtos/assessment/{attempt_input,question_input,answer_input}.rb` · `app/domain/use_cases/assessment/submit_question_attempt.rb`
                     `app/infrastructure/repositories/assessment/{exercise_repository,exercise_session_repository}.rb` · `app/infrastructure/repositories/catalog/content_tree_writer.rb`
                     `app/infrastructure/queries/assessment/{session_play_query,session_result_query,exercise_detail_query}.rb` *(données par type, sans fuite)*
                     `config/schemas/lnclass.{exercises,essentials,course-tree}.v1.json` · `app/domain/entities/catalog/content_node.rb` · `app/domain/use_cases/assessment/import_exercises.rb` · `app/domain/use_cases/catalog/{import_essentials,import_course_tree}.rb`
                     `app/controllers/assessment/question_attempts_controller.rb` · `app/controllers/teams/exercises_controller.rb` *(paramètres)*
                     `app/views/teams/exercises/_question_fields.html.erb` *(aiguillage vers `kinds/_<type>_fields`)* · `app/views/teams/exercises/kinds/_choice_fields.html.erb`
                     `config/locales/assessment/*.fr.yml` · `config/locales/teams/exercises.fr.yml` · `config/locales/teams/import_*.fr.yml` *(toutes les clés du chantier)*
- **Dépend de**    : PR `accueil-eleve` fusionnée
- **Test associé** : `test/domain/entities/assessment/question_test.rb` (les 4 types actuels inchangés) · `test/domain/entities/assessment/answer_shuffle_test.rb` (mélange figé) · `test/infrastructure/queries/assessment/session_play_query_test.rb` (CA-9 côté données) · `test/domain/use_cases/assessment/import_exercises_test.rb` (CA-14, fichier v1 actuel) · `test/domain/use_cases/assessment/submit_question_attempt_test.rb` (indices d'affichage → ids)
- **Done quand**   : toute la suite actuelle passe sans changement de comportement ; les contrats `QuestionKinds`, `AttemptInput`, les queries et les schémas sont gelés

---

## Lot A — Séance en mode concentré (CA-1 à CA-3)

- **Couche**       : UI
- **Fichiers**     : `app/views/layouts/shell.html.erb` *(`content_for :focus`)*
                     `app/views/assessment/exercise_sessions/{show,_question_card,_feedback_card,_progress_bar}.html.erb` · `_quit_dialog.html.erb` *(nouveau)*
                     `app/views/assessment/exercise_sessions/kinds/_choice.html.erb` · `kinds/_choice_feedback.html.erb` *(aiguillage par type)*
                     `app/views/assessment/question_attempts/create.turbo_stream.erb`
                     `test/system/assessment/exercise_session_test.rb` · `test/controllers/assessment/exercise_sessions_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/system/assessment/exercise_session_test.rb` (CA-1, CA-2, CA-3 à 390 et 1 280 px, choix existants)
- **Done quand**   : une séance de Vrai / Faux et de choix se fait de bout en bout en mode concentré, en clair et en sombre

---

## Lot B — Page de l'exercice (CA-15, CA-16)

- **Couche**       : UI
- **Fichiers**     : `app/views/assessment/exercises/{show,_student_progress,_questions_preview}.html.erb`
                     `test/system/assessment/exercise_page_test.rb` · `test/controllers/assessment/exercises_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/system/assessment/exercise_page_test.rb` (nouveau, en cours, déjà fait ; CA-15) · `test/controllers/assessment/exercises_controller_test.rb` (CA-16)
- **Done quand**   : la page suit les maquettes au téléphone, sur tablette et sur ordinateur

---

## Lot C — Résultat (CA-11, CA-12)

- **Couche**       : UI
- **Fichiers**     : `app/views/assessment/session_results/{show,_question_review,_badge,_progress}.html.erb` · `kinds/_choice_review.html.erb`
                     `test/system/assessment/session_result_test.rb` · `test/controllers/assessment/session_results_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/system/assessment/session_result_test.rb` (CA-11) · `test/domain/use_cases/assessment/close_exercise_session_test.rb` (CA-12, relancé)
- **Done quand**   : le résultat suit les maquettes ; « Recommencer » est caché à 20/20

---

## Lots D, E, F, G — Un type de question par lot (CA-4 à CA-10, CA-13)

Chaque lot a la même forme ; `<type>` vaut `fill_blank` (D), `numeric` (E), `ordering` (F), `matching` (G).

- **Couche**       : domaine + UI
- **Fichiers**     : `app/domain/entities/assessment/question_kinds/<type>.rb` *(règles d'ADR-0091 §4.3)*
                     `app/views/assessment/exercise_sessions/kinds/_<type>.html.erb` · `kinds/_<type>_feedback.html.erb`
                     `app/views/assessment/session_results/kinds/_<type>_review.html.erb`
                     `app/javascript/controllers/assessment/<type>_controller.js` *(sauf D si un champ simple suffit)*
                     `app/views/teams/exercises/kinds/_<type>_fields.html.erb`
                     `app/views/teams/imports/kinds/_<type>_example.html.erb`
                     `test/domain/entities/assessment/question_kinds/<type>_test.rb` · `test/system/assessment/question_<type>_test.rb`
- **Dépend de**    : Lots A et C
- **Test associé** : D : CA-4 · E : CA-5, CA-6 · F : CA-7, CA-10 · G : CA-8 · tous : CA-9 (HTML sans solution) et CA-13 (saisie par l'équipe)
- **Done quand**   : une question du type se crée (formulaire et import), se joue au doigt et au clavier, se corrige sans révéler la solution

---

## Lot H — Preuve et clôture

- **Couche**       : docs + preuve
- **Fichiers**     : `journal.md` · `prd.md` *(§7 « Après »)* · `docs/chantiers/README.md` · index ADR/UDR *(par `script/docs/build_index`)* · statut d'ADR-0091 et d'UDR-0087
- **Dépend de**    : Lots B, D, E, F, G
- **Test associé** : `bin/ci-quiet` vert, verdict copié dans la PR · `security-reviewer` (fuite de la solution, paramètres), `silent-failure-hunter`, `pr-test-analyzer` sur le diff final
- **Done quand**   : captures envoyées (390 px et ordinateur : page de l'exercice, une question de chaque type, bonne et mauvaise réponse, quitter, résultat, sombre), PR ouverte prête

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `db/**` · `app/domain/**` sauf `question_kinds/<nouveau type>.rb` | Lot 0 |
| `app/infrastructure/**` · `config/schemas/**` · `config/locales/**` | Lot 0 |
| `app/controllers/**` · `app/views/teams/exercises/_question_fields.html.erb` · `kinds/_choice_fields.html.erb` | Lot 0 |
| `app/views/layouts/shell.html.erb` · `app/views/assessment/exercise_sessions/*` (hors `kinds/_<nouveau type>*`) · `app/views/assessment/question_attempts/**` | Lot A |
| `app/views/assessment/exercises/**` | Lot B |
| `app/views/assessment/session_results/*` (hors `kinds/_<nouveau type>_review`) | Lot C |
| `question_kinds/fill_blank.rb` et tous les fichiers `*fill_blank*` | Lot D |
| `question_kinds/numeric.rb` et tous les fichiers `*numeric*` | Lot E |
| `question_kinds/ordering.rb` et tous les fichiers `*ordering*` | Lot F |
| `question_kinds/matching.rb` et tous les fichiers `*matching*` | Lot G |

## Risques à surveiller

- **Fuite de la solution** : ids dans le HTML, `data-` attributs, valeur attendue dans un `<template>`. CA-9 se vérifie par un test qui lit le HTML brut.
- **`AnswerShuffle` gelé** : le déplacer sans changer son résultat ; une session ouverte avant la PR doit se reprendre à l'identique.
- **Import par COPY** (`ContentTreeWriter`) : les colonnes doivent suivre l'ordre du COPY.
- **Shell partagé** : le mode concentré ne s'active que par `content_for :focus`.
- **Budget JS** (ADR-0051) : quatre petits contrôleurs, pas de bibliothèque de glisser-déposer.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md` *(ADR-0091 écrit ; index à la clôture)*
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md` *(UDR-0087 écrite ; index à la clôture)*
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord *(chaque CA a son test ; rouge d'abord pour le domaine des quatre types, pas pour les vues)*
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [x] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [x] `journal.md` clos (dérapages, dette, chantiers de suivi)
