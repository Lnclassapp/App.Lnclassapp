require "test_helper"

module UseCases
  module Classroom
    # CL-16, CL-17, CL-20, AS-18 (ADR-0048) : assigner crée toujours une nouvelle ligne active, dont l'auteur est un
    # utilisateur ; l'ancienne application levait RecordNotUnique à la réassignation et écrivait un identifiant de profil.
    class AssignResourceTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
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

      # Comme le repository : l'index partiel refuse une seconde ligne active pour le même couple.
      class FakeAssignments
        include Ports::Classroom::AssignmentRepositoryPort

        attr_reader :rows

        def initialize(resources)
          @resources = resources
          @rows = []
        end

        def resolve_assignable(type:, key:) = @resources[[ type, key ]]

        def active_for(classroom_id:, assignable:)
          @rows.find { it.classroom_id == classroom_id && it.assignable.id == assignable.id && it.active? }
        end

        def create(assignment:)
          if active_for(classroom_id: assignment.classroom_id, assignable: assignment.assignable)
            return Shared::Result.failure(:conflict, errors: { base: [ :already_assigned ] })
          end

          @rows << assignment.with(id: @rows.size + 1, public_id: "asg#{@rows.size + 1}")
          Shared::Result.success(@rows.last)
        end

        def archive(id:, archived_by_id:, at:)
          index = @rows.index { it.id == id }
          @rows[index] = @rows[index].with(status: "archived", archived_at: at)
          true
        end
      end

      # Une concurrence perdue : la ligne active est apparue entre la lecture et l'écriture.
      class RacingAssignments < FakeAssignments
        def active_for(classroom_id:, assignable:) = nil
        def create(assignment:) = Shared::Result.failure(:conflict, errors: { base: [ :already_assigned ] })
      end

      setup do
        # Niveau 6 (6ème), sans série : les contenus ci-dessous sont de ce niveau, sauf « tle-d » (UDR-0013, 2026-10-01).
        @classroom = Entities::Classroom::Classroom.new(id: 3, public_id: "cls6e1", name: "6ème 1", teacher_ids: [ 7 ], level_id: 6)
        archived = Entities::Classroom::Classroom.new(id: 4, public_id: "clsold", name: "6ème 2", teacher_ids: [ 7 ], status: "archived",
                                                      level_id: 6)
        @classrooms = FakeClassrooms.new(@classroom, archived)
        @resources = {
          [ "Exercise", "ex-meiose" ] => resolved("Exercise", 30, "ex-meiose", "Méiose"),
          [ "Course", "genetique" ] => resolved("Course", 10, "genetique", "Génétique"),
          [ "Essential", "mitose" ] => resolved("Essential", 20, "mitose", "La mitose"),
          [ "Essential", "brouillon" ] => resolved("Essential", 21, "brouillon", "Brouillon", status: "draft"),
          [ "Exercise", "ex-orphelin" ] => resolved("Exercise", 31, "ex-orphelin", "Orphelin", parents_published: false),
          [ "Course", "tle-d" ] => resolved("Course", 11, "tle-d", "Génétique Tle D", course_level: { level_id: 13, series_id: 40 }),
          [ "Exercise", "ex-6e-serie" ] => resolved("Exercise", 32, "ex-6e-serie", "Série", course_level: { level_id: 6, series_id: 40 })
        }
        @assignments = FakeAssignments.new(@resources)
        @teacher = Entities::Identity::Actor.new(user_id: 7, role: :teacher, school_id: 1)
      end

      def resolved(type, id, key, name, status: "published", parents_published: true, course_level: { level_id: 6, series_id: nil })
        Resolved.new(assignable: Assignable.new(type:, id:, key:, name:), status:, parents_published:, course_level:)
      end

      def assign(key, type: "Exercise", classroom: "cls6e1", actor: @teacher, assignments: @assignments)
        dto = Dtos::Classroom::AssignmentInput.new(classroom_public_id: classroom, assignable_type: type, assignable_key: key)
        AssignResource.new(classrooms: @classrooms, assignments:, policy: Policies::Classroom::AssignPolicy.new,
                           clock: Clock.new(NOW)).call(actor:, dto:)
      end

      test "assigne un exercice publié : une ligne active, dont l'auteur est l'utilisateur connecté" do
        result = assign("ex-meiose")

        assert result.success?
        assignment = result.value.assignment

        assert_equal [ 3, "Exercise", 30, "active", 7, NOW, nil ],
                     [ assignment.classroom_id, assignment.assignable.type, assignment.assignable.id, assignment.status,
                       assignment.assigned_by_id, assignment.assigned_at, assignment.archived_at ]
        assert_equal [ "asg1", "Méiose" ], [ assignment.public_id, assignment.assignable.name ]
        assert_same @classroom, result.value.classroom
        assert_equal 1, @assignments.rows.size
      end

      test "assigne aussi un cours et une fiche essentielle, et l'équipe peut assigner" do
        team = Entities::Identity::Actor.new(user_id: 99, role: :team, team_role: "content")

        assert_equal "Course", assign("genetique", type: "Course").value.assignment.assignable.type
        assert_equal [ "Essential", 99 ], assign("mitose", type: "Essential", actor: team).value.assignment
                                                                                         .then { [ it.assignable.type, it.assigned_by_id ] }
      end

      test "déjà actif : :conflict (« Déjà assigné à cette classe ») et rien n'est écrit" do
        assign("ex-meiose")

        result = assign("ex-meiose")

        assert_equal [ :conflict, { base: [ :already_assigned ] } ], [ result.code, result.errors ]
        assert_equal 1, @assignments.rows.size
      end

      test "une concurrence perdue à l'écriture donne aussi :conflict" do
        result = assign("ex-meiose", assignments: RacingAssignments.new(@resources))

        assert_equal [ :conflict, { base: [ :already_assigned ] } ], [ result.code, result.errors ]
      end

      test "réassigner après un retrait crée une nouvelle ligne ; l'ancienne reste archivée" do
        first = assign("ex-meiose").value.assignment
        @assignments.archive(id: first.id, archived_by_id: 7, at: NOW)

        second = assign("ex-meiose")

        assert second.success?
        assert_equal [ "archived", "active" ], @assignments.rows.map(&:status)
        assert_not_equal first.public_id, second.value.assignment.public_id
      end

      test "une ressource absente, non publiée ou dont un parent ne l'est pas est introuvable" do
        [ [ "Exercise", "inconnu" ], [ "Essential", "brouillon" ], [ "Exercise", "ex-orphelin" ] ].each do |type, key|
          assert_equal :not_found, assign(key, type:).code, key
        end
        assert_empty @assignments.rows
      end

      # UDR-0013, amendement du 2026-10-01 : l'élève ne lirait pas un contenu d'un autre niveau ; il ne s'assigne pas.
      test "un contenu d'un autre niveau, ou d'une série que la classe n'a pas : :conflict (other_level), et rien n'est écrit" do
        [ [ "tle-d", "Course" ], [ "ex-6e-serie", "Exercise" ] ].each do |key, type|
          result = assign(key, type:)

          assert_equal :conflict, result.code, key
          assert_equal({ base: [ :other_level ] }, result.errors, key)
        end
        assert_empty @assignments.rows
      end

      test "une classe inconnue est introuvable" do
        assert_equal :not_found, assign("ex-meiose", classroom: "inconnue").code
      end

      test "une classe qu'on n'enseigne pas : :forbidden, avant même de lire la ressource ; rien n'est écrit" do
        stranger = Entities::Identity::Actor.new(user_id: 8, role: :teacher, school_id: 1)
        student = Entities::Identity::Actor.new(user_id: 7, role: :student)

        assert_equal :forbidden, assign("ex-meiose", actor: stranger).code
        assert_equal :forbidden, assign("inconnu", actor: stranger).code
        assert_equal :forbidden, assign("ex-meiose", actor: student).code
        assert_equal :forbidden, assign("ex-meiose", actor: nil).code
        assert_empty @assignments.rows
      end

      test "une classe archivée : :forbidden (classroom_archived)" do
        result = assign("ex-meiose", classroom: "clsold")

        assert_equal [ :forbidden, [ :classroom_archived ] ], [ result.code, result.errors[:base] ]
        assert_empty @assignments.rows
      end

      test "un type inconnu : :invalid, avec l'erreur du DTO" do
        result = assign("ex-meiose", type: "ExamSubject")

        assert_equal :invalid, result.code
        assert result.errors.key?(:assignable_type)
        assert_empty @assignments.rows
      end
    end
  end
end
