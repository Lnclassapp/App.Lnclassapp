require "test_helper"

module UseCases
  module Classroom
    # ADR-0095 §4.1: a student whose primary classroom is active changes it themself, after a confirmation, for a classroom
    # the cascade offers (way « standard ») or the one of a valid link (way « link »). The old membership is left (left_at,
    # never removed_at), the new one opened in the same transaction, and the move is written to the audit log.
    class ChangeClassroomTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 8, 12)
      YEAR = "2026-2027".freeze
      TOKEN = "0a1b2c3d4e5f".freeze
      Clock = Data.define(:now)
      Membership = Entities::Classroom::Membership

      class JournalTransaction
        include Ports::Shared::TransactionPort

        attr_reader :calls

        def initialize(journal)
          @journal = journal
          @calls = 0
        end

        def call
          @calls += 1
          snapshot = @journal.dup
          yield
        rescue StandardError
          @journal.replace(snapshot)
          raise
        end
      end

      class FakeClassrooms
        include Ports::Classroom::ClassroomRepositoryPort

        def initialize(journal, classrooms)
          @journal = journal
          @classrooms = classrooms
        end

        def lock_by_public_id(public_id:)
          @journal << [ :lock, public_id ]
          @classrooms.find { it.public_id == public_id }
        end

        def lock_by_link_token(token:)
          @journal << [ :lock_link, token ]
          @classrooms.find { it.link_token == token }
        end
      end

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        def initialize(*schools) = @schools = schools
        def find_by_id(id:) = @schools.find { it.id == id }
      end

      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        def initialize(*levels) = @levels = levels
        def find_level(slug:) = @levels.find { it.slug == slug }
      end

      class FakeMemberships
        include Ports::Classroom::MembershipRepositoryPort

        def initialize(journal, primary:, removed_from:, refuse:, leaves: true)
          @journal = journal
          @primary = primary
          @removed_from = removed_from
          @refuse = refuse
          @leaves = leaves
        end

        def primary_for(student_id:)
          @journal << [ :primary_for, student_id ]
          @primary
        end

        def removed_from?(classroom_id:, student_id:)
          @journal << [ :removed_from?, classroom_id, student_id ]
          @removed_from.include?(classroom_id)
        end

        def leave_primary(student_id:, at:)
          @journal << [ :leave, student_id, at ]
          @leaves
        end

        def add_primary(classroom_id:, student_id:, via:, at:)
          return Shared::Result.failure(:conflict, errors: { base: [ :already_member ] }) if @refuse

          @journal << [ :add, classroom_id, student_id, via, at ]
          Shared::Result.success
        end
      end

      class FakeAuditLog
        include Ports::Identity::AuditLogPort

        def initialize(journal) = @journal = journal

        def record(action:, actor_id:, at:, subject_type: nil, subject_id: nil, metadata: {}, ip: nil)
          @journal << [ :audit, action, actor_id, at, subject_type, subject_id, metadata, ip ]
          true
        end
      end

      setup do
        @journal = []
        @transaction = JournalTransaction.new(@journal)
        @student = Entities::Identity::Actor.new(user_id: 41, role: :student)
        @school = Entities::School::School.new(id: 3, public_id: "sch-3", name: "Collège Saint-Viateur", status: "active")
        @level = Entities::Catalog::Level.new(id: 2, slug: "2nde", name: "2nde")
      end

      def classroom(**overrides)
        Entities::Classroom::Classroom.new(id: 7, public_id: "cls-7", name: "2nde C", school_id: 3, level_id: 2,
                                           school_year: YEAR, link_token: TOKEN, active_students_count: 12, **overrides)
      end

      def membership(status = "active", classroom_id: 5)
        Membership.new(classroom_id:, student_id: 41, primary: true, joined_at: NOW - 30.days, left_at: nil,
                       classroom_status: status)
      end

      def choice(**attributes)
        Dtos::Classroom::StudentRegistrationInput.new(drena_public_id: "drn-1", school_public_id: "sch-3", level_slug: "2nde",
                                                      classroom_public_id: "cls-7", **attributes)
      end

      def link(token = TOKEN) = Dtos::Classroom::StudentRegistrationInput.new(link_token: token)

      def change(actor: @student, dto: choice, classrooms: [ classroom ], schools: [ @school ], primary: membership,
                 removed_from: [], refuse: false, leaves: true, ip: nil)
        ChangeClassroom.new(classrooms: FakeClassrooms.new(@journal, classrooms), schools: FakeSchools.new(*schools),
                            taxonomy: FakeTaxonomy.new(@level),
                            memberships: FakeMemberships.new(@journal, primary:, removed_from:, refuse:, leaves:),
                            audit_log: FakeAuditLog.new(@journal), policy: Policies::Classroom::JoinPolicy.new,
                            transaction: @transaction, clock: Clock.new(NOW))
                       .call(actor:, dto:, ip:)
      end

      def written = @journal.select { %i[leave add audit].include?(it.first) }

      def moved(via: "standard", ip: nil)
        [ :audit, "classroom.student_moved", 41, NOW, "User", 41,
          { from_classroom_id: 5, to_classroom_id: 7, to_school_id: 3, via: }, ip ]
      end

      test "a student whose classroom is active leaves it and enters the chosen one, way « standard », and the move is traced" do
        result = change

        assert result.success?
        assert_equal "cls-7", result.value.public_id
        assert_equal [ [ :lock, "cls-7" ], [ :primary_for, 41 ], [ :removed_from?, 7, 41 ], [ :leave, 41, NOW ],
                       [ :add, 7, 41, "standard", NOW ], moved ], @journal
        assert_equal 1, @transaction.calls
      end

      test "by a link, the classroom of the link, way « link », even the one the student was removed from (ADR-0085 §4.3)" do
        result = change(dto: link, removed_from: [ 7 ])

        assert result.success?
        assert_equal [ [ :lock_link, TOKEN ], [ :primary_for, 41 ], [ :leave, 41, NOW ], [ :add, 7, 41, "link", NOW ],
                       moved(via: "link") ], @journal
      end

      test "the classroom the student was removed from is refused by the cascade, nothing written" do
        result = change(removed_from: [ 7 ])

        assert_equal [ :forbidden, { base: [ :removed_from_classroom ] } ], [ result.code, result.errors ]
        assert_empty written
      end

      test "a student without an active classroom goes through « Choisis ta classe »: :forbidden, nothing written" do
        [ nil, membership("archived") ].each do |primary|
          @journal.clear
          result = change(primary:)

          assert_equal [ :forbidden, { base: [ :no_active_classroom ] } ], [ result.code, result.errors ]
          assert_empty written
        end
      end

      test "the current classroom is refused, by the cascade as by its link: :invalid, nothing written" do
        [ choice, link ].each do |dto|
          @journal.clear
          result = change(dto:, primary: membership(classroom_id: 7))

          assert_equal [ :invalid, { base: [ :same_classroom ] } ], [ result.code, result.errors ]
          assert_empty written
        end
      end

      test "a full classroom is refused by JoinPolicy, by both ways, the student stays" do
        [ choice, link ].each do |dto|
          @journal.clear
          result = change(dto:, classrooms: [ classroom(active_students_count: 80) ])

          assert_equal [ :forbidden, { base: [ :classroom_full ] } ], [ result.code, result.errors ]
          assert_empty written
        end
      end

      test "the link of an archived classroom is refused with the reason, a dead link is :not_found" do
        archived = change(dto: link, classrooms: [ classroom(status: "archived") ])
        dead = change(dto: link("cccccccccccc"))

        assert_equal [ :forbidden, { base: [ :classroom_archived ] } ], [ archived.code, archived.errors ]
        assert_equal [ :not_found, {} ], [ dead.code, dead.errors ]
        assert_empty written
      end

      test "a classroom outside the cascade, or none chosen, is refused under the classroom field" do
        assert_equal [ :invalid, { classroom_public_id: [ :unavailable ] } ],
                     change(dto: choice(school_public_id: "sch-other")).then { [ it.code, it.errors ] }
        assert_equal [ :invalid, { classroom_public_id: [ :blank ] } ],
                     change(dto: choice(classroom_public_id: nil)).then { [ it.code, it.errors ] }
        assert_empty written
      end

      test "a visitor or any other role is refused before anything is read" do
        [ nil, *%i[teacher school_admin team].map { Entities::Identity::Actor.new(user_id: 5, role: it) } ].each do |actor|
          result = change(actor:)

          assert_equal [ :forbidden, {} ], [ result.code, result.errors ]
        end
        assert_empty @journal
        assert_equal 0, @transaction.calls
      end

      # La course entre deux classes : l'index index_classroom_students_one_active_primary refuse la seconde adhésion
      # active ; l'élève lit un « Réessaie » neutre, pas « déjà inscrit dans cette classe ».
      test "atomicity: if the new membership fails, the old one is not left, nothing is traced, a neutral conflict" do
        result = change(refuse: true)

        assert_equal [ :conflict, { base: [ :change_conflict ] } ], [ result.code, result.errors ]
        assert_empty written
      end

      test "ADR-0050: the move is traced with the address of the request" do
        assert change(ip: "203.0.113.9").success?
        assert_equal moved(ip: "203.0.113.9"), @journal.last
      end

      test "nothing left to leave (closed meanwhile): :forbidden no_active_classroom, nothing written" do
        result = change(leaves: false)

        assert_equal [ :forbidden, { base: [ :no_active_classroom ] } ], [ result.code, result.errors ]
        assert_empty written
      end

      test "an archived classroom chosen by the cascade is refused under the classroom field" do
        result = change(classrooms: [ classroom(status: "archived") ])

        assert_equal [ :invalid, { classroom_public_id: [ :unavailable ] } ], [ result.code, result.errors ]
        assert_empty written
      end

      test "the current classroom, even full, is same_classroom before any JoinPolicy reason" do
        [ choice, link ].each do |dto|
          @journal.clear
          result = change(dto:, primary: membership(classroom_id: 7), classrooms: [ classroom(active_students_count: 80) ])

          assert_equal [ :invalid, { base: [ :same_classroom ] } ], [ result.code, result.errors ]
        end
      end
    end
  end
end
