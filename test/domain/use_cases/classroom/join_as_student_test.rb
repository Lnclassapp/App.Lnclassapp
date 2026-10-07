require "test_helper"

module UseCases
  module Classroom
    class JoinAsStudentTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
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

        def initialize(journal, classroom)
          @journal = journal
          @classroom = classroom
        end

        def lock_by_join_code(join_code:)
          @journal << [ :lock, join_code ]
          @classroom if @classroom.join_code == join_code
        end
      end

      class FakeMemberships
        include Ports::Classroom::MembershipRepositoryPort

        def initialize(journal, primary:, refuse:)
          @journal = journal
          @primary = primary
          @refuse = refuse
        end

        def primary_for(student_id:)
          @journal << [ :primary_for, student_id ]
          @primary
        end

        def leave_primary(student_id:, at:)
          @journal << [ :leave, student_id, at ]
          true
        end

        def add_primary(classroom_id:, student_id:, via:, at:)
          return Shared::Result.failure(:conflict, errors: { base: [ :already_member ] }) if @refuse

          @journal << [ :add, classroom_id, student_id, at ]
          Shared::Result.success
        end
      end

      setup do
        @journal = []
        @transaction = JournalTransaction.new(@journal)
        @student = Entities::Identity::Actor.new(user_id: 41, role: :student)
      end

      def classroom(**overrides)
        Entities::Classroom::Classroom.new(id: 7, public_id: "cls-7", name: "Tle D 1", join_code: "kfm37", school_id: 3,
                                           level_id: 2, school_year: "2026-2027", active_students_count: 12, **overrides)
      end

      def membership(status)
        Membership.new(classroom_id: 5, student_id: 41, primary: true, joined_at: NOW - 400.days, left_at: nil,
                       classroom_status: status)
      end

      def join(actor: @student, code: "KFM37", classroom: self.classroom, primary: nil, refuse: false)
        JoinAsStudent.new(classrooms: FakeClassrooms.new(@journal, classroom),
                          memberships: FakeMemberships.new(@journal, primary:, refuse:),
                          policy: Policies::Classroom::JoinPolicy.new, transaction: @transaction, clock: Clock.new(NOW))
                     .call(actor:, code:)
      end

      test "CL-06 : un élève dont la classe principale est archivée quitte l'ancienne et rejoint la nouvelle" do
        result = join(primary: membership("archived"))

        assert result.success?
        assert_equal "cls-7", result.value.public_id
        assert_equal [ [ :lock, "kfm37" ], [ :primary_for, 41 ], [ :leave, 41, NOW ], [ :add, 7, 41, NOW ] ], @journal
        assert_equal 1, @transaction.calls
      end

      test "un élève sans classe principale active rejoint la classe sans rien quitter" do
        result = join

        assert result.success?
        assert_equal [ [ :lock, "kfm37" ], [ :primary_for, 41 ], [ :add, 7, 41, NOW ] ], @journal
      end

      test "CL-06 : un élève dont la classe principale est active reçoit :conflict et rien ne change" do
        result = join(primary: membership("active"))

        assert_equal [ :conflict, { base: [ :already_enrolled ] } ], [ result.code, result.errors ]
        assert_equal [ [ :lock, "kfm37" ], [ :primary_for, 41 ] ], @journal
      end

      test "un code inconnu : :not_found, rien n'est lu ni écrit ensuite" do
        result = join(code: "zzz99")

        assert_equal :not_found, result.code
        assert_equal [ [ :lock, "zzz99" ] ], @journal
      end

      test "les refus de JoinPolicy passent avant tout changement : classe archivée, classe complète" do
        assert_equal [ :forbidden, { base: [ :classroom_archived ] } ],
                     join(classroom: classroom(status: "archived"), primary: membership("archived")).then { [ it.code, it.errors ] }
        assert_equal [ :forbidden, { base: [ :classroom_full ] } ],
                     join(classroom: classroom(active_students_count: 80)).then { [ it.code, it.errors ] }
        assert_equal [ [ :lock, "kfm37" ] ] * 2, @journal
      end

      test "un enseignant est refusé par la policy, un visiteur n'a pas de compte à inscrire" do
        assert_equal [ :forbidden, {} ],
                     join(actor: Entities::Identity::Actor.new(user_id: 5, role: :teacher)).then { [ it.code, it.errors ] }
        assert_equal :forbidden, join(actor: nil).code
        assert_equal [ [ :lock, "kfm37" ] ], @journal
        assert_equal 1, @transaction.calls
      end

      test "atomicité : si la nouvelle adhésion échoue, l'ancienne n'est pas close" do
        result = join(primary: membership("archived"), refuse: true)

        assert_equal [ :conflict, { base: [ :already_member ] } ], [ result.code, result.errors ]
        assert_empty @journal
      end
    end
  end
end
