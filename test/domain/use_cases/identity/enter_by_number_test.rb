require "test_helper"

module UseCases
  module Identity
    # Chantiers entree-eleve-unifiee et connexion-numero-d-abord : le numéro seul dit s'il a un compte ; avec un code, un numéro
    # inscrit se connecte (« Code secret incorrect » sur un code faux) et un numéro inconnu confirme son entrée, code tapé une fois.
    class EnterByNumberTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 20, 9)
      Clock = Data.define(:now)
      Failures = Data.define(:count, :last_failed_at)

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def initialize(*users) = @users = users
        def authenticate(contact:, pin:) = (find_by_contact(contact:) if pin == "2468")
        def find_by_contact(contact:) = @users.find { it.contact == contact }
      end

      class FakeAttempts
        include Ports::Identity::LoginAttemptRepositoryPort

        attr_reader :records

        def initialize(count: 0, last_failed_at: nil)
          @failures = Failures.new(count:, last_failed_at:)
          @records = []
        end

        def consecutive_failures(contact:, kind:) = @failures
        def record(**attributes) = @records << attributes
      end

      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        attr_reader :created

        def create(**attributes) = @created = attributes
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        def record(**) = nil
      end

      setup do
        @student = Entities::Identity::User.new(id: 1, contact: "0701020304", role: "student")
        @teacher = Entities::Identity::User.new(id: 2, contact: "0501020304", role: "teacher")
        @attempts = FakeAttempts.new
        @sessions = FakeSessions.new
      end

      test "CA-2 : un numéro inscrit et son code ouvrent une session" do
        result = enter(contact: "07 01 02 03 04", pin: "2468")

        assert_predicate result, :success?
        assert_equal :signed_in, result.value.outcome
        assert_equal @student, result.value.user
        assert_predicate result.value.token, :present?
        assert_equal 1, @sessions.created[:user_id]
      end

      test "CA-3 : un enseignant inscrit est connecté par l'entrée élève" do
        result = enter(contact: "0501020304", pin: "2468")

        assert_equal :signed_in, result.value.outcome
        assert_equal "teacher", result.value.user.role
      end

      test "CA-4 : un code faux sur un numéro inscrit dit « code incorrect » et compte l'échec" do
        result = enter(contact: "0701020304", pin: "1111")

        assert_equal :invalid, result.code
        assert_equal({ pin: [ :wrong_pin ] }, result.errors)
        assert_nil @sessions.created
        assert_equal [ false ], @attempts.records.map { it[:succeeded] }
      end

      test "un numéro verrouillé reste verrouillé" do
        @attempts = FakeAttempts.new(count: 5, last_failed_at: NOW - 60)

        assert_equal :locked, enter(contact: "0701020304", pin: "2468").code
      end

      test "CA-1 : un numéro seul, inscrit, se dit connu, sans rien écrire ni rien rendre du compte" do
        result = enter(contact: "0701020304")

        assert_equal :known, result.value.outcome
        assert_equal "0701020304", result.value.contact
        assert_nil result.value.user
        assert_empty @attempts.records
        assert_nil @sessions.created
      end

      test "CA-2 : un numéro seul, inconnu, se dit nouveau, sans rien écrire" do
        result = enter(contact: "0101020304")

        assert_equal :new_number, result.value.outcome
        assert_empty @attempts.records
      end

      test "CA-9 : un numéro inconnu et son code, tapé une seule fois : l'entrée est confirmée" do
        result = enter(contact: "0101020304", pin: "1357")

        assert_equal :confirmed, result.value.outcome
        assert_equal "0101020304", result.value.contact
        assert_empty @attempts.records
        assert_nil @sessions.created
      end

      test "sans création (la connexion), un numéro inconnu et un code restent un numéro nouveau" do
        result = enter(contact: "0101020304", pin: "1357", creates: false)

        assert_equal :new_number, result.value.outcome
      end

      # Le code secret compte exactement 4 chiffres (décision du porteur, 2026-11-20) : rien n'est cherché sinon.
      test "un code secret qui n'a pas exactement 4 chiffres est refusé, sans rien chercher" do
        [ "123", "12345", "12a4", "" ].each do |pin|
          result = enter(contact: "0101020304", pin:)

          assert_equal :invalid, result.code, pin
          assert_equal 1, result.errors[:pin].size, pin
        end
        assert_empty @attempts.records
      end

      test "CA-10 : un numéro inscrit l'emporte sur une création : jamais de second compte" do
        result = enter(contact: "0701020304", pin: "2468")

        assert_equal :signed_in, result.value.outcome
      end

      test "un numéro hors format ou un code mal formé ne cherche rien" do
        assert_equal [ :contact ], enter(contact: "0901020304", pin: "1357").errors.keys
        assert_equal [ "Tape ton numéro de téléphone." ], enter(contact: "", pin: "1357").errors[:contact]
        assert_equal [ :pin ], enter(contact: "0101020304", pin: "13").errors.keys
      end

      test "la coque Android d'un autre rôle refuse comme à la connexion" do
        result = enter(contact: "0501020304", pin: "2468", client: "android_student")

        assert_equal :conflict, result.code
        assert_equal [ Authenticate::WRONG_APP ], result.errors[:base]
      end

      private

      def enter(creates: true, **attributes)
        dto = Dtos::Identity::StudentEntryInput.new(ip: "1.2.3.4", user_agent: "test", **attributes)
        EnterByNumber.new(users: FakeUsers.new(@student, @teacher), login_attempts: @attempts, sessions: @sessions,
                          audit_log: FakeAudit.new, digest_key: "k" * 32, clock: Clock.new(NOW)).call(dto:, creates:)
      end
    end
  end
end
