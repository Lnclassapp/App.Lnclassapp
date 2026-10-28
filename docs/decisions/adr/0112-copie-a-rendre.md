# ADR-0112 : Un exercice se fait en une copie rendue d'un seul envoi
<!-- index
titre: Copie à rendre
statut: Accepté
problematique: L'élève répond une question à la fois, sans voir le sujet ni revenir sur une réponse ; un exercice sur feuille demande de tout voir, de tout remplir, puis de rendre.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-28 |
| **Chantier** | `docs/chantiers/refonte-page-lecon` |
| **Remplace** | — (amende ADR-0054 : la soumission par question devient une soumission par copie ; la clôture et la note restent) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

ADR-0054 fait répondre l'élève **une question à la fois** : chaque réponse est un POST, corrigée et figée aussitôt ; la dernière clôt la session. Ce mode convient à un quiz, pas à un exercice qui a un sujet commun (ADR-0113) : l'élève doit pouvoir relire le sujet, répondre dans l'ordre qu'il veut, corriger une réponse, puis rendre, comme une interrogation sur feuille.

Le porteur a choisi la **copie à rendre** pour tous les exercices (memo, Q12) : l'ancien écran est retiré, le brouillon vit dans le navigateur, une réponse vide compte faux.

Contraintes existantes :

- `question_attempts` a une ligne unique par question et par session, et refuse une ligne sans réponse (`cardinality(selected_answer_ids) > 0 OR response_text IS NOT NULL`) ;
- aucune correction ne doit partir vers le navigateur avant la clôture (ADR-0091 §4.4) ;
- l'ordre affiché des propositions est un mélange par session, relu côté serveur (`AnswerShuffle`).

## 2. Moteurs de décision

1. Aucune bonne réponse dans la page avant le rendu (rien à lire dans le code source).
2. Une copie est notée une fois, entière, même en cas de double envoi.
3. Le téléphone d'un élève perd le réseau : une copie à moitié remplie ne doit pas se perdre.
4. Un seul chemin de réponse à maintenir.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Un seul POST « rendre » ; brouillon dans `localStorage` | Un aller-retour ; rien de stocké côté serveur avant le rendu ; pas de nouvelle table | — retenue |
| B — Brouillon enregistré côté serveur à chaque saisie | Reprise sur un autre appareil | Une écriture par saisie ; un état de plus ; la reprise sur un autre appareil n'a pas été demandée |
| C — Garder l'envoi par question, afficher toutes les questions | Peu de code changé | Une réponse est figée dès l'envoi : l'élève ne peut plus la changer, ce n'est plus une copie |
| D — Garder les deux modes | Personne ne perd son écran | Deux chemins, deux UDR, deux jeux de tests ; le porteur a choisi le retrait (Q12) |

## 4. Décision

> **Nous faisons rendre chaque exercice en une copie : la page montre le sujet et toutes les questions, l'élève remplit, puis un seul envoi enregistre toutes les réponses, corrige, note et clôt la session dans une transaction. Une question vide compte faux. Le brouillon reste dans le navigateur jusqu'au rendu. L'envoi question par question et son écran sont retirés.**

Précisions :

1. **Use case** `UseCases::Assessment::SubmitExerciseCopy#call(actor:, dto:)` :
   - verrouille la session (`find_by_public_id(lock: true)`), comme aujourd'hui ;
   - session déjà terminée → succès avec `already_closed: true`, **sans rien écrire** : le contrôleur redirige vers le résultat ;
   - session abandonnée, exercice archivé → `:conflict` ;
   - policy `SubmitAttemptPolicy` inchangée ;
   - lit chaque réponse de `Dtos::Assessment::CopyInput` (une `AttemptInput` par question de l'exercice ; une question étrangère → `:invalid`) ;
   - une réponse présente mais mal formée (`question.well_formed?` faux) → `:invalid`, erreurs rangées par numéro de question, **rien n'est écrit** ;
   - une question absente ou vide → tentative `correct: false, unanswered: true` ;
   - écrit toutes les tentatives par `ExerciseSessionRepositoryPort#record_copy`, puis appelle `CloseExerciseSession`, dans la même transaction.
2. **Schéma** : `question_attempts.unanswered boolean NOT NULL DEFAULT false` ; la contrainte devient `unanswered OR cardinality(selected_answer_ids) > 0 OR response_text IS NOT NULL`.
3. **Route** : `POST /sessions/:public_id/copy` (`Assessment::ExerciseCopiesController#create`) ; `POST /sessions/:public_id/attempts` est retirée.
4. **Mélange** : la copie affiche chaque question avec le mélange de la session (ADR-0091) ; les champs portent l'identifiant de la question dans leur nom (`copy[answers][<question_id>][answer_ids][]`), jamais une indication de bonne réponse.
5. **Brouillon** : clé `lnclass:copy:<session_public_id>` dans `localStorage`, écrite à chaque saisie, relue au chargement, effacée au rendu réussi et quand le serveur répond que l'exercice est retiré. Elle ne contient que ce que l'élève a saisi.
6. **Restent valables** : `StartExerciseSession` (le type `remediation`, l'assignation de la classe principale), `CloseExerciseSession` (note, badge, lacune si l'exercice a une notion), `SessionResultQuery`. L'exercice du jour et la remédiation ouvrent une copie comme les autres.

## 5. Conséquences

### 🟢 Positives

- Trois requêtes au lieu de 2 + n pour un exercice de n questions.
- L'élève relit le sujet et change ses réponses jusqu'au rendu.
- Une seule voie de soumission, idempotente.

### 🔴 Coûts consentis

- Le brouillon ne suit pas l'élève sur un autre appareil, et la navigation privée peut le perdre.
- Aucune correction question par question pendant l'exercice : l'élève ne sait qu'au rendu s'il s'est trompé (voulu pour une interro, moins formateur pour la fixation).
- Le contrôleur Stimulus d'une question (`assessment--answer`), l'écran « une question à la fois » et leurs tests partent.
- Une copie est un POST plus lourd ; `CopyInput` refuse plus de réponses que l'exercice n'a de questions, et chaque texte reste borné à 200 caractères.

## 6. Notes d'implémentation

```ruby
# app/domain/ports/assessment/exercise_session_repository_port.rb
# Enregistre les tentatives d'une copie, une par question. attempts : [{ question_id:, selected_answer_ids:,
# response_text:, correct:, unanswered: }]. → :ok | :duplicate (une tentative existait déjà pour cette session)
def record_copy(session_id:, attempts:, at:)
  raise NotImplementedError
end
```

```ruby
# app/domain/use_cases/assessment/submit_exercise_copy.rb (extrait)
@transaction.call do
  session = @sessions.find_by_public_id(public_id: dto.session_public_id, lock: true)
  next Shared::Result.failure(:not_found) if session.nil?
  next Shared::Result.success(Submitted.new(session_public_id: session.public_id, already_closed: true)) if session.status == "completed"

  allowed = @policy.call(actor:, session:)
  next allowed if allowed.failure?

  exercise = @exercises.find(id: session.exercise_id)
  attempts = grade(session, exercise, dto)
  next attempts if attempts.failure?

  @sessions.record_copy(session_id: session.id, attempts: attempts.value, at: @clock.now)
  @close.call(actor:, session:, essential_id: exercise.essential_id)
end
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/use_cases/assessment/submit_exercise_copy_test.rb` : note juste, vide = faux, idempotence (second appel sans écriture), `:invalid` sans écriture, `:forbidden` pour autrui.
- `test/controllers/assessment/exercise_copies_controller_test.rb` : 303 vers le résultat, 422 avec réaffichage, 403.
- `test/system/assessment/exercise_copy_test.rb` : remplir, recharger, retrouver ses réponses, rendre.
- Le HTML de la copie ne contient aucune marque de bonne réponse : assertion dans le test du contrôleur des sessions.
- `bin/rails routes | grep exercise_session_attempts` ne rend rien.
