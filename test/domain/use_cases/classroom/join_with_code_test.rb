require "test_helper"

module UseCases
  module Classroom
    class JoinWithCodeTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      KEY = "k" * 32
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

        attr_reader :locked

        def initialize(journal, *classrooms)
          @journal = journal
          @classrooms = classrooms
          @locked = []
        end

        def lock_by_join_code(join_code:)
          @locked << join_code
          @journal << [ :lock, join_code ]
          @classrooms.find { it.join_code == join_code }
        end
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

          @journal << [ :membership, classroom_id, student_id, at ]
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
      end

      def classroom(**overrides)
        Entities::Classroom::Classroom.new(id: 7, public_id: "cls-7", name: "6ème 1", join_code: "kfm37", school_id: 3,
                                           level_id: 2, school_year: "2026-2027", active_students_count: 12, **overrides)
      end

      def join(code: "KFM 37", actor: nil, classroom: self.classroom, taken: [], refuse_membership: false, **attributes)
        @classrooms = FakeClassrooms.new(@journal, classroom)
        @registrations = FakeRegistrations.new(@journal, taken:)
        dto = Dtos::Classroom::JoinWithCodeInput.new(last_name: "Kouassi", first_name: "Aya Marie", gender: "female",
                                                     contact: "07 01 02 03 04", pin: "4821", pin_confirmation: "4821",
                                                     **attributes)
        JoinWithCode.new(
          classrooms: @classrooms, registrations: @registrations,
          memberships: FakeMemberships.new(@journal, refuse: refuse_membership), sessions: FakeSessions.new(@journal),
          policy: Policies::Classroom::JoinPolicy.new, transaction: @transaction, digest_key: KEY, clock: Clock.new(NOW)
        ).call(actor:, code:, dto:, ip: "1.2.3.4", user_agent: "Chrome")
      end

      test "crée l'élève, en fait le membre principal de la classe et ouvre sa session, sous le verrou de la classe" do
        result = join

        assert result.success?
        assert_equal [ 41, "0701020304", "student" ], [ result.value.user.id, result.value.user.contact, result.value.user.role ]
        assert_equal "cls-7", result.value.classroom.public_id
        token = result.value.token
        assert_operator token.length, :>=, 43
        assert_equal [ [ :lock, "kfm37" ],
                       [ :user, "0701020304", "student" ],
                       [ :membership, 7, 41, NOW ],
                       [ :session, 41, Entities::Identity::SecretDigest.hmac(token, key: KEY), "1.2.3.4", "Chrome", NOW ] ],
                     @journal
        assert_equal [ "Kouassi", "Aya Marie", "female", "4821" ],
                     [ @registrations.received[:user].last_name, @registrations.received[:user].first_name,
                       @registrations.received[:user].gender, @registrations.received[:pin] ]
        assert_equal 1, @transaction.calls
      end

      test "TR-cadre-1 : le rôle est imposé à student, l'entité transmise ne porte jamais un autre rôle" do
        join

        assert_equal "student", @registrations.received[:user].role
        assert_nil @registrations.received[:user].team_role
      end

      test "une saisie invalide : :invalid avec les erreurs du formulaire, rien n'est lu ni écrit" do
        result = join(pin: "", pin_confirmation: "")

        assert_equal :invalid, result.code
        assert_equal %i[pin], result.errors.keys
        assert_empty @journal
        assert_equal 0, @transaction.calls
      end

      test "une confirmation de PIN différente : :invalid sur la confirmation" do
        assert_equal %i[pin_confirmation], join(pin_confirmation: "1357").errors.keys
        assert_empty @journal
      end

      test "un code inconnu : :not_found, aucun compte" do
        result = join(code: "zzz99")

        assert_equal :not_found, result.code
        assert_equal [ [ :lock, "zzz99" ] ], @journal
        assert_nil @registrations.received
      end

      test "CL-06 : un ancien code, remplacé depuis, est inconnu : :not_found" do
        result = join(code: "kfm37", classroom: classroom(join_code: "abc23"))

        assert_equal :not_found, result.code
        assert_nil @registrations.received
      end

      test "CL-06 : une classe archivée est refusée avec sa raison, aucun compte" do
        result = join(classroom: classroom(status: "archived"))

        assert_equal [ :forbidden, { base: [ :classroom_archived ] } ], [ result.code, result.errors ]
        assert_nil @registrations.received
        assert_equal [ [ :lock, "kfm37" ] ], @journal
      end

      test "CL-06 : une classe complète est refusée avec sa raison, aucun compte" do
        result = join(classroom: classroom(active_students_count: 80))

        assert_equal [ :forbidden, { base: [ :classroom_full ] } ], [ result.code, result.errors ]
        assert_nil @registrations.received
      end

      test "une personne connectée autre qu'un élève est refusée par la policy, aucun compte" do
        result = join(actor: Entities::Identity::Actor.new(user_id: 3, role: :teacher))

        assert_equal [ :forbidden, {} ], [ result.code, result.errors ]
        assert_nil @registrations.received
      end

      test "un numéro déjà pris : :conflict sur le numéro, aucune ligne" do
        result = join(taken: [ "0701020304" ])

        assert_equal [ :conflict, { contact: [ :taken ] } ], [ result.code, result.errors ]
        assert_equal [ [ :lock, "kfm37" ] ], @journal
      end

      test "atomicité : si l'adhésion échoue, le compte créé est annulé avec elle" do
        result = join(refuse_membership: true)

        assert_equal [ :conflict, { base: [ :already_member ] } ], [ result.code, result.errors ]
        assert_empty @journal, "aucun compte sans son adhésion"
        assert_equal 1, @transaction.calls
      end
    end
  end
end
