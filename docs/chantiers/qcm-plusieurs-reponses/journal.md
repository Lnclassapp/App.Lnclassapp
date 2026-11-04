# Journal — Un QCM à plusieurs bonnes réponses refuse tout l'exercice sans dire pourquoi

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

### Rapport de root cause

**Chaîne d'appels.** Formulaire de la feuille (`catalog/courses/sheets/_exercise` → `_question` → `_choice`) → `POST /exercises/:id/sheet_check` → `Assessment::SheetChecksController#create` → `UseCases::Assessment::CheckExerciseOnSheet` → `SubmitExerciseCopy#grade` → `attempt_for` → `Question#well_formed?` → `QuestionKinds::Choice.well_formed?` (`app/domain/entities/assessment/question_kinds/choice.rb:28-29`) : `ids.size == question.expected_count` est faux pour une seule case cochée sur deux attendues → `{ answer_ids: [:wrong_selection] }` pour la question 5 → `Result.failure(:invalid, errors: { 5 => … })`.

**Cause.** Deux trous, dans la livraison, pas dans le domaine (la règle « autant de propositions que de bonnes réponses » est voulue, ADR-0054, et le lecteur d'exercice l'annonce) :
1. La feuille n'annonce pas le nombre de propositions attendues : `PrepareSheetsQuery::Question` ne porte que `multiple` (`app/infrastructure/queries/catalog/prepare_sheets_query.rb:35`), et `_question.html.erb:51` n'en fait qu'un rôle ARIA (`group` au lieu de `radiogroup`). Le lecteur d'exercice affiche `question_card.hint` (« Coche %{count} propositions. », `assessment/exercise_sessions/kinds/_choice.html.erb:7`).
2. Le refus jette les erreurs par question : `SheetChecksController#error_code` (`app/controllers/assessment/sheet_checks_controller.rb:73`) ramène tout `:invalid` à `:invalid_copy`, dont le texte parle d'un nombre (`config/locales/assessment/sheet_checks.fr.yml:12`).

En une phrase, sans les mots du symptôme : la feuille de cahier ne transmet à l'élève ni la consigne de sélection que le domaine applique, ni la question que le domaine désigne en la refusant.

**Pourquoi aucun test ne l'a vu.** `sheet_checks_controller_test` teste `:invalid_copy` avec une réponse en nombre illisible et vérifie le texte général ; aucun test de la feuille n'a de QCM à plusieurs bonnes réponses coché à moitié, et aucun ne vérifie que la feuille annonce le nombre de propositions. Le test de reproduction va au niveau contrôleur (le refus et son texte), plus un test de requête (le nombre attendu) et un test système (l'annonce).

### Test rouge, trou comblé, effets de bord

**Rouge d'abord (bonne raison).** `sheet_checks_controller_test` : « un QCM à deux bonnes réponses coché à moitié » (cinquième question, `multiple_correct_2`, une seule proposition postée) échoue ainsi, avant tout correctif :

```
expected: "Question e : coche 2 réponses."
actual:   "Une réponse n'est pas lisible : vérifie-la (un nombre est attendu pour un calcul), puis réessaie."
```

Rouges aussi : requête (`NoMethodError: undefined method 'expected'`), système (`p.ps-instruction` introuvable), deux questions fautives, copie illisible dans sa forme (message encore « un nombre est attendu »), nombre illisible (« Question a : écris un nombre, par exemple -3,5. »).

**Trou comblé.** Tests ajoutés : refus nommé (contrôleur, Turbo Stream), deux lignes pour deux questions fautives, QCM multiple bien coché passe, copie illisible dans sa forme, `expected` de la requête (1, 2, 3, vrai ou faux), annonce « Coche 2 réponses. » et refus nommé sur la feuille (système). Deux tests existants adaptés au nouveau texte du refus d'un nombre illisible.

**Effets de bord écartés.** Domaine inchangé (règle du nombre exact). QCM à une réponse : pas d'annonce, `radiogroup` conservé ; copie juste : 303 vers la page de résultat (tests existants verts). `bin/rails test test/controllers/assessment test/infrastructure/queries/catalog test/domain/entities/assessment` : 529 runs, 0 échec ; `test/controllers/catalog` et `classroom` : 563 runs, 0 échec ; `bin/system-changed` : 42 runs, 0 échec. Les réponses de l'élève restent cochées au refus (système).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
