# ADR-0089 : L'exercice du jour se calcule à la lecture, et « fait seul » se déduit d'une session sans assignation
<!-- index
titre: Exercice du jour calculé à la lecture, « fait seul » déduit
statut: Accepté
problematique: Proposer chaque jour un exercice à l'élève sans enseignant, et compter à part son travail autonome chez l'enseignant et la direction, sans nouvelle table ni colonne
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-15 |
| **Chantier** | [`docs/chantiers/accueil-eleve`](../../chantiers/accueil-eleve/memo.md) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Au lancement, beaucoup de classes n'ont aucun enseignant sur Lnclass : « À faire » reste vide et l'élève n'a pas de raison de revenir. Le porteur a décidé (memo du chantier, 2026-10-15) :

- chaque jour, Lnclass propose **un** exercice : la matière suivante dans le tour des matières de l'élève, et dans cette matière le premier exercice publié qu'il n'a pas fait ;
- la proposition ne change pas dans la journée (heure d'Abidjan) ; une fois faite, la carte dit « Bravo, à demain ! » avec la matière de demain ;
- le travail de l'enseignant passe toujours avant : la proposition ne s'affiche que s'il n'y en a aucun ;
- ce travail fait seul est vu par l'élève, son enseignant et la direction, **séparé** des comptes du travail donné ;
- l'élève peut inviter son enseignant par WhatsApp.

Ce qui existe déjà :

- `exercise_sessions` a `classroom_assignment_id` nullable. Il n'y a pas de colonne d'origine.
- Toute session démarre par `UseCases::Assessment::StartExerciseSession`, sans exigence d'assignation.
- Ce use case rattache la session à l'assignation active de cet exercice dans la classe principale de l'élève (ADR-0048), quelle que soit la page d'où il part.
- Les comptes de l'enseignant (`AssignmentFollowUpQuery`, `TeacherFollowUpsQuery`, `AssignmentScores`) et de la direction (`StudentWorkQuery::HANDED_IN`) ne lisent que les sessions rattachées à une assignation.
- Il n'y a ni port d'horloge ni port de date : les queries reçoivent `today:` et `config.time_zone` vaut `Africa/Abidjan`.

## 2. Moteurs de décision

- Pas de migration ni de nouvelle table pour une proposition qui se recalcule.
- La même proposition toute la journée, sur tous les appareils de l'élève, sans état à synchroniser.
- Les comptes du travail donné ne doivent pas bouger.
- Une règle de tour testable sans base de données.
- La requête de l'accueil ne doit pas coûter plus cher qu'aujourd'hui sur un téléphone d'entrée de gamme.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Table `daily_proposals` (élève, jour, exercice) écrite à la première ouverture | Proposition figée, historique exact | Une écriture sur une page de lecture, une table de plus, des courses à la première ouverture simultanée sur deux appareils |
| B — Colonne `origin` (`assigned` / `daily` / `self`) sur `exercise_sessions` | « Fait seul » explicite, distingue la proposition du catalogue | Migration sur la table la plus écrite ; le rattachement automatique (ADR-0048) rendrait `origin` et `classroom_assignment_id` contradictoires ; personne n'a demandé à distinguer « du jour » et « catalogue » |
| C — Calcul à la lecture, « fait seul » = session terminée sans assignation | Aucune écriture nouvelle, déterministe, réutilise les colonnes existantes | Retenue |

## 4. Décision

> **Nous calculons l'exercice du jour à chaque lecture, à partir de la date d'Abidjan et des sessions déjà terminées, et nous comptons comme « fait seul » toute session terminée sans `classroom_assignment_id`. Aucune table, colonne ni port nouveau.**

### 4.1 Règle de l'exercice du jour

Pour un élève et un jour `D` (date d'Abidjan) :

1. **Matières** : l'union des matières de ses classes actives de l'année, ordonnée par `SUBJECT_ORDER` (puis par nom).
   *Note du 2026-10-15 : l'ordre se lit désormais dans `materials.position` (`NULLS LAST`, puis le nom), qui remplace `SUBJECT_ORDER` ([ADR-0090](0090-lecture-des-fiches-par-l-eleve-et-rang-des-matieres.md) §4.2) ; l'ordre est le même.*
2. **Candidats d'une matière** : ses exercices publiés (exercice, fiche et cours publiés, ADR-0035) pour les niveaux et séries de l'élève (`StudentAudienceQuery`), dans l'ordre du catalogue (niveau, puis nom du cours, comme `CourseCatalogQuery`), puis `essentials.position`, puis `exercises.position`, en excluant :
   - les exercices dont l'élève a une session terminée **commencée avant le début de `D`** ;
   - les exercices qui ont une assignation active dans une de ses classes : ceux-là sont du travail de l'enseignant (priorité stricte), et le rattachement automatique les sortirait de toute façon de « fait seul ».
3. **Matière du jour** : `index = (D - 2026-01-01).to_i % n`. On part de `matières[index]` et on avance jusqu'à la première qui a un candidat. Aucune → état `:none`.
4. **Exercice du jour** : le premier candidat de la matière du jour.
5. **État** :
   - `:done_today` : l'élève a une session terminée de cet exercice, sans assignation, commencée pendant `D` ;
   - `:proposed` sinon.
6. **Matière de demain** : la même règle pour `D + 1`, en excluant aussi l'exercice du jour s'il est fait.

L'exercice commencé à 23 h 50 et terminé après minuit est daté par `started_at` : il compte pour `D`, et `D + 1` a sa propre matière.

**Affichage** : la carte n'est montrée que si `StudentHomeQuery#assigned_exercises` est vide. Le calcul est sauté sinon, pour ne rien coûter aux élèves qui ont un enseignant.

### 4.2 « Fait seul »

- **Définition** : une session `status = 'completed'`, `classroom_assignment_id IS NULL`, de `kind = 'standard'`. Les remédiations restent hors du compte, comme dans les comptes actuels.
- **Jour** : celui de `started_at` à Abidjan. **Fenêtre** : les 7 derniers jours, `D` compris.
- **Enseignant** : `ClassroomOverviewQuery::StudentRow` gagne `self_practice_count`, lu seulement avec `show_roster` (`ReadClassroomPolicy`).
- **Direction** : la ligne par niveau de `DirectionHomeQuery` gagne `self_practice_count`, dans le même cache de 5 minutes et le même périmètre d'établissement.
- `AssignmentFollowUpQuery`, `TeacherFollowUpsQuery`, `AssignmentScores` et `StudentWorkQuery` ne changent pas : ils filtrent déjà sur l'assignation.

### 4.3 Inviter mon enseignant

- Un lien `whatsapp_share_url` (helper existant) avec la clé `classroom.student_homes.invite_teacher.message`, qui nomme la classe et l'établissement et pointe vers `new_teacher_registration_url`.
- L'élève n'a pas de jeton de parrainage (`TeacherProfile.referral_token`) : l'établissement n'est donc pas prérempli et aucun partage n'est compté. Donner un jeton aux élèves serait un autre ADR.

## 5. Conséquences

### 🟢 Positives

- Zéro migration ; la PR reste dans `app/` et `config/locales/`.
- Même proposition sur le téléphone et l'ordinateur, sans synchronisation.
- La règle du tour est une fonction pure, testée sans base.
- Les chiffres du travail donné sont intacts par construction.

### 🔴 Coûts consentis

- **Proposition mouvante** : si un nouvel exercice est publié avant le candidat dans cet ordre, ou qu'une assignation apparaît dans la journée, la proposition du jour peut changer. C'est accepté : c'est rare et sans perte pour l'élève.
- **Pas d'historique des propositions** : on ne saura pas combien de propositions ont été montrées et ignorées. La mesure du PRD §7 se contente des sessions « fait seul ».
- **« Fait seul » ne distingue pas** la proposition du jour d'un exercice ouvert depuis Mes matières.
- **Assignation après coup** : une session faite avant qu'un exercice soit donné reste « fait seul », même si l'exercice est donné ensuite. C'est conforme au sens (« fait sans qu'on le lui demande »), mais elle n'apparaîtra pas dans les « faits » de l'assignation.
- **Coût de requête** : une requête de plus sur l'accueil des élèves sans travail donné, sur les index existants (`exercise_sessions` par élève et exercice).

## 6. Notes d'implémentation

```ruby
# app/domain/entities/assessment/daily_rotation.rb
# Rôle : choisit la matière de l'exercice du jour (ADR-0089 §4.1), Ruby pur
module Entities
  module Assessment
    class DailyRotation
      EPOCH = Date.new(2026, 1, 1)

      # subjects : slugs ordonnés (SUBJECT_ORDER) ; with_candidates : slugs qui ont au moins un candidat ce jour-là
      def self.subject_for(day:, subjects:, with_candidates:)
        return nil if subjects.empty?

        start = (day - EPOCH).to_i % subjects.size
        subjects.rotate(start).find { |slug| with_candidates.include?(slug) }
      end
    end
  end
end
```

```ruby
# app/infrastructure/queries/assessment/daily_exercise_query.rb
module Queries
  module Assessment
    class DailyExerciseQuery
      Row = Data.define(:state, :exercise_public_id, :exercise_title, :material_name, :material_category,
                        :tomorrow_material_name)
      def call(student_id:, today: Time.zone.today) = ...
    end
  end
end
```

```ruby
# « fait seul » (ClassroomOverviewQuery, DirectionHomeQuery)
Orm::ExerciseSession.where(status: "completed", kind: "standard", classroom_assignment_id: nil)
                    .where(started_at: (today - 6).beginning_of_day..today.end_of_day)
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/assessment/daily_rotation_test.rb` : le tour, le saut d'une matière sans candidat, l'absence de candidat, le changement de jour.
- `test/infrastructure/queries/assessment/daily_exercise_query_test.rb` : CA-8 à CA-15 du PRD, dont minuit et l'exercice donné jamais proposé.
- `test/infrastructure/queries/classroom/assignment_follow_up_query_test.rb` : un cas ajouté prouve qu'une session sans assignation ne change pas `Counts`.
- `git diff --stat` de la PR ne contient aucun fichier sous `db/`.
