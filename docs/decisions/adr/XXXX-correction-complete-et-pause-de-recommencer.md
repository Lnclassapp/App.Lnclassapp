# ADR-XXXX : L'élève voit la correction complète de sa copie rendue, et « Recommencer » se met en pause après 3 copies d'affilée
<!-- index
titre: Correction complète après la copie, pause de Recommencer
statut: Accepté
problematique: Montrer les bonnes réponses à l'élève après sa copie sans que la meilleure note perde tout sens
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-28 |
| **Chantier** | `docs/chantiers/correction-comme-en-classe` |
| **Remplace** | La décision du porteur du 2026-09-25 portée par `RevealAnswersPolicy` (« l'élève ne voit jamais les bonnes réponses, pas même après sa tentative »), pour le seul résultat d'une copie rendue |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Depuis le 2026-09-25, l'élève ne voit jamais les bonnes réponses : ni pendant sa copie, ni dans son résultat. La raison :
avec « Recommencer » et la meilleure note qui compte, un élève qui verrait la correction referait l'exercice en la recopiant,
et sa note ne mesurerait plus rien.

Le Lot C de la refonte de la page de la leçon (#334) a fait de l'exercice une copie rendue d'un seul envoi. Le porteur veut
désormais une correction « comme en classe » : la réponse de l'élève, la bonne réponse et l'explication (issue #350, D1).
Il avait d'abord voulu que seule la première copie compte (D2). Au cadrage, Touré a préféré garder la meilleure note, et le
porteur l'a validé le 2026-10-28, avec un frein : « Recommencer » se met en pause après 3 copies rendues d'affilée.

Deux contrats changent :
- **qui voit les bonnes réponses dans un résultat** : la règle dépend maintenant de la copie, pas seulement de l'exercice ;
- **le démarrage d'une copie** : il doit lire les dernières fins de copies de l'élève, ce que le port ne sait pas faire.

## 2. Moteurs de décision

1. Ne jamais montrer une bonne réponse avant la copie rendue, ni sur une copie abandonnée.
2. Ne changer aucun calcul de note, de maîtrise, de badge ni de lacune (hors périmètre du chantier).
3. Une pause qu'aucun chemin ne contourne : résultat, page de l'exercice, accueil, historique, autre onglet.
4. Une règle de pause en Ruby pur, testable sans base ni horloge réelle.
5. Pas de table ni de colonne nouvelle.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Seule la première copie compte (D2 d'origine) | La note ne peut pas être obtenue correction vue | Écartée par le porteur au cadrage : l'élève et l'enseignant gardent la meilleure note, plus motivante, et une règle de note qui ne change nulle part |
| B — Meilleure note, bonnes réponses d'un devoir montrées seulement après sa date limite | Une note de devoir ne peut pas être obtenue correction vue | Écartée au cadrage : la correction arrive trop tard pour l'élève qui vient de rendre sa copie |
| C — Meilleure note, correction tout de suite, pause de « Recommencer » | Correction immédiate, aucune règle de note ne change ; la pause freine la copie mécanique | **Retenue.** Le risque reste : un 20/20 peut être obtenu à la 2e copie, correction vue |
| C1 — Pause dans `StartSessionPolicy` | Un seul point de contrôle, déjà appelé par les vues | Une policy ne lit pas de dépôt ; il faudrait passer les fins de copies à chaque appel, depuis trois contrôleurs |
| C2 — Pause dans le use case `StartExerciseSession`, règle dans une entité | Le use case a déjà le dépôt ; tous les démarrages y passent | **Retenue** |
| D — Étendre `RevealAnswersPolicy` à l'élève | Un seul nom | Sa règle sert aussi la page de l'exercice, où l'élève ne doit jamais voir les réponses ; elle prend un exercice, pas une copie |

## 4. Décision

> **Nous montrons la correction complète à l'élève auteur d'une copie rendue, par une nouvelle `RevealCorrectionPolicy`
> qui juge la copie, et nous mettons « Recommencer » en pause 30 minutes après 3 copies rendues d'affilée sur un exercice.
> Cette règle vit dans l'entité `RestartPause` et `StartExerciseSession` l'applique à chaque démarrage. Aucun calcul de
> note, de maîtrise, de badge ni de lacune ne change.**

- **Révélation.** `Policies::Assessment::RevealCorrectionPolicy#call(actor:, exercise:, session:)` :
  - l'équipe et l'enseignant : la règle de `RevealAnswersPolicy`, inchangée ;
  - l'élève : seulement l'auteur d'une copie au statut `completed`.

  `SessionResultsController` l'utilise à la place de `RevealAnswersPolicy`, qui reste celle de la page de l'exercice.
- **Pause.** `Entities::Assessment::RestartPause.until(completions:, now:)` reçoit les fins des 3 dernières copies rendues,
  de la plus récente à la plus ancienne. Elle rend la fin de la pause, ou `nil`.

  La pause vaut quand les trois conditions sont réunies :
  - il y a 3 fins de copies ;
  - moins de 30 minutes séparent deux fins consécutives ;
  - `now` est à moins de 30 minutes de la plus récente.
- **Port.** `ExerciseSessionRepositoryPort#recent_completions(student_id:, exercise_id:, limit:)` rend les `completed_at`
  des copies `completed`, de la plus récente à la plus ancienne. Toutes les sortes comptent (`standard`, `remediation`,
  avec ou sans devoir). Les copies abandonnées n'en font pas partie.
- **Refus.** `StartExerciseSession` rend `Shared::Result.failure(:conflict, errors: { base: [ :paused ] })` avant
  d'abandonner ou d'ouvrir quoi que ce soit. Une copie en cours se reprend toujours : la pause ne bloque que l'ouverture
  d'une nouvelle copie.

## 5. Conséquences

### 🟢 Positives

- L'élève comprend ses fautes juste après sa copie, ce que l'explication seule ne permettait pas toujours.
- Aucune requête de score ne change : les tableaux de l'enseignant, l'accueil et les badges restent tels quels.
- La pause tient sur tous les chemins, puisqu'ils passent tous par le même use case.

### 🔴 Coûts consentis

- **Une note peut être obtenue la correction sous les yeux** : 20/20 à la 2e copie, en recopiant. La pause freine, sans
  empêcher. L'enseignant n'en sait rien. Risque accepté par le porteur le 2026-10-28.
- Deux policies de révélation coexistent : `RevealAnswersPolicy` pour la page de l'exercice, `RevealCorrectionPolicy`
  pour le résultat. Un lecteur pressé peut confondre les deux.
- Une requête de plus au démarrage d'une copie, et une sur la page du résultat et sur celle de l'exercice, sur l'index
  existant `(student_id, completed_at)`.
- Une pause se calcule à partir d'heures en base : un décalage d'horloge entre serveurs peut l'allonger ou l'écourter de
  quelques secondes.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/assessment/restart_pause.rb
module Entities
  module Assessment
    module RestartPause
      SERIES = 3
      SECONDS = 30 * 60

      # completions : [Time] des copies rendues, la plus récente d'abord. → Time | nil
      def self.until(completions:, now:)
        recent = completions.first(SERIES)
        return if recent.size < SERIES
        return unless recent.each_cons(2).all? { |later, earlier| later - earlier < SECONDS }

        ends_at = recent.first + SECONDS
        ends_at if now < ends_at
      end
    end
  end
end
```

```ruby
# app/domain/use_cases/assessment/start_exercise_session.rb (extrait)
# call enveloppe désormais le résultat d'open_session : @transaction.call { open_session(actor, exercise, restart) }
def open_session(actor, exercise, restart)
  current = @sessions.started_for(student_id: actor.user_id, exercise_id: exercise.id)
  return Shared::Result.success(current) if current && !restart
  return Shared::Result.failure(:conflict, errors: { base: [ :paused ] }) if paused?(actor, exercise)

  @sessions.abandon(id: current.id, at: @clock.now) if current
  Shared::Result.success(@sessions.start(session: new_session(actor, exercise)))
end

def paused?(actor, exercise)
  completions = @sessions.recent_completions(student_id: actor.user_id, exercise_id: exercise.id,
                                             limit: Entities::Assessment::RestartPause::SERIES)
  !Entities::Assessment::RestartPause.until(completions:, now: @clock.now).nil?
end
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/assessment/restart_pause_test.rb` : les CA-13 à CA-16, aux bornes (29 min 59 s, 30 min).
- `test/domain/policies/assessment/reveal_correction_policy_test.rb` : le CA-06, chaque acteur et chaque statut de copie.
- `test/domain/use_cases/assessment/start_exercise_session_test.rb` : refus `:paused` sans abandon ni création ; reprise
  d'une copie en cours toujours permise.
- `test/controllers/assessment/exercise_sessions_controller_test.rb` : le CA-13 par la requête, 303 vers l'exercice.
- `test/controllers/assessment/exercises_controller_test.rb` : aucune bonne réponse sur la page de l'exercice pour l'élève
  (non-régression de `RevealAnswersPolicy`).
