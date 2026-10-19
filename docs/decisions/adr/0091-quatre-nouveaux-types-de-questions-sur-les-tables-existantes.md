# ADR-0091 : Quatre nouveaux types de questions (trous, nombre, ordre, relier) sur les tables existantes, notés tout juste ou faux
<!-- index
titre: Texte à trous, nombre, ordre et relier sur les tables existantes
statut: Accepté
problematique: Ajouter quatre types de questions à un moteur qui ne connaît que « cocher des propositions », sans changer la note, sans montrer la bonne réponse à l'élève et sans la laisser deviner dans la page
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-15 |
| **Chantier** | [`docs/chantiers/exercice-eleve`](../../chantiers/exercice-eleve/memo.md) |
| **Amende** | [ADR-0054](0054-moteur-d-evaluation-soumission-et-cloture.md) (moteur d'évaluation) · [ADR-0039](0039-format-d-import-du-contenu.md) (format d'import) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le porteur a demandé quatre nouveaux types de questions (memo `exercice-eleve`, 2026-10-15) :

- **texte à trous** : un champ dans la phrase ;
- **réponse en nombre** ;
- **remettre dans l'ordre** : flèches monter et descendre ;
- **relier** : toucher à gauche puis à droite.

Il a aussi tranché la notation :
- **Trous** : la réponse est juste sans tenir compte des majuscules, des accents ni des espaces en trop. L'enseignant peut saisir plusieurs réponses justes. Une faute de frappe est fausse.
- **Nombre** : l'enseignant peut fixer une marge par question ; sans marge, seule la valeur exacte est juste. « 3,5 » et « 3.5 » valent pareil.
- **Ordre et relier** : la question est juste seulement si tout est juste, sans points partiels.

Aujourd'hui, tout le moteur suppose « cocher parmi des propositions » :

- `questions.question_type` est limité par un CHECK à `true_false`, `single_choice`, `multiple_correct_2` et `multiple_correct_3` ;
- `answers` n'a que `content` et `correct` ;
- `question_attempts.selected_answer_ids bigint[]` doit être non vide ;
- `Question#correct?` compare deux ensembles d'ids ;
- le formulaire de l'équipe, l'import JSON (`lnclass.exercises.v1.json` et ses deux cousins), `SessionPlayQuery`, la carte de la question et la correction ne connaissent que ce cas.

**Contrainte de sécurité** : l'élève ne doit jamais voir ni pouvoir lire la bonne réponse (UDR-0022, UDR-0023).
- Les ids des propositions sont créés dans l'ordre des positions : envoyer à la page les ids des étapes d'un « ordre » ou des éléments de droite d'un « relier » suffirait à retrouver la solution.
- Envoyer la valeur attendue d'un « nombre » ou d'un « trou » la donnerait directement.

## 2. Moteurs de décision

1. Ne jamais exposer la solution dans le HTML, même mélangée.
2. Ne pas toucher au calcul de la note, aux badges ni aux lacunes : tout juste ou faux par question (ADR-0033, ADR-0043, ADR-0054).
3. Peu de migrations, sur les tables existantes ; pas de JSON libre là où une colonne suffit.
4. Pouvoir livrer les types un par un, en parallèle, sans que deux lots touchent le même fichier.
5. Garder la logique de notation en Ruby pur dans le domaine.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Une table par type (`blank_answers`, `numeric_answers`, `match_pairs`…) | Schéma explicite | Quatre tables, quatre repositories, un import réécrit ; disproportionné pour des données de quelques lignes |
| B — Colonnes `payload jsonb` sur `questions` et `question_attempts` | Souple | Validation hors base, ce que le projet évite (contraintes en base partout) ; l'import COPY devient plus complexe |
| C — Réutiliser `answers` et ajouter trois colonnes ciblées | Les propositions restent des lignes ordonnées ; une colonne par besoin nouveau | Retenue |

## 4. Décision

> **Nous gardons `answers` comme liste ordonnée des éléments d'une question pour les quatre nouveaux types, nous ajoutons trois colonnes (`questions.numeric_tolerance`, `answers.match_content`, `question_attempts.response_text`), nous notons chaque type tout juste ou faux dans une classe de domaine par type, et la page de l'élève ne reçoit jamais ni id ni valeur qui révèle la solution.**

### 4.1 Schéma (une migration)

| Table | Changement |
|---|---|
| `questions` | CHECK `questions_question_type_values` étendu à `fill_blank`, `numeric`, `ordering`, `matching` ; colonne `numeric_tolerance decimal(12,4)` nullable, CHECK `numeric_tolerance >= 0` |
| `answers` | colonne `match_content varchar(500)` nullable |
| `question_attempts` | colonne `response_text varchar(200)` nullable ; le CHECK `cardinality(selected_answer_ids) > 0` devient `cardinality(selected_answer_ids) > 0 OR response_text IS NOT NULL` |

### 4.2 Ce que contient `answers`, par type

| Type | Lignes `answers` | `correct` | Autres |
|---|---|---|---|
| `fill_blank` | une réponse acceptée par ligne (1 à 5) | toutes `true` | `questions.content` contient exactement une fois `___` (trois tirets bas), là où s'affiche le champ |
| `numeric` | une seule ligne : la valeur attendue (« -3,5 ») | `true` | `questions.numeric_tolerance` : la marge, ou `NULL` pour la valeur exacte |
| `ordering` | les étapes, **dans le bon ordre** par `position` (3 à 6) | toutes `true` | — |
| `matching` | une paire par ligne (3 à 5) : `content` à gauche, `match_content` à droite | toutes `true` | les `match_content` sont distincts |

### 4.3 Notation (domaine, Ruby pur)

- `Entities::Assessment::Question` délègue `structure_errors`, `well_formed?` et `correct?` à une classe par type, sous `app/domain/entities/assessment/question_kinds/`. Les quatre types actuels passent dans `Choice`, sans changer de comportement.
- **`FillBlank#correct?(text)`** : la réponse est normalisée puis comparée à chaque réponse acceptée, normalisée de la même façon. La normalisation :
  - met en minuscules ;
  - décompose les accents (`unicode_normalize(:nfd)`) et retire les marques (`\p{Mn}`) ;
  - réduit les espaces à un seul ;
  - retire les espaces au début et à la fin.

  Aucune distance d'édition n'est appliquée.
- **`Numeric#correct?(text)`** : la saisie est lue en `BigDecimal`.
  - Formes acceptées : la virgule ou le point comme séparateur, le signe moins ASCII ou Unicode (`−`), les espaces des milliers.
  - Juste si `|saisie − attendue| ≤ marge` (marge 0 si `NULL`).
  - Une saisie illisible n'est pas `well_formed?` : l'élève voit une erreur de saisie, pas « Mauvaise réponse ».
  - Le point et la virgule sont toujours le séparateur décimal, jamais celui des milliers : « 1.000 » vaut 1, et « 1 000 » vaut mille.
  - La marge tient dans `decimal(12,4)` : finie, au plus 99 999 999,9999, quatre décimales au plus ; sinon `:tolerance_out_of_range`.
- **`Ordering#correct?(ids)`** : les ids reconstitués (§4.4) sont égaux aux ids triés par `position`.
- **`Matching#correct?(ids)`** : pour chaque élément de gauche pris dans l'ordre des positions, l'id de l'élément de droite choisi est le sien.
- **`Grading`** ne change pas : une question compte 1 ou 0.

### 4.4 Ne jamais révéler la solution dans la page

- **Trous et nombre** : `SessionPlayQuery` n'envoie aucune ligne `answers` pour ces types. Le formulaire poste `attempt[response_text]`.
- **Ordre et relier** :
  - **Affichage** : les éléments mélangés (les étapes, ou la colonne de droite) sont montrés dans l'ordre d'un mélange déterministe, propre à la session. Ce mélange est déjà utilisé pour les choix, et il passe dans le domaine : `Entities::Assessment::AnswerShuffle.for(session_public_id:, question_id:, ids:)`.
  - **Envoi** : le formulaire poste des **indices d'affichage** (`attempt[display_order][]`), jamais des ids.
  - **Lecture** : `SubmitQuestionAttempt` reconstitue les ids avec le même mélange, puis enregistre ces ids dans `selected_answer_ids`, dans l'ordre choisi par l'élève.
  - **Graine** : le mélange est tiré de `session_id ^ question_id`, l'id entier de la session (pas son `public_id`), pour que les sessions ouvertes avant ce chantier se reprennent à l'identique. Aucune surface élève (page, lien, donnée, message) ne doit donc exposer `exercise_sessions.id` : avec lui et l'id de la question, l'ordre d'affichage se recalculerait.
  - **Mélange identité** : pour l'ordre et relier seulement, si le mélange donne la solution telle quelle, il tourne d'un cran. Les choix ne changent pas.
  - **Colonne de gauche de « relier »** : elle est montrée dans l'ordre des positions, sans id.
- **« Ton choix »** (retour et correction) :
  - pour les trous et le nombre, le texte saisi (`response_text`) ;
  - pour l'ordre, les étapes dans l'ordre de l'élève ;
  - pour relier, les paires de l'élève.

  Jamais la bonne réponse (`RevealAnswersPolicy` inchangée : l'enseignant et l'équipe la voient).

### 4.5 Saisie et import

- **`QuestionInput` et `AnswerInput`** gagnent `numeric_tolerance` et `match_content`. `Question::TYPES` liste les huit types.
- **Formulaire de l'équipe** (`teams/exercises`) : un partial de champs par type.
- **Import** :
  - les trois schémas JSON (`lnclass.exercises.v1.json`, `lnclass.essentials.v1.json`, `lnclass.course-tree.v1.json`) gagnent deux propriétés facultatives : `tolerance` sur la question et `match` sur la réponse ;
  - la version reste `v1`, car un fichier valide aujourd'hui le reste ;
  - `ContentNode#question_errors` appelle les mêmes `structure_errors_for`.

## 5. Conséquences

### 🟢 Positives

- La note, les badges, les lacunes et la remédiation ne changent pas.
- Une classe par type : les quatre lots se codent en parallèle, sans collision.
- La solution n'est jamais dans le HTML ; l'ordre des ids ne fuit plus.
- L'import reste compatible avec les fichiers existants.

### 🔴 Coûts consentis

- **`answers.correct`** n'a plus de sens pour trois types (toujours `true`). La colonne est gardée pour ne pas réécrire les choix.
- **`match_content`** est vide pour sept types sur huit.
- **Une faute de frappe** dans un texte à trous est comptée fausse, ce qui peut frustrer. C'est le choix du porteur ; la règle se change dans `FillBlank` seul.
- **Indices d'affichage** : poster des indices au lieu d'ids lie la correction au mélange. Changer `AnswerShuffle` pendant qu'une session est ouverte fausserait la reprise : son algorithme est donc gelé, et un test le fige.
- **Taille** : c'est le plus gros chantier de la série. Il touche le domaine, l'import, la saisie de l'équipe et les trois écrans de l'élève.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/assessment/question_kinds/fill_blank.rb
# Rôle : texte à trous (ADR-0091 §4.3) : juste sans casse, accents ni espaces en trop
module Entities
  module Assessment
    module QuestionKinds
      class FillBlank
        MARKER = "___"

        def self.normalize(text) = text.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.squeeze(" ").strip

        def correct?(question, response_text)
          given = self.class.normalize(response_text)
          question.answers.any? { |answer| self.class.normalize(answer.content) == given }
        end
      end
    end
  end
end
```

```ruby
# db/migrate/…_add_question_kinds.rb (extrait)
remove_check_constraint :questions, name: "questions_question_type_values"
add_check_constraint :questions,
  "question_type IN ('true_false','single_choice','multiple_correct_2','multiple_correct_3','fill_blank','numeric','ordering','matching')",
  name: "questions_question_type_values"
add_column :questions, :numeric_tolerance, :decimal, precision: 12, scale: 4
add_column :answers, :match_content, :string, limit: 500
add_column :question_attempts, :response_text, :string, limit: 200
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/assessment/question_kinds/*_test.rb` : règles de §4.3. Pour les trous : « Côte d'Ivoire » = « cote d'ivoire » ; « Abidjn » est faux. Pour le nombre : « 3,5 » = « 3.5 », « −2 » est lu, la marge s'applique.
- `test/domain/entities/assessment/answer_shuffle_test.rb` : le mélange est figé pour une graine donnée.
- `test/infrastructure/queries/assessment/session_play_query_test.rb` : pour `fill_blank` et `numeric`, aucune réponse n'est lue ; pour `ordering` et `matching`, aucun id n'est dans les données de la page.
- `test/system/assessment/exercise_session_test.rb` : le HTML d'une question de chaque nouveau type ne contient ni la valeur attendue ni un id de proposition.
- `test/domain/use_cases/assessment/import_exercises_test.rb` : un fichier v1 actuel s'importe sans changement ; `tolerance` et `match` sont lus.
