require "test_helper"

module UseCases
  module School
    # GD-14 to GD-18 (ADR-0071 §4.3): the direction of an active school withdraws one of its teachers. His attachment and
    # his declarations in the school go, his active assignments of the school are archived by the direction, a departure is
    # opened and audited; classes, students and sessions stay. Nothing moves in another school.
    class DetachTeacherTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 1, 9)
      Clock = Data.define(:now)
      SCHOOL_A = 31
      SCHOOL_B = 32
      Assignment = Struct.new(:id, :assigned_by_id, :school_id, :status, :archived_by_id, :archived_at)

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        attr_reader :attachments

        def initialize(schools:, attachments:)
          @schools = schools
          @attachments = attachments
        end

        def find_by_id(id:) = @schools.find { it.id == id }

        def detach_teacher(teacher_id:, school_id:)
          before = @attachments.size
          @attachments.reject! { it == [ teacher_id, school_id ] }
          before - @attachments.size
        end
      end

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def initialize(*users) = @users = users
        def find_by_public_id(public_id:) = @users.find { it.public_id == public_id }
      end

      class FakeTeachings
        include Ports::Classroom::TeachingRepositoryPort

        attr_reader :declarations

        # declarations: [teacher_id, classroom_id, school_id]
        def initialize(declarations) = @declarations = declarations

        def withdraw_all_in_school(teacher_id:, school_id:)
          before = @declarations.size
          @declarations.reject! { |teacher, _classroom, school| teacher == teacher_id && school == school_id }
          before - @declarations.size
        end
      end

      class FakeAssignments
        include Ports::Classroom::AssignmentRepositoryPort

        attr_reader :assignments

        def initialize(assignments) = @assignments = assignments

        def archive_all_by_teacher_in_school(teacher_id:, school_id:, archived_by_id:, at:)
          targets = @assignments.select { it.assigned_by_id == teacher_id && it.school_id == school_id && it.status == "active" }
          targets.each do |assignment|
            assignment.status = "archived"
            assignment.archived_by_id = archived_by_id
            assignment.archived_at = at
          end
          targets.size
        end
      end

      class FakeDepartures
        include Ports::School::TeacherDepartureRepositoryPort

        attr_reader :departures

        def initialize = @departures = []

        def record(teacher_id:, school_id:, detached_by_id:, at:)
          Entities::School::TeacherDeparture.new(id: @departures.size + 1, teacher_id:, school_id:, detached_by_id:,
                                                 detached_at: at, reinstated_by_id: nil, reinstated_at: nil)
                                            .tap { @departures << it }
        end
      end

      setup do
        @teacher = user(id: 41, public_id: "awa", first_name: "Awa", last_name: "Koné")
        @schools = FakeSchools.new(schools: [ school(SCHOOL_A), school(SCHOOL_B), school(33, status: "inactive") ],
                                   attachments: [ [ 41, SCHOOL_A ], [ 43, 33 ] ])
        @users = FakeUsers.new(@teacher, user(id: 42, public_id: "yao", role: "student"),
                               user(id: 44, public_id: "anne", anonymized_at: NOW - 86_400), user(id: 45, public_id: "paul"),
                               user(id: 43, public_id: "zadi"))
        @teachings = FakeTeachings.new([ [ 41, 101, SCHOOL_A ], [ 41, 102, SCHOOL_A ], [ 41, 201, SCHOOL_B ], [ 46, 101, SCHOOL_A ] ])
        @assignments = FakeAssignments.new(
          [ Assignment.new(1, 41, SCHOOL_A, "active"), Assignment.new(2, 41, SCHOOL_A, "active"),
            Assignment.new(3, 41, SCHOOL_A, "active"), Assignment.new(4, 41, SCHOOL_A, "archived", 46, NOW - 3600),
            Assignment.new(5, 41, SCHOOL_B, "active"), Assignment.new(6, 46, SCHOOL_A, "active") ]
        )
        @departures = FakeDepartures.new
        @audit = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @direction = Entities::Identity::Actor.new(user_id: 7, role: :school_admin, school_id: SCHOOL_A)
      end

      def school(id, status: "active") = Entities::School::School.new(id:, status:)

      def user(id:, public_id:, role: "teacher", first_name: "Yao", last_name: "Brou", anonymized_at: nil)
        Entities::Identity::User.new(id:, public_id:, role:, first_name:, last_name:, anonymized_at:)
      end

      def detach(teacher_public_id: "awa", actor: @direction, school_id: actor.school_id)
        DetachTeacher.new(schools: @schools, users: @users, teachings: @teachings, assignments: @assignments,
                          departures: @departures, audit_log: @audit, policy: Policies::School::ManageSchoolTeachersPolicy.new,
                          transaction: @transaction, clock: Clock.new(NOW))
                     .call(actor:, school_id:, teacher_public_id:)
      end

      def assert_nothing_written
        assert_equal [ [ 41, SCHOOL_A ], [ 43, 33 ] ], @schools.attachments
        assert_equal 4, @teachings.declarations.size
        assert_equal %w[active active active archived active active], @assignments.assignments.map(&:status)
        assert_empty @departures.departures
        assert_empty @audit.events
      end

      test "GD-14 : rattachement et déclarations retirés, 3 devoirs actifs archivés par la direction, départ ouvert, audité" do
        result = detach

        assert result.success?
        assert_equal @teacher, result.value.teacher
        assert_equal 3, result.value.assignments_archived
        assert_equal 2, result.value.classrooms_count
        assert_equal 1, @transaction.calls
        assert_equal [ [ 43, 33 ] ], @schools.attachments
        assert_equal [ [ 41, 201, SCHOOL_B ], [ 46, 101, SCHOOL_A ] ], @teachings.declarations
        archived = @assignments.assignments.first(3)
        assert_equal [ [ "archived", 7 ] ] * 3, archived.map { [ it.status, it.archived_by_id ] }
        assert archived.all? { it.archived_at == NOW }
        assert_equal [ "archived", 46, NOW - 3600 ], @assignments.assignments[3].to_a.last(3), "l'archivé le reste, tel quel"
        assert_equal [ Entities::School::TeacherDeparture.new(id: 1, teacher_id: 41, school_id: SCHOOL_A, detached_by_id: 7,
                                                              detached_at: NOW, reinstated_by_id: nil, reinstated_at: nil) ],
                     @departures.departures
        assert_equal [ { action: "teacher.detached", actor_id: 7, at: NOW, subject_type: "User", subject_id: 41,
                         metadata: { school_id: SCHOOL_A, classrooms_count: 2, assignments_archived: 3 } } ], @audit.events
      end

      test "GD-15 : le devoir actif d'une classe de B et le devoir d'un collègue restent actifs" do
        detach

        assert_equal %w[active active], @assignments.assignments.last(2).map(&:status)
      end

      test "GD-16 : la direction de A qui envoie l'établissement B reçoit forbidden ; rien n'est écrit" do
        @schools.attachments << [ 41, SCHOOL_B ]

        assert_equal :forbidden, detach(school_id: SCHOOL_B).code
        assert_includes @schools.attachments, [ 41, SCHOOL_B ]
        assert_equal 0, @transaction.calls
      end

      test "GD-16 : un enseignant d'un autre établissement n'existe pas pour la direction de A" do
        assert_equal :not_found, detach(teacher_public_id: "zadi").code
        assert_nothing_written
      end

      test "GD-17 : la direction d'un établissement inactif et l'équipe reçoivent forbidden ; rien n'est écrit" do
        inactive = Entities::Identity::Actor.new(user_id: 8, role: :school_admin, school_id: 33)
        team = Entities::Identity::Actor.new(user_id: 9, role: :team, team_role: :admin)

        assert_equal :forbidden, detach(teacher_public_id: "zadi", actor: inactive).code
        assert_equal :forbidden, detach(actor: team, school_id: SCHOOL_A).code
        assert_equal :forbidden, detach(actor: team, school_id: nil).code
        assert_nothing_written
      end

      test "GD-18 : un enseignant en attente, sans rattachement, n'est pas retirable" do
        assert_equal :not_found, detach(teacher_public_id: "paul").code
        assert_nothing_written
      end

      test "compte inconnu, non enseignant ou anonymisé : not_found, rien n'est écrit" do
        %w[nobody yao anne].each { assert_equal :not_found, detach(teacher_public_id: it).code, it }
        assert_nothing_written
      end

      test "déjà retiré (deux onglets) : le second retrait est not_found" do
        assert detach.success?
        assert_equal :not_found, detach.code
        assert_equal 1, @departures.departures.size
        assert_equal 1, @audit.events.size
      end
    end
  end
end
