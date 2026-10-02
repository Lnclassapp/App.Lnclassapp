require "test_helper"

module UseCases
  module Classroom
    # CL-16, CL-17, CL-20, AS-18 (ADR-0048) : assigner crée toujours une nouvelle ligne active, dont l'auteur est un
    # utilisateur ; l'ancienne application levait RecordNotUnique à la réassignation et écrivait un identifiant de profil.
    # ADR-0072 §4.3 : l'échéance est le prochain jour de séance de l'auteur, strictement après la date d'Abidjan.
    class AssignResourceTest < ActiveSupport::TestCase
      ABIDJAN = ActiveSupport::TimeZone["Africa/Abidjan"]
      NOW = ABIDJAN.local(2026, 9, 25, 12)
      # Octobre 2026 : lundi 5, mardi 6, mercredi 7, jeudi 8, dimanche 11, lundi 12.
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

      # Comme le repository : une ligne par jour ; « non renseigné » = aucune ligne.
      class FakeSessionDays
        include Ports::Classroom::SessionDaysRepositoryPort

        attr_reader :writes

        def initialize(stored = {})
          @stored = stored
          @writes = []
        end

        def for(teacher_id:, classroom_id:) = Entities::Classroom::SessionDays.new(weekdays: @stored.fetch([ teacher_id, classroom_id ], []))

        def replace(teacher_id:, classroom_id:, weekdays:, at:)
          @writes << [ teacher_id, classroom_id, weekdays, at ]
          @stored[[ teacher_id, classroom_id ]] = weekdays
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
        @classroom = Entities::Classroom::Classroom.new(id: 3, public_id: "cls6e1", name: "6ème 1", teacher_ids: [ 7, 8 ], level_id: 6)
        archived = Entities::Classroom::Classroom.new(id: 4, public_id: "clsold", name: "6ème 2", teacher_ids: [ 7 ], status: "archived",
                                                      level_id: 6)
        @classrooms = FakeClassrooms.new(@classroom, archived)
        @resources = {
          [ "Exercise", "ex-meiose" ] => resolved("Exercise", 30, "ex-meiose", "Méiose"),
          [ "Exercise", "ex-mitose" ] => resolved("Exercise", 20, "ex-mitose", "La mitose"),
          [ "Exercise", "ex-brouillon" ] => resolved("Exercise", 21, "ex-brouillon", "Brouillon", status: "draft"),
          [ "Exercise", "ex-orphelin" ] => resolved("Exercise", 31, "ex-orphelin", "Orphelin", parents_published: false),
          [ "Exercise", "ex-tle-d" ] => resolved("Exercise", 11, "ex-tle-d", "Génétique Tle D", course_level: { level_id: 13, series_id: 40 }),
          [ "Exercise", "ex-6e-serie" ] => resolved("Exercise", 32, "ex-6e-serie", "Série", course_level: { level_id: 6, series_id: 40 })
        }
        @assignments = FakeAssignments.new(@resources)
        @teacher = Entities::Identity::Actor.new(user_id: 7, role: :teacher, school_id: 1)
        @colleague = Entities::Identity::Actor.new(user_id: 8, role: :teacher, school_id: 1)
        @team = Entities::Identity::Actor.new(user_id: 99, role: :team, team_role: "content")
        @session_days = FakeSessionDays.new
        @transaction = FakeTransaction.new
      end

      def resolved(type, id, key, name, status: "published", parents_published: true, course_level: { level_id: 6, series_id: nil })
        Resolved.new(assignable: Assignable.new(type:, id:, key:, name:), status:, parents_published:, course_level:)
      end

      def assign(key, type: "Exercise", classroom: "cls6e1", actor: @teacher, assignments: @assignments, at: NOW, **step)
        dto = Dtos::Classroom::AssignmentInput.new(classroom_public_id: classroom, assignable_type: type, assignable_key: key, **step)
        AssignResource.new(classrooms: @classrooms, assignments:, session_days: @session_days, transaction: @transaction,
                           policy: Policies::Classroom::AssignPolicy.new,
                           session_days_policy: Policies::Classroom::SetSessionDaysPolicy.new, clock: Clock.new(at)).call(actor:, dto:)
      end

      def due_on(result) = result.value.assignment.due_on

      test "assigne un exercice publié : une ligne active, dont l'auteur est l'utilisateur connecté" do
        result = assign("ex-meiose")

        assert result.success?
        assignment = result.value.assignment

        assert_equal [ 3, "Exercise", 30, "active", 7, NOW, nil, nil ],
                     [ assignment.classroom_id, assignment.assignable.type, assignment.assignable.id, assignment.status,
                       assignment.assigned_by_id, assignment.assigned_at, assignment.archived_at, assignment.due_on ]
        assert_equal [ "asg1", "Méiose" ], [ assignment.public_id, assignment.assignable.name ]
        assert_same @classroom, result.value.classroom
        assert_equal 1, @assignments.rows.size
      end

      test "l'équipe peut assigner un exercice, sans échéance : elle n'a pas de jours" do
        assert_equal [ "Exercise", 99, nil ], assign("ex-mitose", actor: @team, at: MONDAY).value.assignment
                                                                                          .then { [ it.assignable.type, it.assigned_by_id, it.due_on ] }
        assert_empty @session_days.writes
      end

      # ADR-0072 §4.2, §9.4 : l'équipe n'écrit pas les jours d'un enseignant ; rien n'est écrit, pas même l'assignation.
      test "des jours dans le DTO d'un membre de l'équipe : :forbidden, rien n'est écrit" do
        result = assign("ex-mitose", actor: @team, weekdays: %w[1 4])

        assert_equal :forbidden, result.code
        assert_empty @session_days.writes
        assert_empty @assignments.rows
      end

      test "lundi 5 octobre, jours cochés lundi et jeudi : jours enregistrés, échéance jeudi 8, dans une transaction" do
        result = assign("ex-meiose", at: MONDAY, weekdays: %w[1 4])

        assert_equal Date.new(2026, 10, 8), due_on(result)
        assert_equal [ [ 7, 3, [ 1, 4 ], MONDAY ] ], @session_days.writes
        assert_equal 1, @transaction.calls
      end

      test "jours connus : l'échéance se lit sans rien écrire ; jeudi → lundi suivant, dimanche → lundi" do
        @session_days = FakeSessionDays.new([ 7, 3 ] => [ 1, 4 ])

        assert_equal Date.new(2026, 10, 12), due_on(assign("ex-meiose", at: ABIDJAN.local(2026, 10, 8, 9)))
        assert_equal Date.new(2026, 10, 12), due_on(assign("ex-mitose", at: ABIDJAN.local(2026, 10, 11, 9)))
        assert_empty @session_days.writes
      end

      test "un seul jour, le mercredi, assigné un mercredi : le mercredi suivant (+ 7)" do
        @session_days = FakeSessionDays.new([ 7, 3 ] => [ 3 ])

        assert_equal Date.new(2026, 10, 14), due_on(assign("ex-meiose", at: ABIDJAN.local(2026, 10, 7, 8)))
      end

      # La date est celle d'Abidjan (Time.zone), jamais celle d'un autre fuseau : dimanche 23 h 30 reste dimanche.
      test "dimanche 11 octobre à 23 h 30 à Abidjan : échéance lundi 12, pas jeudi 15" do
        @session_days = FakeSessionDays.new([ 7, 3 ] => [ 1, 4 ])

        assert_equal Date.new(2026, 10, 12), due_on(assign("ex-meiose", at: ABIDJAN.local(2026, 10, 11, 23, 30)))
      end

      test "« Plus tard » : assigné sans échéance, aucun jour écrit ; la question reviendra" do
        result = assign("ex-meiose", at: MONDAY, later: true, weekdays: %w[1 4])

        assert result.success?
        assert_nil due_on(result)
        assert_empty @session_days.writes
      end

      test "« Assigner » sans aucun jour coché : :invalid sur weekdays, rien n'est écrit" do
        result = assign("ex-meiose", at: MONDAY, weekdays: [ "" ])

        assert_equal :invalid, result.code
        assert result.errors.key?(:weekdays)
        assert_empty @session_days.writes
        assert_empty @assignments.rows
      end

      test "deux enseignants dans la classe : l'échéance suit les jours de l'auteur" do
        @session_days = FakeSessionDays.new([ 7, 3 ] => [ 1, 4 ], [ 8, 3 ] => [ 2 ])

        assert_equal Date.new(2026, 10, 6), due_on(assign("ex-meiose", actor: @colleague, at: MONDAY))
        assert_equal Date.new(2026, 10, 8), due_on(assign("ex-mitose", at: MONDAY))
      end

      test "déjà assigné, avec des jours cochés : :conflict, et les jours ne sont pas écrits" do
        assign("ex-meiose", at: MONDAY)

        result = assign("ex-meiose", at: MONDAY, weekdays: %w[1 4])

        assert_equal :conflict, result.code
        assert_empty @session_days.writes
      end

      # ADR-0072 §4.1 : seul un exercice s'assigne ; le DTO refuse le type avant toute lecture de la ressource.
      test "un cours ou une fiche : :invalid sur le type, et rien n'est écrit" do
        [ [ "Course", "genetique" ], [ "Essential", "mitose" ] ].each do |type, key|
          result = assign(key, type:)

          assert_equal :invalid, result.code, type
          assert result.errors.key?(:assignable_type), type
        end
        assert_empty @assignments.rows
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

      # La transaction est annulée par une exception : les jours écrits avant le refus ne restent pas en base.
      test "une concurrence perdue après l'écriture des jours : :conflict, rendu après avoir annulé la transaction" do
        result = assign("ex-meiose", assignments: RacingAssignments.new(@resources), weekdays: %w[1 4])

        assert_equal [ :conflict, { base: [ :already_assigned ] } ], [ result.code, result.errors ]
        assert_equal 1, @transaction.calls
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
        %w[inconnu ex-brouillon ex-orphelin].each do |key|
          assert_equal :not_found, assign(key).code, key
        end
        assert_empty @assignments.rows
      end

      # UDR-0013, amendement du 2026-10-01 : l'élève ne lirait pas un contenu d'un autre niveau ; il ne s'assigne pas.
      test "un contenu d'un autre niveau, ou d'une série que la classe n'a pas : :conflict (other_level), et rien n'est écrit" do
        %w[ex-tle-d ex-6e-serie].each do |key|
          result = assign(key)

          assert_equal :conflict, result.code, key
          assert_equal({ base: [ :other_level ] }, result.errors, key)
        end
        assert_empty @assignments.rows
      end

      test "une classe inconnue est introuvable" do
        assert_equal :not_found, assign("ex-meiose", classroom: "inconnue").code
      end

      test "une classe qu'on n'enseigne pas : :forbidden, avant même de lire la ressource ; rien n'est écrit" do
        stranger = Entities::Identity::Actor.new(user_id: 9, role: :teacher, school_id: 1)
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
