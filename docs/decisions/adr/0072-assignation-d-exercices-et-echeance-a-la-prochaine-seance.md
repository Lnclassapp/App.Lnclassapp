# ADR-0072 : Seul un exercice s'assigne ; son échéance est la prochaine séance de l'enseignant dans la classe, calculée et figée à l'assignation

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-02 : « lance les lots ») |
| **Date** | 2026-10-02 |
| **Chantier** | [`docs/chantiers/fonctions-espace-eleve`](../../chantiers/fonctions-espace-eleve/memo.md) — grill Q5 à Q8, Q10 à Q12 ; [PRD](../../chantiers/fonctions-espace-eleve/prd.md) |
| **Amende** | [ADR-0048](./0048-statuts-d-assignation-active-et-archived.md) §4 « Types » (trois types assignables → un seul) et table `classroom_assignments` (colonne `due_on`) · [ADR-0071](./0071-gestes-de-la-direction-sur-son-etablissement.md) §4.5 (`withdraw_all_in_school` retire aussi les jours de séance) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

La maquette V2 de l'accueil élève, validée le 2026-10-02, affiche « À rendre demain », trie « À faire ensuite » par échéance et pose un point ambre sur une matière en retard. Aucune de ces données n'existe : une assignation (`classroom_assignments`, ADR-0048) n'a ni date limite ni notion de retard.

Le grill du chantier a tranché la règle métier :

- **L'enseignant n'assigne qu'un exercice**, « pour la séance prochaine » (Q6). Cours et fiches essentielles ne s'assignent plus. Aujourd'hui, `Entities::Classroom::Assignable::TYPES` vaut `%w[Course Essential Exercise]`, la base l'impose par la contrainte `classroom_assignments_type_values`, et cinq écrans portent une bascule ou un bouton d'assignation de cours ou de fiche (UDR-0013, 0028, 0029, 0030).
- **Le porteur affirme qu'aucune assignation de cours ni de fiche n'existe en base** (Q7). Rien n'est converti. La migration doit quand même vérifier, et s'arrêter plutôt que de perdre des lignes.
- **L'échéance se déduit des jours de séance** de l'enseignant dans la classe (Q8) : les jours de la semaine, sans heure, cochés aux premières assignations et modifiables ensuite. L'échéance est le prochain de ces jours **strictement après** l'assignation. Vacances et jours fériés sont ignorés (Q10). Sans jours renseignés, pas d'échéance : l'enseignant peut répondre « Plus tard » (Q11).
- **Après l'échéance, rien ne se ferme** (Q5). L'exercice reste faisable ; il est « en retard » pour l'élève, et l'enseignant voit qu'il a été rendu après la date.
- **L'enseignant voit les retards sur l'exercice assigné**, avec la liste nominative des retardataires, réservée à l'enseignant de la classe et à l'équipe, jamais à un élève (Q12, UDR-0011).

Trois contraintes de l'existant pèsent sur la forme :

1. Une session d'exercice est rattachée à l'assignation active de la classe principale de l'élève **au démarrage** (`StartExerciseSession#assignment_id`, ADR-0048). « Rendu » se lit déjà ainsi : au moins une session `completed`, `standard`, rattachée à l'assignation (`StudentWorkQuery::HANDED_IN`, index partiel `index_exercise_sessions_handed_in`).
2. `teacher_classrooms` (enseignant × classe, index unique `(teacher_id, classroom_id)`) est la seule trace de « l'enseignant de la classe ». Ses lignes sont **supprimées** quand l'enseignant retire sa déclaration (`TeachingRepository#withdraw`) ou quand la direction le retire de l'établissement (`#withdraw_all_in_school`, ADR-0071).
3. L'application tourne en `config.time_zone = "Africa/Abidjan"` (UTC+0, sans heure d'été) ; les `datetime` sont stockés en UTC.

## 2. Moteurs de décision

1. **Une échéance ne bouge jamais après coup** : ce que l'élève a lu reste vrai (cas limite « jours modifiés après coup »).
2. **Aucune donnée perdue en silence** au retrait des cours et des fiches (Q7).
3. **Le domaine calcule, la base garantit** : la règle « prochain jour de séance » est en Ruby pur et testée en millisecondes ; la base refuse une échéance impossible.
4. **Une seule définition de « fait »** dans l'application, celle de l'ADR-0048 déjà lue par la direction.
5. **Aucune fuite nominative** : la liste des retardataires a sa policy et son test de refus (ADR-0015, ADR-0028).
6. **Pas de job, pas d'état de plus** : « rien ne se ferme » (Q5) veut dire aucune transition automatique.

## 3. Options envisagées

**Types assignables**

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Garder les trois types, masquer les boutons | Aucune migration | Le domaine accepterait encore ce que l'interface ne propose plus : une requête forgée assignerait un cours, sans échéance possible |
| B — **`Exercise` seul, dans le domaine et dans la base** | Le contrat dit ce que le produit fait ; trois branches de code disparaissent | Retenue |

**Sort des assignations de cours et de fiches existantes**

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Les convertir en assignations de leurs exercices | Rien ne disparaît pour l'élève | Le porteur dit qu'il n'y en a pas (Q7) ; une conversion non testée sur des données réelles est un risque sans objet |
| B — Les supprimer dans la migration | Simple | Perte silencieuse, contraire à l'ADR-0036 (une assignation s'archive) |
| C — **Vérifier et échouer s'il en reste** | Rien ne se perd ; si Q7 se trompe, le déploiement s'arrête avec un message clair | Retenue. Coût : un déploiement bloqué si la base contredit Q7 |

**Jours de séance**

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Une colonne sur `teacher_classrooms` (tableau ou masque de bits) | Pas de table nouvelle ; les jours suivent la déclaration | Mêle à la déclaration d'enseignement (ADR-0030, `insert … unique_by`) une donnée qui a son propre cycle ; la table n'a pas d'`updated_at` ; un masque de bits est illisible en SQL |
| B — Une table, une ligne par enseignant × classe, colonne `weekdays smallint[]` | Une ligne à lire | Doublons possibles dans le tableau ; « non renseigné » s'écrit de deux façons (pas de ligne, ou tableau vide) |
| C — **Une table, une ligne par jour** (`classroom_session_days`) | Contraintes simples (`weekday BETWEEN 1 AND 6`, unicité) ; « non renseigné » = aucune ligne, un seul état ; clé étrangère composite vers `teacher_classrooms` | Retenue. Coût : remplacer les jours = supprimer puis insérer, dans une transaction |
| D — Un emploi du temps avec heures | Échéance plus fine | Hors périmètre : seuls les jours comptent (Q8) |

**Lien avec la déclaration d'enseignement**

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Clés étrangères simples vers `users` et `classrooms` | Les jours survivent à un retrait de déclaration | Des jours orphelins d'un enseignant qui n'enseigne plus la classe ; ils bloqueraient `RemoveLevelClassroom` (`on_delete: :restrict`) sans raison visible |
| B — Clé composite vers `teacher_classrooms`, `ON DELETE CASCADE` | Le ménage est fait par la base | Ajoute une cascade hors de la liste fermée de l'ADR-0036 §4 : il faudrait l'amender |
| C — **Clé composite vers `teacher_classrooms`, `ON DELETE RESTRICT`**, et le repository de l'enseignement retire les jours avant la déclaration | Invariant garanti par la base (pas de jours sans déclaration), aucune cascade nouvelle | Retenue. Coût : `TeachingRepository#withdraw` et `#withdraw_all_in_school` touchent désormais une autre table |

**Échéance**

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Recalculée à la lecture depuis les jours courants | Aucune colonne | Une échéance changerait quand l'enseignant modifie ses jours : interdit par le cas limite du memo |
| B — **Colonne `due_on date NULL`, écrite une fois par `AssignResource`** | Figée ; triable ; lisible par toutes les queries sans connaître les jours | Retenue |
| C — Colonne `due_at datetime` | Prête pour des heures | Aucune heure n'existe (Q8) ; une heure inventée (minuit, 8 h) ferait mentir l'écran |

**« Rendu en retard »**

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Colonne stockée (`exercise_sessions.late`, ou table élève × assignation) écrite à la clôture | Lecture triviale | `CloseExerciseSession` (contexte `assessment`) devrait connaître l'échéance d'une assignation (contexte `classroom`) ; une seconde vérité à tenir cohérente, à remplir pour l'historique |
| B — **Calcul en lecture** : première session rendue comparée à l'échéance | Une seule vérité ; aucune écriture nouvelle ; la première session terminée et l'échéance sont toutes deux immuables, donc le résultat aussi | Retenue. Coût : un `MIN(completed_at)` groupé par élève dans les queries de suivi |

## 4. Décision

> **Nous réduisons les types assignables à `Exercise`, dans le domaine et dans la base, par une migration qui échoue s'il reste une assignation d'un autre type. Nous enregistrons les jours de séance de chaque enseignant dans chaque classe qu'il déclare, une ligne par jour, dans le contexte `classroom`. À l'assignation, nous calculons l'échéance — le prochain jour de séance de l'auteur strictement après la date de l'assignation, à Abidjan — et nous la figeons dans `classroom_assignments.due_on`, nulle sans jours. « Rendu en retard » se calcule en lecture. Rien ne se ferme.**

### 4.1 Types assignables

- `Entities::Classroom::Assignable::TYPES = %w[Exercise]`. `Dtos::Classroom::AssignmentInput` refuse tout autre type (`:invalid`, déjà par `inclusion`).
- `Repositories::Classroom::AssignmentRepository` perd `resolve_course` et `resolve_essential` ; `RESOURCES` ne garde que `Exercise`.
- Contrainte `classroom_assignments_type_values` : `assignable_type = 'Exercise'`.
- La migration **compte d'abord** les lignes d'un autre type, archivées comprises. S'il y en a, elle lève une erreur qui donne le nombre et renvoie à cet ADR : le déploiement s'arrête (ADR-0052), l'ancienne version continue de tourner, rien n'est modifié. La contrainte reste la vraie garde : posée sous verrou, elle refuse aussi une ligne arrivée entre le comptage et sa pose.
- Les colonnes `assignable_type` et `assignable_id` restent : la table reste polymorphe dans sa forme, pour que l'historique et les index ne bougent pas. Rouvrir un type demandera un ADR.

### 4.2 Jours de séance

**Table `classroom_session_days`** (contexte `classroom`, propriétaire : l'enseignant qui a déclaré la classe)

| Colonne | Contrainte |
|---|---|
| `teacher_id` | `bigint NOT NULL` |
| `classroom_id` | `bigint NOT NULL` |
| `weekday` | `smallint NOT NULL`, `CHECK (weekday BETWEEN 1 AND 6)` : 1 = lundi … 6 = samedi, comme `Date#cwday` ; le dimanche n'est pas proposé |
| `created_at` | `datetime NOT NULL` |

- Index unique `(teacher_id, classroom_id, weekday)` ; index `(classroom_id)`.
- Clé étrangère composite `(teacher_id, classroom_id)` → `teacher_classrooms (teacher_id, classroom_id)`, `ON DELETE RESTRICT`. Un jour de séance n'existe que pour une classe déclarée.
- **« Non renseigné » = aucune ligne.** Il n'y a pas d'autre état. Décocher tous les jours sur la page de la classe revient à « non renseigné » : la question revient à la prochaine assignation (Q11).
- `TeachingRepository#withdraw` et `#withdraw_all_in_school` suppriment les jours de séance concernés **avant** les déclarations, dans la même transaction. Un enseignant qui redéclare la classe la retrouve sans jours.
- **Qui écrit** : l'enseignant de la classe, pour lui-même, sur une classe active (`Policies::Classroom::SetSessionDaysPolicy`). L'équipe n'a pas de jours (elle n'est pas dans `teacher_classrooms`) et n'écrit pas ceux d'un enseignant ; une autre personne reçoit `:forbidden`.
- **Plusieurs enseignants dans une classe** : chacun a ses lignes. L'échéance d'un exercice suit les jours de **l'auteur** de l'assignation (`assigned_by_id`). L'index unique actif de l'ADR-0048 reste : un même exercice n'est assigné qu'une fois à la fois dans une classe, par un seul enseignant.

**Domaine**

- `Entities::Classroom::SessionDays` (valeur) : `weekdays`, triés et dédoublonnés, chacun dans `1..6` ; `#next_after(date)` → le premier jour de `date + 1` à `date + 7` dont le `cwday` est un jour de séance, ou `nil` sans jours.
- `Ports::Classroom::SessionDaysRepositoryPort` : `#for(teacher_id:, classroom_id:)` → `SessionDays` (vide si non renseigné) ; `#replace(teacher_id:, classroom_id:, weekdays:, at:)` → `true`.
- `UseCases::Classroom::SetSessionDays` (page de la classe) : policy, puis `replace`. Il **ne touche à aucune assignation**.

### 4.3 Échéance

- Colonne `classroom_assignments.due_on date NULL`.
- Contrainte `classroom_assignments_due_on_within_a_week` : `due_on IS NULL OR due_on − date locale de assigned_at BETWEEN 1 AND 7`. Elle traduit « strictement après » et « au plus une semaine plus tard » (un seul jour de séance par semaine donne + 7).
- `UseCases::Classroom::AssignResource` :
  1. si le DTO porte des jours (l'étape « Quels jours voyez-vous cette classe ? » a été remplie), il appelle `SetSessionDaysPolicy` puis `SessionDaysRepositoryPort#replace`, dans la même transaction que l'assignation ;
  2. il lit les jours de l'acteur pour la classe ; l'équipe n'en a jamais ;
  3. `due_on = session_days.next_after(clock.now.to_date)` : la date locale d'Abidjan (`Time.zone`), jamais la date UTC du serveur ;
  4. il crée l'assignation avec `due_on`, `nil` sans jours. « Plus tard » est une assignation sans jours dans le DTO : rien n'est bloqué (Q11).
- **Jamais recalculée.** Aucun use case n'écrit `due_on` après la création. Modifier ses jours ne change que les assignations suivantes. Une réassignation (nouvelle ligne, ADR-0048) calcule une nouvelle échéance à sa date.
- Vacances, jours fériés, heure de la séance : ignorés (Q8, Q10).

### 4.4 Retard, lu et jamais écrit

Toutes les dates se comparent en **date locale d'Abidjan**.

- **Fait** (vu de l'enseignant) : l'élève, présent dans la classe (`left_at` nul, compte non anonymisé), a au moins une session `completed`, `standard`, rattachée à l'assignation. C'est la définition de l'ADR-0048, déjà lue par `StudentWorkQuery`. Les sessions de remédiation ne comptent pas.
- **Rendu en retard** : `due_on` non nul, et la date locale de la **première** de ces sessions (`MIN(completed_at)`) est **postérieure à `due_on`**. Une session terminée le jour de l'échéance est à l'heure : faute d'heure de séance, la journée entière compte. Une session refaite ensuite n'efface ni ne crée un retard.
- **Pas encore fait** : élève présent sans session rendue.
- **En retard pour l'élève** : exercice non terminé par lui et date du jour postérieure à `due_on`. Sans échéance, jamais en retard.
- **Échéance proche** (ambre, charte §5) : faute d'heure, « moins de 24 h » se lit en jours : échéance aujourd'hui ou demain. Le détail d'affichage est dans l'[UDR-0062](../udr/0062-echeances.md).
- **Rien ne se ferme** : aucun job, aucun statut nouveau, aucun refus dans `StartExerciseSession` ni `CloseExerciseSession`.
- **Désassigné ou archivé** : l'assignation archivée sort du suivi et de « À faire », retard compris (les queries ne lisent que `status = 'active'`).

### 4.5 Liste nominative des retardataires

- `Policies::Classroom::FollowAssignmentPolicy#call(actor:, classroom:)` : succès pour l'équipe et pour un enseignant de la classe (`classroom.teacher_ids`), classe active ou archivée ; `:forbidden` pour un élève, un autre enseignant, la direction (Q12 ne la nomme pas) et un visiteur.
- La liste et les comptes sont lus par une query dédiée (`Queries::Classroom::AssignmentFollowUpQuery`), appelée seulement après la policy. La page de la classe affiche les seuls comptes, sous la même policy.
- Un élève ne voit jamais le retard d'un autre élève ; il ne voit que le sien (UDR-0011).

### 4.6 Lectures touchées (CQRS, ADR-0026)

| Query | Changement |
|---|---|
| `StudentHomeQuery` | `ExerciseRow` gagne `due_on` ; les exercices ne se lisent plus par leur fiche ou leur cours ; tri par échéance (UDR-0062 §3.2) |
| `ClassroomOverviewQuery` | « Cours assignés » ne se lit plus ; lit les exercices assignés actifs avec `due_on` et les trois comptes (UDR-0062 §3.4) |
| `AssignmentFollowUpQuery` (nouvelle) | Une assignation : comptes, liste des rendus en retard avec leur date de première session |
| `ClassroomCourseQuery`, `ClassroomEssentialQuery` | Ne lisent plus les assignations `Course` ni `Essential` |
| `EssentialDetailQuery` | « Assigné par ton enseignant » ne lit plus que les assignations `Exercise` |
| `CourseAssignmentTargetsQuery` | Supprimée avec l'écran « Assigner un cours » (UDR-0030) |
| `StudentWorkQuery`, `TeamDashboardQuery`, `TeacherHomeQuery` | Inchangées : elles comptent des assignations, qui ne sont plus que des exercices |

## 5. Conséquences

### 🟢 Positives

- Le contrat dit ce que le produit fait : un exercice, pour la séance prochaine. Trois branches de résolution, une query et un écran disparaissent.
- L'échéance est une donnée simple (`date`), figée, triable, que toute query lit sans connaître l'emploi du temps.
- La base refuse une échéance impossible et un jour de séance sans déclaration.
- « Rendu en retard » n'a qu'une source, les sessions, et ne peut pas diverger d'une colonne.
- Aucune assignation n'est jamais bloquée : sans jours, elle part sans échéance.

### 🔴 Coûts consentis

- **Un déploiement bloqué** si la base contredit Q7. C'est voulu ; il faudra alors un ADR qui décide du sort de ces lignes.
- **Les écrans enseignant perdent leur chemin vers les exercices.** Aujourd'hui, l'enseignant atteint un exercice par les cours **assignés** de sa classe (UDR-0027 → 0028 → 0029). Sans cours assignés, ce chemin est vide. Il est rouvert par un bloc « Cours » sur la page de la classe (UDR-0062 §3.4 ; memo, Q18, révisable par le porteur).
- **Un élève qui a fait l'exercice avant qu'il soit assigné** (depuis le catalogue) reste « pas encore fait » pour l'enseignant : sa session n'est rattachée à aucune assignation (ADR-0048, inchangé). Pour lui-même, l'exercice est terminé.
- **Retirer sa déclaration d'une classe efface ses jours de séance** : redéclarer la classe repose la question. `TeachingRepository` ne « touche plus à rien d'autre ».
- **Pas d'échéance quand l'équipe assigne** : elle n'a pas de jours.
- **Vacances ignorées** : un exercice assigné avant les congés paraît en retard pendant les congés (Q10). Sans effet, puisque rien ne se ferme.
- **Un calcul en lecture** : `MIN(completed_at)` par élève sur l'index partiel `index_exercise_sessions_handed_in`, qui n'inclut pas `completed_at`. Si le budget de l'ADR-0067 (< 100 ms) n'est pas tenu au volume de la feuille de route, ajouter `completed_at` à l'`INCLUDE` de cet index, sans autre ADR.
- **Le glossaire** est corrigé à l'acceptation (2026-10-02) : `ClassroomAssignment` n'a plus qu'un type, et « jours de séance », « échéance » et « rendu en retard » y entrent.

## 6. Notes d'implémentation

Code cible, sur le code réel de ces fichiers au 2026-10-02.

```ruby
# app/domain/entities/classroom/assignable.rb
Assignable::TYPES = %w[Exercise].freeze
```

```ruby
# app/domain/entities/classroom/session_days.rb
# 🧠 DOMAINE · Entities::Classroom::SessionDays
# Rôle : jours de la semaine où un enseignant voit une classe ; donne l'échéance d'une assignation
# ADR  : 0072
module Entities
  module Classroom
    SessionDays = Data.define(:weekdays) do
      def initialize(weekdays:)
        days = Array(weekdays).map { Integer(it) }.uniq.sort
        raise ArgumentError, "jour de séance hors de 1..6 : #{days.inspect}" unless days.all? { SessionDays::WEEKDAYS.cover?(it) }

        super(weekdays: days.freeze)
      end

      def none? = weekdays.empty?

      # Le prochain jour de séance strictement après `date` (jamais le jour même), ou nil sans jours.
      def next_after(date)
        (1..7).map { date + it }.find { weekdays.include?(it.cwday) } unless none?
      end
    end
    SessionDays::WEEKDAYS = (1..6) # lundi … samedi (Date#cwday)
  end
end
```

```ruby
# app/domain/use_cases/classroom/assign_resource.rb — extrait de #create
now = @clock.now
@session_days.replace(teacher_id: actor.user_id, classroom_id: classroom.id, weekdays: dto.weekdays, at: now) if dto.weekdays
due_on = @session_days.for(teacher_id: actor.user_id, classroom_id: classroom.id).next_after(now.to_date)
created = @assignments.create(assignment: Entities::Classroom::Assignment.new(
  id: nil, public_id: nil, classroom_id: classroom.id, assignable:, status: "active",
  assigned_by_id: actor.user_id, assigned_at: now, archived_at: nil, due_on:
))
```

```ruby
# db/migrate/2026100xxxxxx_restrict_classroom_assignments_to_exercises.rb
# ADR-0072: only exercises can be assigned. Grill Q7 says no course or essential assignment exists; if one does,
# stop here rather than lose it. The check constraint still guards a row written between the count and its creation.
class RestrictClassroomAssignmentsToExercises < ActiveRecord::Migration[8.1]
  def up
    others = select_value("SELECT COUNT(*) FROM classroom_assignments WHERE assignable_type <> 'Exercise'").to_i
    if others.positive?
      raise ActiveRecord::MigrationError,
            "ADR-0072: #{others} course or essential assignment(s) found. Nothing was changed; decide their fate first."
    end

    remove_check_constraint :classroom_assignments, name: "classroom_assignments_type_values"
    add_check_constraint :classroom_assignments, "assignable_type = 'Exercise'", name: "classroom_assignments_type_values"
  end

  def down
    remove_check_constraint :classroom_assignments, name: "classroom_assignments_type_values"
    add_check_constraint :classroom_assignments, "assignable_type IN ('Course', 'Essential', 'Exercise')",
                         name: "classroom_assignments_type_values"
  end
end
```

```ruby
# db/migrate/2026100xxxxxx_add_due_on_to_classroom_assignments.rb
# ADR-0072 §4.3: the due date is the next session day, strictly after the local (Abidjan) assignment date.
class AddDueOnToClassroomAssignments < ActiveRecord::Migration[8.1]
  def change
    add_column :classroom_assignments, :due_on, :date
    add_check_constraint :classroom_assignments,
                         "due_on IS NULL OR due_on - (assigned_at AT TIME ZONE 'UTC' AT TIME ZONE 'Africa/Abidjan')::date BETWEEN 1 AND 7",
                         name: "classroom_assignments_due_on_within_a_week"
  end
end
```

```ruby
# db/migrate/2026100xxxxxx_create_classroom_session_days.rb
# ADR-0072 §4.2: the weekdays (1 = Monday … 6 = Saturday) a teacher sees a classroom. No row means "not answered yet".
class CreateClassroomSessionDays < ActiveRecord::Migration[8.1]
  def change
    create_table :classroom_session_days do |t|
      t.bigint :teacher_id, null: false
      t.bigint :classroom_id, null: false
      t.integer :weekday, limit: 2, null: false
      t.datetime :created_at, null: false
      t.check_constraint "weekday BETWEEN 1 AND 6", name: "classroom_session_days_weekday_range"
      t.index %i[teacher_id classroom_id weekday], unique: true, name: "index_classroom_session_days_unique"
      t.index :classroom_id
    end
    add_foreign_key :classroom_session_days, :teacher_classrooms, column: %i[teacher_id classroom_id],
                                                                   primary_key: %i[teacher_id classroom_id], on_delete: :restrict
  end
end
```

```ruby
# app/infrastructure/repositories/classroom/teaching_repository.rb — les jours partent avant la déclaration
def withdraw(teacher_id:, classroom_id:)
  Orm::TeacherClassroom.transaction do
    Orm::ClassroomSessionDay.where(teacher_id:, classroom_id:).delete_all
    Orm::TeacherClassroom.where(teacher_id:, classroom_id:).delete_all
  end
  true
end
```

Rendu en retard, dans les queries de suivi (une requête groupée, quel que soit l'effectif) :

```ruby
# { student_id => date locale de la première session rendue }
first_done = Orm::ExerciseSession.where(classroom_assignment_id: assignment_id, status: "completed", kind: "standard")
                                 .group(:student_id).minimum(:completed_at)
                                 .transform_values { it.in_time_zone.to_date }
late = first_done.select { |_, done_on| due_on && done_on > due_on }
```

## 7. Comment vérifier que la décision est respectée

| Garde | Ce qui échoue |
|---|---|
| `test/domain/entities/classroom/assignable_test.rb` | `Assignable.new(type: "Course", …)` et `"Essential"` lèvent `ArgumentError` |
| `test/domain/entities/classroom/session_days_test.rb` | Lundi et jeudi : assigné lundi → jeudi ; jeudi → lundi suivant ; dimanche → lundi ; un seul jour (mercredi), assigné mercredi → mercredi + 7 ; sans jours → `nil` ; jour 0 ou 7 → `ArgumentError` |
| `test/domain/use_cases/classroom/assign_resource_test.rb` | Échéance figée à la date locale (horloge fixée à 23 h 30 UTC un samedi : la date d'Abidjan sert) ; « Plus tard » → `due_on` nul et assignation créée ; jours dans le DTO d'un membre de l'équipe → `:forbidden`, rien d'écrit ; type `Course` → `:invalid` |
| `test/domain/use_cases/classroom/set_session_days_test.rb` | Changer ses jours ne modifie aucun `due_on` existant ; refus (`:forbidden`) pour l'équipe, un autre enseignant, un élève, une classe archivée |
| `test/domain/policies/classroom/follow_assignment_policy_test.rb` | Refus pour un élève de la classe, un enseignant d'une autre classe, la direction de l'établissement, `nil` ; succès pour l'enseignant de la classe et l'équipe |
| `test/db/classroom_assignments_constraints_test.rb` | Insertion SQL d'une ligne `Course` refusée ; `due_on` le jour même ou à + 8 refusé ; jour de séance 7 refusé ; jour de séance sans déclaration refusé |
| `test/db/restrict_classroom_assignments_to_exercises_test.rb` | Dans une transaction annulée : l'ancienne contrainte rétablie, une ligne `Course` insérée, `#up` lève `ActiveRecord::MigrationError` et la ligne est intacte |
| `test/infrastructure/repositories/classroom/teaching_repository_test.rb` | Retirer une déclaration (seule, ou par `withdraw_all_in_school`) retire les jours de séance correspondants, et eux seuls |
| `test/infrastructure/queries/classroom/assignment_follow_up_query_test.rb` | Session terminée le jour de l'échéance → à l'heure ; le lendemain → en retard ; session refaite après un retard → reste en retard ; remédiation → ne compte pas ; élève parti → ne compte pas ; assignation archivée → absente |
| `test/architecture/assignable_types_test.rb` | Échoue si `app/` contient `assignable_type: "Course"` ou `"Essential"`, ou une chaîne `"Course"`/`"Essential"` passée comme type assignable |

## 8. Remplace, complète, amende

- **Amende l'ADR-0048** : §4 « Types » (seul `Exercise`) et la table `classroom_assignments` (colonne `due_on`, contrainte de type). Le reste (statuts, nouvelle ligne à la réassignation, rattachement des sessions) est inchangé.
- **Amende l'ADR-0071** §4.5 : `withdraw_all_in_school` retire aussi les jours de séance.
- **Interfaces** : [UDR-0062](../udr/0062-echeances.md) (échéances, jours de séance, suivi) ; amendements acceptés des UDR-0011, 0013, 0015, 0027, 0028, 0029, et dépréciation de l'UDR-0030 (retrait de l'assignation de cours et de fiches).

## 9. Choix faits sans réponse du grill

Acceptés tels quels par le porteur le 2026-10-02 (« lance les lots » ; memo, Q17) :

1. **Limite de l'échéance** : une session terminée le jour de l'échéance est à l'heure ; le retard commence le lendemain.
2. **Ambre** : « moins de 24 h » lu en jours, soit échéance aujourd'hui ou demain (la maquette montre « À rendre demain » en ambre).
3. **Dimanche** non proposé comme jour de séance.
4. **Équipe** : elle assigne sans échéance et n'écrit pas les jours d'un enseignant.
5. **Décocher tous ses jours** = « non renseigné » : la question revient.
6. **Retirer sa déclaration** d'une classe efface ses jours de séance.
7. **« Fait »** = session rendue rattachée à l'assignation (définition de l'ADR-0048).
8. **Direction** : elle ne voit ni les retards ni la liste nominative.
