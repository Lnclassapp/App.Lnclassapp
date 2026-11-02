# ADR-0113 : L'exercice appartient à la leçon, porte un sujet, et la notion n'a plus de page
<!-- index
titre: Exercice de leçon avec sujet, notion sans page
statut: Accepté
problematique: Les exercices vivent sous des pages de notion que la fiche de révision rend inutiles ; il faut des exercices sur toute la leçon, un sujet commun, et garder la notion pour les lacunes.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-28 |
| **Chantier** | `docs/chantiers/refonte-page-lecon` |
| **Remplace** | — (amende ADR-0035 sur le rattachement d'un exercice, ADR-0090 §4.1 sur le moment de la lecture) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Depuis ADR-0035, un exercice appartient à une notion (« fiche essentielle ») : `exercises.essential_id` est obligatoire et la position est unique par notion. L'élève lit une notion sur sa page, puis ouvre ses exercices depuis cette page ; l'enseignant assigne depuis cette page aussi. ADR-0090 enregistre la lecture d'une notion quand l'élève ouvre sa page.

La fiche à l'identique des maquettes (ADR-0110) contient déjà tout le texte des notions. Le porteur a tranché (memo, Q1, Q3, Q9 à Q12) :

- la page de notion disparaît ; la leçon a deux sections, « Fiche de révision » et « Prépare interros » ;
- « Prépare interros » contient **un exercice par notion, puis quatre exercices sur toute la leçon** ;
- chaque exercice a un **sujet** (énoncé commun, comme une feuille) avant ses questions ;
- la notion reste une donnée : elle rattache un exercice et une lacune, son titre sert d'intertitre ;
- tout arrive par l'import ; les exercices actuels sont remplacés (pas d'utilisateurs réels).

Un exercice « toute la leçon » n'a pas de notion : le modèle actuel ne sait pas le représenter.

## 2. Moteurs de décision

1. Représenter l'exercice de toute la leçon sans inventer une fausse notion.
2. Garder la lacune (« Notion à revoir ») sur une notion précise, sans la casser pour les exercices de leçon.
3. Ne pas multiplier les tables : le chantier touche déjà la page de la leçon, la session et l'import.
4. Un contenu toujours complet : la règle « 1 par notion + 4 sur la leçon » se vérifie à l'entrée, pas à l'affichage.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — `exercises.course_id` obligatoire, `essential_id` facultatif ; `description` devient `statement` | Une colonne en plus ; un exercice de notion garde sa notion pour la lacune ; la leçon liste ses exercices en une requête | — retenue |
| B — Une notion technique « Toute la leçon » par leçon | Aucun changement de schéma | Une notion fausse s'afficherait partout (lacunes, lectures, rang des matières) et chaque requête devrait l'exclure |
| C — Une table de sujets qui regroupe des exercices | Sépare le sujet des questions | Deux objets pour une seule chose vue par l'élève ; l'assignation (ADR-0072) porte sur l'exercice, il faudrait la migrer |
| D — Garder la page de notion, masquée | Rien à migrer | Contredit Q1 ; garde des écrans d'édition que personne ne doit plus utiliser |

## 4. Décision

> **Nous rattachons chaque exercice à sa leçon (`course_id`, obligatoire) et, s'il est de notion, à sa notion (`essential_id`, facultatif). L'exercice porte un sujet (`statement`, texte avec formules). La notion n'a plus de page : ses anciennes adresses redirigent vers la page de la leçon. L'import `lnclass.course-tree` v2 est la seule porte d'entrée des exercices et refuse une leçon qui n'a pas exactement un exercice par notion et quatre exercices de toute la leçon. Les exercices existants sont archivés.**

Précisions :

1. **Ordre de « Prépare interros »** : exercices de notion dans l'ordre des notions, puis exercices de toute la leçon par `position`. La position est unique par leçon (`course_id, position`), et non plus par notion.
2. **Lacune** : `CloseExerciseSession` n'ouvre, n'incrémente ni ne résout une lacune que si l'exercice a une notion. Un exercice de toute la leçon n'en produit jamais.
3. **Lecture (amende ADR-0090 §4.1)** : ouvrir la page de la leçon, pour un élève, enregistre la lecture de chacune de ses notions publiées, par le use case existant `RecordEssentialRead` (aucun port nouveau). Le rang des matières et l'accueil restent inchangés. Pas de préchargement au survol, comme aujourd'hui.
4. **Import v2** :
   - `essentials[].exercises[]` : exactement un exercice par notion *(amendé le 2026-10-31 : un ou deux, voir ADR-0116)* ;
   - `exercises[]` à la racine de la leçon : exactement quatre ;
   - chaque exercice : `title`, `statement` (obligatoire), `exercise_type` (`fixation` ou `evaluation`), `questions[]` (format des questions v1 inchangé) ;
   - une leçon qui ne tient pas la règle est refusée entière, avec la notion en cause ;
   - un fichier v1 reste lu pour la leçon et ses notions ; ses exercices sont ignorés, avec un avertissement dans le rapport ;
   - le type d'import `exercises` (`lnclass.exercises`, exercices d'une notion seule) est retiré : il contournerait la règle.
5. **Archivage** : une migration de données archive tous les exercices existants (`status = archived`, `archived_at` posé). Ils ne sont pas supprimés : leurs sessions restent lisibles. Leurs assignations actives sont archivées dans la même migration (pas d'utilisateurs réels, Q5).
6. **Édition** : les écrans de création et d'édition d'une notion et d'un exercice (espace équipe) sont retirés ; la publication en cascade reste (ADR-0035).

## 5. Conséquences

### 🟢 Positives

- Une requête par leçon liste ses exercices, sans passer par les notions.
- La lacune garde son sens : elle pointe toujours une notion réelle.
- Le contenu d'une leçon arrive complet ou n'arrive pas.

### 🔴 Coûts consentis

- `essential_id` facultatif : chaque lecture qui suppose une notion (lacunes, résultat, suivi de classe) doit traiter l'exercice de leçon.
- Les 215 leçons n'ont aucun exercice visible jusqu'au réimport du chantier contenu (accepté, Q5).
- La redondance entre `course_id` et la leçon de la notion doit rester cohérente : le repository, seule voie d'écriture, la contrôle (voir §6).
- Deux formats d'import à lire pendant la transition.
- L'équipe ne corrige plus une coquille d'exercice à l'écran : elle réimporte la leçon.

## 6. Notes d'implémentation

```ruby
# db/migrate/XXXX_attach_exercises_to_courses.rb
add_reference :exercises, :course, foreign_key: true, null: true
execute <<~SQL
  UPDATE exercises SET course_id = essentials.course_id
  FROM essentials WHERE essentials.id = exercises.essential_id
SQL
change_column_null :exercises, :course_id, false
change_column_null :exercises, :essential_id, true
rename_column :exercises, :description, :statement
remove_index :exercises, name: "index_exercises_on_essential_id_and_position"
add_index :exercises, [ :course_id, :position ], unique: true
```

```ruby
# db/migrate/XXXX_archive_exercises_before_lesson_redesign.rb (migration de données, irréversible)
execute "UPDATE classroom_assignments SET status = 'archived', archived_at = NOW() WHERE status <> 'archived'"
execute "UPDATE exercises SET status = 'archived', archived_at = NOW() WHERE status <> 'archived'"
```

La position actuelle est unique par notion : avant l'index unique par leçon, la migration renumérote (`ROW_NUMBER() OVER (PARTITION BY course_id ORDER BY essential position, exercise position)`).

```ruby
# app/domain/entities/assessment/exercise.rb
attr_accessor :course_id, :essential_id # essential_id nil : exercice de toute la leçon
validates :course_id, presence: true
def lesson_wide? = essential_id.nil?
```

```ruby
# app/domain/use_cases/assessment/close_exercise_session.rb : pas de lacune sans notion
return no_gap if essential_id.nil?
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/assessment/exercise_test.rb` : un exercice sans `course_id` est invalide ; sans `essential_id`, il est valide et `lesson_wide?`.
- `test/domain/use_cases/catalog/import_course_tree_test.rb` : refus d'une leçon v2 sans exercice pour une notion, et avec 3 exercices de leçon ; avertissement v1.
- `test/domain/use_cases/assessment/close_exercise_session_test.rb` : aucun appel au port des lacunes pour un exercice de leçon.
- `test/controllers/catalog/essentials_controller_test.rb` : 301 vers la page de la leçon, ancre `#notion-<slug>`.
- Test du repository des exercices : refus d'une notion d'une autre leçon.
- `bin/rails routes | grep -E "new_team_.*essential|edit_team_.*essential|new_team_.*exercise|edit_team_.*exercise"` ne rend rien.
