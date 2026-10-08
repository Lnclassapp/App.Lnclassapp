require "test_helper"

module UseCases
  module Classroom
    # IL-01, IL-03, IL-05, IL-07, IL-08, IL-09, IL-10, IL-19 (ADR-0085 §4.1 to §4.3): a visitor creates a student account
    # and enters at once the classroom chosen in the cascade (way « standard ») or given by a valid link (way « link »),
    # in one transaction under the classroom lock. A valid token prevails over the classroom sent; an invalid one falls
    # back to the standard way. No account survives a refusal.
    class RegisterStudentTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 7, 12)
      YEAR = "2026-2027".freeze
      KEY = "k" * 32
      TOKEN = "0a1b2c3d4e5f".freeze
      Clock = Data.define(:now)

      # Toutes les écritures des faux repositories vont dans un même journal : la transaction le restaure si
      # une exception la traverse, comme la base annule une transaction.
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

      class FakeRegistrations
        include Ports::Identity::RegistrationRepositoryPort

        attr_reader :received

        def initialize(journal, taken:)
          @journal = journal
          @taken = taken
        end

        def create_student(user:, pin:)
          @received = { user:, pin: }
          return Shared::Result.failure(:conflict, errors: { contact: [ :taken ] }) if @taken.include?(user.contact)

          @journal << [ :user, user.contact, user.role ]
          Shared::Result.success(Entities::Identity::User.new(id: 41, public_id: "usr-41", last_name: user.last_name,
                                                              first_name: user.first_name, contact: user.contact,
                                                              gender: user.gender, role: "student"))
        end
      end

      class FakeMemberships
        include Ports::Classroom::MembershipRepositoryPort

        def initialize(journal, refuse:)
          @journal = journal
          @refuse = refuse
        end

        def add_primary(classroom_id:, student_id:, via:, at:)
          return Shared::Result.failure(:conflict, errors: { base: [ :already_member ] }) if @refuse

          @journal << [ :membership, classroom_id, student_id, via, at ]
          Shared::Result.success
        end
      end

      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        def initialize(journal) = @journal = journal

        def create(user_id:, token_digest:, ip:, user_agent:, at:)
          @journal << [ :session, user_id, token_digest, ip, user_agent, at ]
          9
        end
      end

      setup do
        @journal = []
        @transaction = JournalTransaction.new(@journal)
        @school = Entities::School::School.new(id: 3, public_id: "sch-3", name: "Lycée Moderne de Cocody", status: "active")
        @level = Entities::Catalog::Level.new(id: 2, slug: "3eme", name: "3ème")
      end

      def classroom(**overrides)
        Entities::Classroom::Classroom.new(id: 7, public_id: "cls-7", name: "3e 2", school_id: 3, level_id: 2, school_year: YEAR,
                                           link_token: TOKEN, teacher_ids: [ 5 ], active_students_count: 12, **overrides)
      end

      def register(actor: nil, classrooms: [ classroom ], schools: [ @school ], taken: [], refuse_membership: false, **attributes)
        @registrations = FakeRegistrations.new(@journal, taken:)
        dto = Dtos::Classroom::StudentRegistrationInput.new(
          full_name: "KOUASSI Aya Marie", gender: "female", contact: "07 01 02 03 04", pin: "4821", pin_confirmation: "4821",
          drena_public_id: "drn-1", school_public_id: "sch-3", level_slug: "3eme", classroom_public_id: "cls-7", **attributes
        )
        RegisterStudent.new(
          classrooms: FakeClassrooms.new(@journal, classrooms), schools: FakeSchools.new(*schools),
          taxonomy: FakeTaxonomy.new(@level), registrations: @registrations,
          memberships: FakeMemberships.new(@journal, refuse: refuse_membership), sessions: FakeSessions.new(@journal),
          policy: Policies::Classroom::JoinPolicy.new, transaction: @transaction, digest_key: KEY, clock: Clock.new(NOW)
        ).call(actor:, dto:, ip: "1.2.3.4", user_agent: "Chrome")
      end

      def membership = @journal.find { it.first == :membership }

      test "IL-01: creates the student, enters the chosen classroom at once, way « standard », and opens the session" do
        result = register

        assert result.success?
        assert_equal [ 41, "0701020304", "student" ], [ result.value.user.id, result.value.user.contact, result.value.user.role ]
        assert_equal "cls-7", result.value.classroom.public_id
        token = result.value.token
        assert_operator token.length, :>=, 43
        assert_equal [ [ :lock, "cls-7" ],
                       [ :user, "0701020304", "student" ],
                       [ :membership, 7, 41, "standard", NOW ],
                       [ :session, 41, Entities::Identity::SecretDigest.hmac(token, key: KEY), "1.2.3.4", "Chrome", NOW ] ],
                     @journal
        assert_equal [ "KOUASSI", "Aya Marie", "female", "4821" ],
                     [ @registrations.received[:user].last_name, @registrations.received[:user].first_name,
                       @registrations.received[:user].gender, @registrations.received[:pin] ]
        assert_equal 1, @transaction.calls
      end

      test "TR-cadre-1: the role is imposed, the entity sent never carries another role" do
        register

        assert_equal "student", @registrations.received[:user].role
        assert_nil @registrations.received[:user].team_role
      end

      test "IL-03: a classroom without any teacher takes the student at once" do
        result = register(classrooms: [ classroom(teacher_ids: []) ])

        assert result.success?
        assert_equal "standard", membership[3]
      end

      test "IL-08: a valid link gives its classroom, way « link », and prevails over the classroom sent" do
        other = classroom(id: 8, public_id: "cls-8", name: "3e 3", link_token: "ffffffffffff")

        result = register(classrooms: [ classroom, other ], link_token: TOKEN, classroom_public_id: "cls-8")

        assert result.success?
        assert_equal "cls-7", result.value.classroom.public_id
        assert_equal [ :lock_link, TOKEN ], @journal.first
        assert_equal [ :membership, 7, 41, "link", NOW ], membership
        assert_not_includes @journal, [ :lock, "cls-8" ]
      end

      test "IL-08: with a valid link, neither the school, the level nor the classroom need to be sent" do
        result = register(link_token: TOKEN, drena_public_id: nil, school_public_id: nil, level_slug: nil,
                          classroom_public_id: nil)

        assert result.success?
        assert_equal "link", membership[3]
      end

      test "IL-09: an unknown, archived or inactive-school link falls back to the classroom chosen, way « standard »" do
        archived = classroom(id: 9, public_id: "cls-9", link_token: "aaaaaaaaaaaa", status: "archived")
        closed_school = Entities::School::School.new(id: 4, public_id: "sch-4", name: "Lycée fermé", status: "inactive")
        closed = classroom(id: 10, public_id: "cls-10", school_id: 4, link_token: "bbbbbbbbbbbb")

        [ "cccccccccccc", "aaaaaaaaaaaa", "bbbbbbbbbbbb" ].each do |token|
          @journal.clear
          result = register(classrooms: [ classroom, archived, closed ], schools: [ @school, closed_school ], link_token: token)

          assert result.success?, token
          assert_equal "cls-7", result.value.classroom.public_id
          assert_equal [ :membership, 7, 41, "standard", NOW ], membership
        end
      end

      test "IL-09: an invalid link and no classroom chosen: the classroom is asked, no account" do
        result = register(link_token: "cccccccccccc", classroom_public_id: nil)

        assert_equal [ :invalid, { classroom_public_id: [ :blank ] } ], [ result.code, result.errors ]
        assert_nil @registrations.received
      end

      test "IL-10: no token (« Ce n'est pas ta classe ? »): the way is « standard »" do
        register(link_token: nil)

        assert_equal "standard", membership[3]
      end

      test "IL-07: a classroom outside the list is refused in :invalid under the classroom, no account" do
        draft_school = Entities::School::School.new(id: 5, public_id: "sch-5", name: "Lycée brouillon", status: "draft")
        cases = {
          "archived" => [ classroom(status: "archived"), {} ],
          "of another year" => [ classroom(school_year: "2025-2026"), {} ],
          "of another level" => [ classroom(level_id: 99), {} ],
          "of another school" => [ classroom, { school_public_id: "sch-other" } ],
          "of a level not sent" => [ classroom, { level_slug: "6eme" } ],
          "of a draft school" => [ classroom(school_id: 5), { school_public_id: "sch-5" } ],
          "unknown" => [ classroom(public_id: "cls-other"), {} ]
        }

        cases.each do |label, (candidate, attributes)|
          @journal.clear
          result = register(classrooms: [ candidate ], schools: [ @school, draft_school ], **attributes)

          assert_equal [ :invalid, { classroom_public_id: [ :unavailable ] } ], [ result.code, result.errors ], label
          assert_nil @registrations.received, label
          assert_equal [ [ :lock, "cls-7" ] ], @journal, label
        end
      end

      test "IL-05: a full classroom is refused in :forbidden with its reason, by both ways, no account" do
        full = classroom(active_students_count: 80)

        [ {}, { link_token: TOKEN } ].each do |attributes|
          result = register(classrooms: [ full ], **attributes)

          assert_equal [ :forbidden, { base: [ :classroom_full ] } ], [ result.code, result.errors ]
          assert_nil @registrations.received
        end
      end

      test "an invalid entry: :invalid with the form's errors, nothing read nor written" do
        result = register(full_name: "Kouassi", pin_confirmation: "1357")

        assert_equal :invalid, result.code
        assert_equal %i[pin_confirmation full_name], result.errors.keys
        assert_empty @journal
        assert_equal 0, @transaction.calls
      end

      test "IL-18: a signed-in student is told they are already enrolled; any other role is refused; nothing is read" do
        student = register(actor: Entities::Identity::Actor.new(user_id: 3, role: :student))

        assert_equal [ :forbidden, { base: [ :already_enrolled ] } ], [ student.code, student.errors ]

        %i[teacher school_admin team].each do |role|
          result = register(actor: Entities::Identity::Actor.new(user_id: 3, role:))

          assert_equal [ :forbidden, {} ], [ result.code, result.errors ]
        end
        assert_empty @journal
        assert_nil @registrations.received
      end

      test "IL-19: a number already used: :conflict on the number, no membership" do
        result = register(taken: [ "0701020304" ])

        assert_equal [ :conflict, { contact: [ :taken ] } ], [ result.code, result.errors ]
        assert_equal [ [ :lock, "cls-7" ] ], @journal
      end

      test "atomicity: if the membership fails, the account created is cancelled with it" do
        result = register(refuse_membership: true)

        assert_equal [ :conflict, { base: [ :already_member ] } ], [ result.code, result.errors ]
        assert_empty @journal, "aucun compte sans son adhésion"
        assert_equal 1, @transaction.calls
      end
    end
  end
end
