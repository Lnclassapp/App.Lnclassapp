require "test_helper"

module UseCases
  module Classroom
    # prepare-interros-cahier, Lot E (CA-12, CA-15), ADR sujets-de-devoir (ajout du 2026-10-30) : l'enseignant de la classe envoie de 1 à 10
    # exercices en un devoir ; une assignation ordinaire par exercice, toutes du même envoi, échéance au prochain jour de séance ; un exercice
    # déjà assigné est écarté et nommé. Les identifiants envoyés par le navigateur ne sont jamais crus : liste bornée, inconnus et autres
    # niveaux refusés avant toute écriture.
    class AssignExerciseBatchTest < ActiveSupport::TestCase
      ABIDJAN = ActiveSupport::TimeZone["Africa/Abidjan"]
      # Octobre 2026 : lundi 5, jeudi 8.
      MONDAY = ABIDJAN.local(2026, 10, 5, 10)
      Clock = Data.define(:now)
      Assignable = Entities::Classroom::Assignable
      Resolved = Ports::Classroom::AssignmentRepositoryPort::ResolvedAssignable

      class FakeClassrooms
        include Ports::Classroom::ClassroomRepositoryPort

        def initialize(*classrooms)
          @stored = classrooms
        end

        def find_by_public_id(public_id:) = @stored.find { it.public_id == public_id }
      end

      # Comme le repository : create_batch écrit dans l'ordre reçu, un exercice déjà actif pour la classe est écarté.
      class FakeAssignments
        include Ports::Classroom::AssignmentRepositoryPort

        attr_reader :rows, :resolved_keys, :batches

        def initialize(resources)
          @resources = resources
          @rows = []
          @resolved_keys = []
          @batches = 0
        end

        def resolve_assignable(type:, key:)
          @resolved_keys << key
          @resources[[ type, key ]]
        end

        def active_for(classroom_id:, assignable:)
          @rows.find { it.classroom_id == classroom_id && it.assignable.id == assignable.id && it.active? }
        end

        def create_batch(assignments:)
          @batches += 1
          created = []
          skipped = []
          assignments.each do |assignment|
            if active_for(classroom_id: assignment.classroom_id, assignable: assignment.assignable)
              skipped << assignment.assignable
            else
              @rows << assignment.with(id: @rows.size + 1, public_id: "asg#{@rows.size + 1}")
              created << @rows.last
            end
          end
          Shared::Result.success(BatchCreation.new(created:, skipped:))
        end
      end

      class FakeSessionDays
        include Ports::Classroom::SessionDaysRepositoryPort

        def initialize(stored = {})
          @stored = stored
        end

        def for(teacher_id:, classroom_id:) = Entities::Classroom::SessionDays.new(weekdays: @stored.fetch([ teacher_id, classroom_id ], []))
      end

      setup do
        @classroom = Entities::Classroom::Classroom.new(school_id: 1, id: 3, public_id: "cls3e1", name: "3e 1", teacher_ids: [ 7 ], level_id: 9)
        archived = Entities::Classroom::Classroom.new(school_id: 1, id: 4, public_id: "clsold", name: "3e 2", teacher_ids: [ 7 ], status: "archived",
                                                      level_id: 9)
        @classrooms = FakeClassrooms.new(@classroom, archived)
        @resources = (1..12).to_h { |n| [ [ "Exercise", "ex#{n}" ], resolved(n, "ex#{n}", "Exercice #{n}") ] }
        @resources[[ "Exercise", "ex-brouillon" ]] = resolved(40, "ex-brouillon", "Brouillon", status: "draft")
        @resources[[ "Exercise", "ex-orphelin" ]] = resolved(41, "ex-orphelin", "Orphelin", parents_published: false)
        @resources[[ "Exercise", "ex-tle-d" ]] = resolved(42, "ex-tle-d", "Tle D", course_level: { level_id: 13, series_id: 40 })
        @assignments = FakeAssignments.new(@resources)
        @teacher = Entities::Identity::Actor.new(user_id: 7, role: :teacher, school_id: 1)
        @team = Entities::Identity::Actor.new(user_id: 99, role: :team, team_role: "content")
        @session_days = FakeSessionDays.new([ 7, 3 ] => [ 1, 4 ])
      end

      def resolved(id, key, name, status: "published", parents_published: true, course_level: { level_id: 9, series_id: nil })
        Resolved.new(assignable: Assignable.new(type: "Exercise", id:, key:, name:), status:, parents_published:, course_level:)
      end

      def send_batch(ids, actor: @teacher, classroom: "cls3e1", at: MONDAY)
        AssignExerciseBatch.new(classrooms: @classrooms, assignments: @assignments, session_days: @session_days,
                                policy: Policies::Classroom::AssignPolicy.new,
                                session_days_policy: Policies::Classroom::SetSessionDaysPolicy.new, clock: Clock.new(at))
                           .call(actor:, classroom_public_id: classroom, exercise_public_ids: ids)
      end

      # CA-12
      test "4 exercices : 4 assignations actives d'un même envoi, échéance au prochain jour de séance, dans l'ordre choisi" do
        result = send_batch(%w[ex3 ex1 ex4 ex2])

        assert result.success?
        sent = result.value
        assert_equal %w[ex3 ex1 ex4 ex2], sent.created.map { it.assignable.key }
        assert_empty sent.skipped
        assert_same @classroom, sent.classroom
        assert_equal [ [ 3, "active", 7, MONDAY, Date.new(2026, 10, 8) ] ],
                     sent.created.map { [ it.classroom_id, it.status, it.assigned_by_id, it.assigned_at, it.due_on ] }.uniq
        assert_equal 1, sent.created.map(&:batch_public_id).uniq.size
        assert_match(/\A[1-9A-HJ-NP-Za-km-z]{14}\z/, sent.created.first.batch_public_id)
        assert_equal 1, @assignments.batches
      end

      test "deux envois n'ont pas le même identifiant d'envoi" do
        first = send_batch(%w[ex1 ex2]).value.created.first.batch_public_id
        second = send_batch(%w[ex3 ex4]).value.created.first.batch_public_id

        assert_not_equal first, second
      end

      test "un seul exercice est un envoi d'un exercice" do
        result = send_batch(%w[ex1])

        assert_equal 1, result.value.created.size
        assert_not_nil result.value.created.first.batch_public_id
      end

      # CA-15
      test "un exercice déjà assigné à la classe est écarté et nommé, les autres partent" do
        send_batch(%w[ex2])

        result = send_batch(%w[ex1 ex2 ex3])

        assert result.success?
        assert_equal %w[ex1 ex3], result.value.created.map { it.assignable.key }
        assert_equal [ "Exercice 2" ], result.value.skipped.map(&:name)
      end

      test "tous déjà assignés : un succès sans assignation créée, les exercices nommés" do
        send_batch(%w[ex1 ex2])

        result = send_batch(%w[ex1 ex2])

        assert result.success?
        assert_empty result.value.created
        assert_equal [ "Exercice 1", "Exercice 2" ], result.value.skipped.map(&:name)
      end

      test "l'équipe envoie sans échéance : elle n'a pas de jours" do
        result = send_batch(%w[ex1], actor: @team)

        assert_nil result.value.created.first.due_on
        assert_equal 99, result.value.created.first.assigned_by_id
      end

      # --- Refus : droits ---------------------------------------------------------------------------------------------------

      test "un autre enseignant, un élève, un visiteur : :forbidden, avant de lire un exercice ; rien n'est écrit" do
        stranger = Entities::Identity::Actor.new(user_id: 9, role: :teacher, school_id: 1)
        student = Entities::Identity::Actor.new(user_id: 7, role: :student)

        [ stranger, student, nil ].each do |actor|
          assert_equal :forbidden, send_batch(%w[ex1 ex2], actor:).code, actor.inspect
        end
        assert_empty @assignments.rows
        assert_empty @assignments.resolved_keys
      end

      test "un enseignant de la classe dans un autre de ses établissements : le refus dit de changer d'établissement" do
        elsewhere = Entities::Identity::Actor.new(user_id: 7, role: :teacher, school_id: 2)

        result = send_batch(%w[ex1], actor: elsewhere)

        assert_equal [ :forbidden, [ :other_school ] ], [ result.code, result.errors[:base] ]
        assert_empty @assignments.rows
      end

      test "une classe archivée : :forbidden (classroom_archived)" do
        result = send_batch(%w[ex1], classroom: "clsold")

        assert_equal [ :forbidden, [ :classroom_archived ] ], [ result.code, result.errors[:base] ]
        assert_empty @assignments.rows
      end

      test "une classe inconnue est introuvable" do
        assert_equal :not_found, send_batch(%w[ex1], classroom: "inconnue").code
        assert_empty @assignments.rows
      end

      # --- Refus : la liste envoyée par le navigateur ---------------------------------------------------------------------

      test "aucun exercice, ou seulement des vides : :invalid (entre 1 et 10), rien n'est écrit" do
        [ [], [ "", "  " ], nil, "ex1" ].each do |ids|
          result = send_batch(ids)

          assert_equal [ :invalid, { base: [ :invalid_count ] } ], [ result.code, result.errors ], ids.inspect
        end
        assert_empty @assignments.rows
      end

      test "10 exercices partent ; 11 : :invalid, avant toute lecture et sans rien écrire" do
        assert_equal 10, send_batch(%w[ex1 ex2 ex3 ex4 ex5 ex6 ex7 ex8 ex9 ex10]).value.created.size

        @assignments.resolved_keys.clear
        result = send_batch(%w[ex1 ex2 ex3 ex4 ex5 ex6 ex7 ex8 ex9 ex10 ex11])

        assert_equal [ :invalid, { base: [ :invalid_count ] } ], [ result.code, result.errors ]
        assert_empty @assignments.resolved_keys
        assert_equal 10, @assignments.rows.size
      end

      test "une liste énorme est refusée sans lire un seul exercice" do
        result = send_batch(Array.new(5_000) { "x#{it}" })

        assert_equal :invalid, result.code
        assert_empty @assignments.resolved_keys
      end

      test "les doublons comptent une fois : 12 identifiants dont 10 distincts partent, une seule assignation chacun" do
        ids = %w[ex1 ex2 ex3 ex4 ex5 ex6 ex7 ex8 ex9 ex10 ex1 ex2]
        result = send_batch(ids)

        assert result.success?
        assert_equal 10, result.value.created.size
        assert_equal 10, @assignments.rows.map { it.assignable.key }.uniq.size
      end

      test "les espaces sont retirés, les valeurs qui ne sont pas du texte sont ignorées" do
        result = send_batch([ " ex1 ", 12, nil, { "a" => 1 }, [ "ex2" ], "ex2" ])

        assert_equal %w[ex1 ex2], result.value.created.map { it.assignable.key }
      end

      test "un identifiant inconnu, non publié, ou dont un parent ne l'est pas : :invalid (unknown_exercise), rien n'est écrit pour les autres" do
        [ "inconnu", "ex-brouillon", "ex-orphelin", "x" * 200 ].each do |bad|
          result = send_batch([ "ex1", bad ])

          assert_equal [ :invalid, { base: [ :unknown_exercise ] } ], [ result.code, result.errors ], bad
        end
        assert_empty @assignments.rows
      end

      test "un exercice d'un autre niveau que la classe : :conflict (other_level), rien n'est écrit pour les autres" do
        result = send_batch(%w[ex1 ex-tle-d])

        assert_equal [ :conflict, { base: [ :other_level ] } ], [ result.code, result.errors ]
        assert_empty @assignments.rows
      end

      test "un enseignant sans jours de séance pour la classe : :invalid sur weekdays, rien n'est écrit" do
        @session_days = FakeSessionDays.new

        result = send_batch(%w[ex1 ex2])

        assert_equal [ :invalid, { weekdays: [ :blank ] } ], [ result.code, result.errors ]
        assert_empty @assignments.rows
      end

      test "les jours d'un autre enseignant ne comptent pas" do
        @session_days = FakeSessionDays.new([ 8, 3 ] => [ 1 ])

        assert_equal :invalid, send_batch(%w[ex1]).code
      end
    end
  end
end
