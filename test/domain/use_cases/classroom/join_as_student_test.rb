require "test_helper"

module UseCases
  module Classroom
    # CL-06, IL-15, IL-16, IL-17, IL-18 (ADR-0040, ADR-0085 §4.3): a signed-in student without an active classroom (archived,
    # or removed) enters the classroom chosen in the cascade (way « standard ») or given by a link (way « link »), without a
    # new account; an archived primary classroom is left in the same transaction. The classroom they were removed from is
    # refused by the standard way and reopened by the link. There is no classroom code any more (Lot F).
    class JoinAsStudentTest < ActiveSupport::TestCase
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

        def initialize(journal, primary:, removed_from:, refuse:)
          @journal = journal
          @primary = primary
          @removed_from = removed_from
          @refuse = refuse
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
          true
        end

        def add_primary(classroom_id:, student_id:, via:, at:)
          return Shared::Result.failure(:conflict, errors: { base: [ :already_member ] }) if @refuse

          @journal << [ :add, classroom_id, student_id, via, at ]
          Shared::Result.success
        end
      end

      setup do
        @journal = []
        @transaction = JournalTransaction.new(@journal)
        @student = Entities::Identity::Actor.new(user_id: 41, role: :student)
        @school = Entities::School::School.new(id: 3, public_id: "sch-3", name: "Lycée Moderne de Cocody", status: "active")
        @level = Entities::Catalog::Level.new(id: 2, slug: "3eme", name: "3ème")
      end

      def classroom(**overrides)
        Entities::Classroom::Classroom.new(id: 7, public_id: "cls-7", name: "3e 2", school_id: 3, level_id: 2,
                                           school_year: YEAR, link_token: TOKEN, active_students_count: 12, **overrides)
      end

      def membership(status, classroom_id: 5)
        Membership.new(classroom_id:, student_id: 41, primary: true, joined_at: NOW - 400.days, left_at: nil,
                       classroom_status: status)
      end

      def choice(**attributes)
        Dtos::Classroom::StudentRegistrationInput.new(drena_public_id: "drn-1", school_public_id: "sch-3", level_slug: "3eme",
                                                      classroom_public_id: "cls-7", **attributes)
      end

      def join(actor: @student, dto: choice, classrooms: [ classroom ], schools: [ @school ], primary: nil,
               removed_from: [], refuse: false)
        JoinAsStudent.new(classrooms: FakeClassrooms.new(@journal, classrooms), schools: FakeSchools.new(*schools),
                          taxonomy: FakeTaxonomy.new(@level),
                          memberships: FakeMemberships.new(@journal, primary:, removed_from:, refuse:),
                          policy: Policies::Classroom::JoinPolicy.new, transaction: @transaction, clock: Clock.new(NOW))
                     .call(actor:, dto:)
      end

      def added = @journal.find { it.first == :add }

      test "IL-17: a student whose primary classroom is archived leaves it and enters the chosen one, way « standard »" do
        result = join(primary: membership("archived"))

        assert result.success?
        assert_equal "cls-7", result.value.public_id
        assert_equal [ [ :primary_for, 41 ], [ :lock, "cls-7" ], [ :removed_from?, 7, 41 ], [ :leave, 41, NOW ],
                       [ :add, 7, 41, "standard", NOW ] ], @journal
        assert_equal 1, @transaction.calls
      end

      test "IL-15: a removed student (no primary classroom) enters another classroom, leaving nothing" do
        result = join(removed_from: [ 5 ])

        assert result.success?
        assert_equal [ [ :primary_for, 41 ], [ :lock, "cls-7" ], [ :removed_from?, 7, 41 ], [ :add, 7, 41, "standard", NOW ] ],
                     @journal
      end

      test "IL-15: the classroom the student was removed from is refused by the standard way, nothing changes" do
        result = join(removed_from: [ 7 ])

        assert_equal [ :forbidden, { base: [ :removed_from_classroom ] } ], [ result.code, result.errors ]
        assert_nil added
      end

      test "IL-16: by its link, the classroom the student was removed from takes them back, way « link »" do
        result = join(dto: choice(link_token: TOKEN, classroom_public_id: nil), removed_from: [ 7 ])

        assert result.success?
        assert_equal [ [ :primary_for, 41 ], [ :lock_link, TOKEN ], [ :add, 7, 41, "link", NOW ] ], @journal
      end

      test "IL-16: a valid link prevails over the classroom sent, and needs neither school nor level" do
        other = classroom(id: 8, public_id: "cls-8", link_token: "ffffffffffff")

        result = join(dto: Dtos::Classroom::StudentRegistrationInput.new(link_token: TOKEN, classroom_public_id: "cls-8"),
                      classrooms: [ classroom, other ], primary: membership("archived"))

        assert result.success?
        assert_equal "cls-7", result.value.public_id
        assert_equal [ :add, 7, 41, "link", NOW ], added
      end

      test "a link that no longer leads to an open classroom: :not_found, nothing written" do
        archived = classroom(status: "archived")
        closed_school = Entities::School::School.new(id: 3, public_id: "sch-3", name: "Lycée fermé", status: "inactive")
        cases = { "unknown" => [ [ classroom ], [ @school ], "cccccccccccc" ], "archived" => [ [ archived ], [ @school ], TOKEN ],
                  "inactive school" => [ [ classroom ], [ closed_school ], TOKEN ] }

        cases.each do |label, (classrooms, schools, token)|
          @journal.clear
          result = join(dto: choice(link_token: token), classrooms:, schools:)

          assert_equal :not_found, result.code, label
          assert_equal [ [ :primary_for, 41 ], [ :lock_link, token ] ], @journal, label
        end
      end

      test "a classroom outside the cascade is refused in :invalid under the classroom, nothing written" do
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
          result = join(dto: choice(**attributes), classrooms: [ candidate ], schools: [ @school, draft_school ])

          assert_equal [ :invalid, { classroom_public_id: [ :unavailable ] } ], [ result.code, result.errors ], label
          assert_equal [ [ :primary_for, 41 ], [ :lock, "cls-7" ] ], @journal, label
        end
      end

      test "no classroom chosen: :invalid, the classroom is asked" do
        result = join(dto: choice(classroom_public_id: nil))

        assert_equal [ :invalid, { classroom_public_id: [ :blank ] } ], [ result.code, result.errors ]
        assert_equal [ [ :primary_for, 41 ] ], @journal
      end

      test "IL-18: a student whose primary classroom is active is told so before anything else, and nothing changes" do
        [ choice, choice(link_token: TOKEN), choice(classroom_public_id: nil) ].each do |dto|
          @journal.clear
          result = join(dto:, primary: membership("active"))

          assert_equal [ :forbidden, { base: [ :already_enrolled ] } ], [ result.code, result.errors ]
          assert_equal [ [ :primary_for, 41 ] ], @journal
        end
      end

      test "a full classroom is refused by both ways, with its reason" do
        full = classroom(active_students_count: 80)

        [ choice, choice(link_token: TOKEN) ].each do |dto|
          result = join(dto:, classrooms: [ full ])

          assert_equal [ :forbidden, { base: [ :classroom_full ] } ], [ result.code, result.errors ]
        end
        assert_nil added
      end

      test "a visitor has no account to enrol, any other role is refused; nothing is read" do
        assert_equal [ :forbidden, {} ], join(actor: nil).then { [ it.code, it.errors ] }
        %i[teacher school_admin team].each do |role|
          result = join(actor: Entities::Identity::Actor.new(user_id: 5, role:))

          assert_equal [ :forbidden, {} ], [ result.code, result.errors ]
        end
        assert_empty @journal
        assert_equal 0, @transaction.calls
      end

      test "atomicity: if the new membership fails, the archived one is not left" do
        result = join(primary: membership("archived"), refuse: true)

        assert_equal [ :conflict, { base: [ :already_member ] } ], [ result.code, result.errors ]
        assert_empty @journal
      end

      test "IL-02: no classroom code is accepted any more" do
        subject = JoinAsStudent.new(classrooms: nil, schools: nil, taxonomy: nil, memberships: nil, policy: nil, transaction: nil,
                                    clock: nil)

        assert_raises(ArgumentError) { subject.call(actor: @student, code: "kfm37") }
      end
    end
  end
end
