# ADR-XXXX : Le sujet de devoir et l'indice entrent dans le catalogue, et la copie se rend depuis la feuille de la leçon
<!-- index
titre: Sujets de devoir, indice et copie rendue depuis la feuille
statut: Proposé
problematique: Les maquettes « Prépare interros » et « Prépare devoirs » demandent un sujet de devoir, un indice et une copie vérifiée sans quitter la page de la leçon, que l'application ne connaît pas
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-30 |
| **Chantier** | `docs/chantiers/prepare-interros-cahier` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Touré demande que « Prépare interros » et « Prépare devoirs » reprennent ses maquettes telles quelles. Trois choses y
manquent à l'application :

- **le sujet de devoir** : un titre, une phrase « Notions mobilisées » et quatre exercices qui mélangent les notions. Un
  exercice appartient aujourd'hui à une notion ou à « Toute la leçon », rien ne les regroupe en sujet ;
- **l'indice** : une phrase par exercice, montrée avant la vérification ;
- **la vérification sur place** : « Vérifier ma réponse » rend une copie et la corrige dans la feuille. Aujourd'hui une
  copie demande deux pages (`POST /exercises/:id/sessions` puis `POST /sessions/:id/copy`) et finit sur la page de résultat.

La maquette note sur 10 avec « Excellent » dès 9 ; l'ADR-0115 note sur 20. Le memo (Q2) laisse ce point au porteur.

## 2. Moteurs de décision

- Le design des maquettes s'applique tel quel.
- Une vérification reste une vraie copie : note de l'enseignant, maîtrise, badge, pause de 3 copies (ADR-0115) inchangés.
- Le sujet et l'indice s'écrivent dans le fichier d'import de la leçon, comme le reste du contenu.
- Le domaine ne connaît ni ActiveRecord ni Turbo.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Une table `subjects`, `exercises.subject_id` | Un sujet a son titre, ses notions, son ordre ; un exercice n'est que dans un sujet | **Retenue** |
| B — Un sujet = un exercice « évaluation » dont les parties sont les exercices de la maquette | Aucune table | Une partie n'aurait ni sa copie, ni « Vérifier », ni « Refaire » : la maquette en a un par exercice |
| C — Le sujet comme libellé texte sur l'exercice | Une colonne | Titre et notions recopiés sur chaque exercice ; pas d'ordre des sujets |
| D — Garder les deux pages de la copie, la feuille n'étant qu'un lien | Rien à écrire côté serveur | Contraire à la maquette : l'élève quitte la feuille |
| E — Un nouveau use case qui recalcule la note | Une seule transaction écrite d'un bloc | Doublerait les règles de `SubmitExerciseCopy` ; on compose les deux use cases existants |

## 4. Décision

> **Nous ajoutons au catalogue le sujet de devoir (table `subjects` : cours, position, titre, notions mobilisées ; un
> exercice de sujet n'a pas de notion) et l'indice d'un exercice (`exercises.hint`, facultatif), tous deux écrits par
> l'import `course_tree`. La feuille rend une copie par `POST /exercises/:exercise_public_id/sheet_check`, servi par
> `UseCases::Assessment::CheckExerciseOnSheet`, qui enchaîne `StartExerciseSession` (restart: true) et
> `SubmitExerciseCopy` dans une transaction et répond en Turbo Stream. La note de la feuille se lit sur la copie par
> `Entities::Assessment::SheetGrade` : sur 10, au demi-point, mention de la maquette (≥ 9 Excellent, ≥ 7 Très bien,
> ≥ 5 Assez bien, sinon À retravailler), sous réserve du porteur (memo Q2).**

## 5. Conséquences

### 🟢 Positives

- Une vérification depuis la feuille est la même copie qu'aujourd'hui : rien ne change pour l'enseignant ni pour les badges.
- Le sujet est une donnée : un professeur pourra l'assigner plus tard sans nouvelle migration.
- La page de l'exercice et celle du résultat restent pour les exercices assignés.

### 🔴 Coûts consentis

- Deux migrations et une table de plus ; l'import `course_tree` apprend deux clés (`hint`, `subjects`).
- Si le porteur garde la maquette, la note s'affiche sur 10 dans la feuille et sur 20 ailleurs, pour la même copie.
- Une vérification sur la feuille ouvre et ferme une session dans la même requête : une copie de plus compte pour la pause.
- `PrepareInterrosQuery` est remplacée par `PrepareSheetsQuery`, qui lit en plus les questions, l'indice, les sujets et la
  dernière copie de l'élève par exercice : la page de la leçon lit plus de données (mesure au PRD §7).

## 6. Notes d'implémentation

```ruby
# db/migrate/…_add_hint_to_exercises.rb
add_column :exercises, :hint, :text
add_check_constraint :exercises, "hint IS NULL OR char_length(btrim(hint)) BETWEEN 1 AND 400", name: "exercises_hint_length"

# db/migrate/…_create_subjects.rb
create_table :subjects do |t|
  t.references :course, null: false, foreign_key: true
  t.integer :position, null: false
  t.string :title, null: false, limit: 200
  t.text :notions, null: false
  t.timestamps
end
add_index :subjects, %i[course_id position], unique: true
add_reference :exercises, :subject, foreign_key: true, index: true
add_check_constraint :exercises, "subject_id IS NULL OR essential_id IS NULL", name: "exercises_subject_without_essential"
```

```ruby
# app/domain/use_cases/assessment/check_exercise_on_sheet.rb
# → Result(Submitted) | :not_found | :forbidden | :conflict (pause : resume_at) | :invalid
def call(actor:, exercise_public_id:, answers:)
  @transaction.call do
    started = @start.call(actor:, exercise_public_id:, restart: true)
    next started if started.failure?

    @submit.call(actor:, dto: Dtos::Assessment::ExerciseCopy.new(session_public_id: started.value.public_id, answers:))
  end
end
```

Import `course_tree` : sous un cours, `"subjects": [{ "title": "Sujet 1 · …", "notions": "…", "exercises": [ … ] }]` ;
sous un exercice, `"hint": "…"`.

## 7. Comment vérifier que la décision est respectée

- `test/domain/use_cases/assessment/check_exercise_on_sheet_test.rb` : une copie terminée, la pause rend `:conflict`.
- `test/domain/entities/assessment/sheet_grade_test.rb` : 4 justes sur 5 → 8 / 10, « Très bien ».
- La contrainte `exercises_subject_without_essential` refuse un exercice de sujet rattaché à une notion.
- `test/domain/use_cases/catalog/import_course_tree_test.rb` : indice et sujet importés ; sujet avec notion refusé.
