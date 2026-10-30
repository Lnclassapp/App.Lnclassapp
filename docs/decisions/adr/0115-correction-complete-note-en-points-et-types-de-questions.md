# ADR-0115 : La copie vérifiée montre la correction complète, se note en points et accepte les questions d'un devoir
<!-- index
titre: Correction complète, note en points, choix dans une liste, réponse rédigée, cahier, pause
statut: Accepté
problematique: L'élève ne voit jamais la bonne réponse, chaque question vaut 1 point et la feuille ne sait pas poser les questions d'un devoir de 3e
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-28 |
| **Chantier** | `docs/chantiers/correction-comme-en-classe` |
| **Remplace** | — (amende ADR-0028 et la décision du 2026-09-25 sur la révélation ; amende ADR-0091 §4.2 pour les types) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Depuis le 2026-09-25, l'élève ne voit jamais la bonne réponse, même après sa copie : la crainte était qu'il refasse l'exercice
la correction sous les yeux. Une faute reste alors incomprise. Le porteur revient sur cette règle le 2026-10-28 (D1) et choisit
de garder la meilleure note, avec une pause de « Recommencer » pour freiner la copie de la correction (D2 révisée).

Les maquettes de Konan (Thalès, Lentilles, 3e) montrent aussi ce que Lnclass ne sait pas poser : une phrase à compléter par un
mot d'une liste, une réponse chiffrée avec son unité, une question à rédiger, une construction sur le cahier, un tableau ou un
document dans le sujet, et des questions qui valent plusieurs points. Le porteur exclut toute durée (D5) et toute note donnée
à la main ou par l'élève (D7) : seule la machine note.

## 2. Moteurs de décision

1. Ce que lit l'élève fait foi (ADR-0106) : la note sur 20 reste lue sur un seul score.
2. Aucun exercice en production ne change de note.
3. La machine ne note que ce qu'elle sait corriger ; rien ne repose sur l'honnêteté de l'élève.
4. Pas d'objet nouveau quand un existant suffit : les types de questions restent une classe de règles chacun (ADR-0091 §4.3),
   le sujet réutilise les blocs des fiches.
5. Un texte libre de l'élève, lu par l'enseignant, est une entrée hostile.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Seule la première copie compte (D2 d'origine) | Une note faite la correction vue ne compte jamais | Écartée par le porteur : l'élève et l'enseignant lisent la meilleure note partout aujourd'hui |
| B — Correction d'un devoir montrée après sa date limite | Protège la note du devoir | Écartée : un exercice libre n'a pas de date, et l'élève attend la correction tout de suite |
| C — Meilleure note, correction tout de suite, pause après 3 copies d'affilée | Garde les règles de note ; freine la copie de la correction | **Retenue** (D2 révisée) |
| D — Réponse rédigée notée par l'élève avec la grille | Compte tout le devoir | Écartée (D7) : avec la meilleure note, l'élève se mettrait 20/20 |
| E — Réponse rédigée notée par l'enseignant | Une vraie note de devoir | Hors périmètre : un chantier à part |
| F — Un type « liste de mots partagée » à l'échelle de l'exercice | Une seule liste pour 5 phrases | Écartée : un objet nouveau ; 5 questions « choix dans une liste » avec les mêmes propositions suffisent, et « Quelle propriété utiliser ? » réutilise une proposition deux fois, ce qu'une liste partagée ou une association ne permettent pas |

## 4. Décision

> **Nous montrons la correction complète à l'élève auteur d'une copie vérifiée, et à lui seul parmi les élèves.**

Une nouvelle `Policies::Assessment::RevealCorrectionPolicy` décide de la page du résultat : équipe et enseignant comme
`RevealAnswersPolicy`, élève auteur seulement si la copie est terminée (`completed`). La feuille garde `RevealAnswersPolicy` :
l'élève n'y voit jamais une bonne réponse. Une copie abandonnée n'a pas de résultat.

> **Nous notons une copie en points, sur les seules questions corrigées automatiquement.**

Chaque question a des `points` (décimal, de 0,5 à 20 par demi-point, 1 par défaut). Une question est **corrigée
automatiquement** si son type le dit (`kind::AUTO_GRADED`). Le score est la somme des points des questions justes, sur la
somme des points des questions corrigées automatiquement, arrondi vers le bas. La note sur 20, la maîtrise, le badge, les
lacunes et la meilleure note se lisent sur ce score, comme aujourd'hui. Avec toutes les questions à 1 point, le calcul est
celui d'aujourd'hui. Un exercice publiable a au moins une question corrigée automatiquement.

> **Nous ajoutons trois types de questions, chacun sa classe de règles.**

| Type (import) | Classe | Réponse | Corrigé automatiquement |
|---|---|---|---|
| `select` — choix dans une liste | `QuestionKinds::Select` | un identifiant de proposition | oui : juste si c'est la correcte |
| `written` — réponse rédigée | `QuestionKinds::Written` | un texte, 2 000 caractères au plus, vide admis | non |
| `notebook` — travail sur le cahier | `QuestionKinds::Notebook` | aucune | non |

- `select` : 2 à 10 propositions, une seule correcte ; `___` absent ou présent une fois.
- `written` : un corrigé type obligatoire (le champ `explanation`) ; un début de phrase `starter` facultatif (150 caractères) ;
  une grille `criteria` facultative (8 critères de 150 caractères au plus). La grille n'est jamais enregistrée côté élève.
- `notebook` : un corrigé type obligatoire, en texte.
- `numeric` gagne une `unit` facultative (10 caractères) : une réponse qui finit par cette unité, espaces compris, est lue sans
  elle.

> **Nous pausons « Recommencer » après 3 copies vérifiées d'affilée.**

`Entities::Assessment::RestartPause` lit les fins des 3 dernières copies terminées de l'élève sur l'exercice
(`ExerciseSessionRepositoryPort#recent_completions`, toutes sortes confondues). En pause si elles sont 3, si moins de
30 minutes séparent chaque fin de la suivante et si moins de 30 minutes ont passé depuis la 3e. `StartExerciseSession` refuse
alors (`:conflict`, `base: [:paused]`, avec l'heure de fin).

> **Nous écrivons le sujet d'un exercice en blocs, ceux des fiches.**

Un exercice garde son `statement` en texte et gagne `statement_blocks`, facultatif : une liste de 10 blocs au plus, de types
`paragraph`, `box` et `table`, validée par les règles de `Entities::Catalog::SheetDocument` et rendue par les partiels des
fiches (`catalog/course_sheets/blocks/`). Le document titré est un `box` ; le tableau un `table`.

> **Nous n'ajoutons aucune durée.** Ni chronomètre, ni copie rendue d'office (D5).

## 5. Conséquences

### 🟢 Positives

- L'élève comprend ses fautes ; l'enseignant lit la même correction et le texte rédigé.
- Les devoirs de 3e s'écrivent tels quels ; la note reste un fait de la machine.
- Aucun exercice existant ne change de note, ni de forme d'import : toutes les nouvelles clés sont facultatives.

### 🔴 Coûts consentis

- Un élève peut obtenir 20/20 à sa 2e copie, la correction sous les yeux, et c'est la note que lit l'enseignant. La pause le
  freine sans l'empêcher (risque accepté par le porteur).
- La note d'un devoir ignore ses réponses rédigées : « 14/20 » ne mesure qu'une partie du devoir. La page le dit (« 9 points à
  comparer au corrigé »).
- Une migration : 4 colonnes sur `questions`, une borne levée sur `question_attempts.response_text`, une colonne
  `statement_blocks` sur `exercises`.
- Un texte libre de 2 000 caractères par question, gardé et affiché à l'enseignant : une surface nouvelle (menace §7).
- Une question `written` ou `notebook` enregistre une tentative avec `correct: false` ; tout calcul qui compte les bonnes
  réponses doit passer par le score en points, jamais par `count(&:correct)` sur toutes les tentatives.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/assessment/grading.rb
# Points des questions justes sur points des questions corrigées automatiquement, arrondi vers le bas (ADR-0115).
# graded : [[points (BigDecimal), correct (Boolean)]] des seules questions corrigées automatiquement.
def self.points_percent(graded)
  total = graded.sum { |points, _| points }
  return 0 if total.zero?

  (graded.sum { |points, correct| correct ? points : 0 } * 100 / total).floor
end
```

```ruby
# app/domain/use_cases/assessment/close_exercise_session.rb — remplace Grading.score_percent(correct:, total:)
graded = questions.select(&:auto_graded?).map { |question| [ question.points, attempts_by_question[question.id]&.correct == true ] }
score_percent = Entities::Assessment::Grading.points_percent(graded)
```

```ruby
# db/migrate/…_add_points_and_kinds_to_questions.rb
add_column :questions, :points, :decimal, precision: 4, scale: 1, null: false, default: 1
add_column :questions, :unit, :string, limit: 10
add_column :questions, :starter, :string, limit: 150
add_column :questions, :criteria, :string, array: true, null: false, default: []
add_check_constraint :questions, "points >= 0.5 AND points <= 20 AND points * 2 = round(points * 2)", name: "questions_points_range"
change_column :question_attempts, :response_text, :string, limit: 2000
add_column :exercises, :statement_blocks, :jsonb
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/policies/assessment/reveal_correction_policy_test.rb` : élève auteur d'une copie terminée accepté ; en cours,
  abandonnée, autre élève refusés (CA-07).
- `test/domain/entities/assessment/grading_test.rb` : CA-14, CA-15 et CA-16 (un exercice tout à 1 point garde sa note).
- `test/domain/entities/assessment/question_kinds/{select,written,notebook}_test.rb` : chaque règle de structure.
- `test/domain/entities/assessment/restart_pause_test.rb` : CA-29 à CA-33.
- Menace, écrite au Lot 0 dans `docs/chantiers/correction-comme-en-classe/menace.md` : texte rédigé affiché échappé (CA-13),
  borné au contrôleur, au DTO et en base (CA-22) ; clés d'import bornées par le schéma et par l'adaptateur ; blocs du sujet
  validés par `SheetDocument`, jamais rendus en HTML brut.
