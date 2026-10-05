require "test_helper"

# ID-01 to ID-06 (ADR-0077 §4.3): a visitor registers as the direction of an active school with its code; the role is
# always school_admin; the account is attached by the code under the cap, or not created at all; the session opens.
module UseCases
  module Identity
    class RegisterSchoolStaffTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 4, 9)
      KEY = "k" * 32
      Clock = Data.define(:now)
      SchoolEntity = Entities::School::School
      ERRORS = "activemodel.errors.models.dtos/identity/school_staff_registration_input.attributes".freeze

      # Every fake write goes to one journal: the transaction restores it when an exception crosses it, as the database
      # rolls back a transaction.
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

      class FakeRegistrations
        include Ports::Identity::RegistrationRepositoryPort

        attr_reader :received

        def initialize(journal, taken: [])
          @journal = journal
          @taken = taken
        end

        def create_school_admin(user:, pin:)
          @received = { user:, pin: }
          return Shared::Result.failure(:conflict, errors: { contact: [ :taken ] }) if @taken.include?(user.contact)

          @journal << [ :user, user.contact, user.role ]
          Shared::Result.success(Entities::Identity::User.new(id: 41, public_id: "usr-41", last_name: user.last_name,
                                                              first_name: user.first_name, contact: user.contact,
                                                              gender: user.gender, role: user.role))
        end
      end

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        def initialize(*schools) = @schools = schools
        def find_by_school_code(school_code:) = @schools.find { it.school_code == school_code }
      end

      # Ports::School::StaffRepositoryPort#attach_by_code: the cap is counted by the adapter under a lock; here, `taken`
      # directions by the code are already there.
      class FakeStaffs
        include Ports::School::StaffRepositoryPort

        attr_reader :received

        def initialize(journal, taken:)
          @journal = journal
          @taken = taken
        end

        def attach_by_code(user_id:, school_id:, cap:, at:)
          @received = { user_id:, school_id:, cap:, at: }
          return false if @taken >= cap

          @journal << [ :staff, user_id, school_id, "code", at ]
          true
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

      class FakeAuditLog
        include Ports::Identity::AuditLogPort

        def initialize(journal) = @journal = journal

        def record(action:, actor_id:, at:, subject_type: nil, subject_id: nil, metadata: {}, ip: nil)
          raise ArgumentError, action unless Entities::Identity::AuditAction.valid?(action)

          @journal << [ :audit, action, actor_id, subject_type, subject_id, metadata, ip, at ]
          true
        end
      end

      setup do
        @journal = []
        @transaction = JournalTransaction.new(@journal)
        @schools = FakeSchools.new(
          SchoolEntity.new(id: 31, public_id: "sch-a", drena_id: 1, name: "Lycée Classique d'Abidjan", school_type: "public",
                           cycle: "both", status: "active", school_code: "k7m4qz"),
          SchoolEntity.new(id: 32, public_id: "sch-closed", drena_id: 1, name: "Lycée fermé", school_type: "public",
                           cycle: "both", status: "inactive", school_code: "abc234"),
          SchoolEntity.new(id: 33, public_id: "sch-c", drena_id: 2, name: "Lycée en brouillon", school_type: "public",
                           cycle: "both", status: "draft", school_code: "xyz789")
        )
      end

      def register(actor: nil, taken_contacts: [], taken_places: 0, **attributes)
        @registrations = FakeRegistrations.new(@journal, taken: taken_contacts)
        @staffs = FakeStaffs.new(@journal, taken: taken_places)
        dto = Dtos::Identity::SchoolStaffRegistrationInput.new(
          last_name: "Kouassi", first_name: "Aya", gender: "female", contact: "07 01 02 03 04", pin: "4821",
          pin_confirmation: "4821", school_code: "K7M-4QZ", **attributes
        )
        RegisterSchoolStaff.new(
          registrations: @registrations, schools: @schools, staffs: @staffs, sessions: FakeSessions.new(@journal),
          audit_log: FakeAuditLog.new(@journal), policy: Policies::Identity::RegisterSchoolStaffPolicy.new,
          transaction: @transaction, digest_key: KEY, clock: Clock.new(NOW)
        ).call(actor:, dto:, ip: "1.2.3.4", user_agent: "Chrome")
      end

      test "ID-01: crée le compte school_admin, le rattache par le code, ouvre la session et l'écrit au journal" do
        result = register

        assert result.success?
        assert_equal [ 41, "0701020304", "school_admin" ], [ result.value.user.id, result.value.user.contact, result.value.user.role ]
        token = result.value.token
        assert_operator token.length, :>=, 43
        assert_equal [ [ :user, "0701020304", "school_admin" ],
                       [ :staff, 41, 31, "code", NOW ],
                       [ :session, 41, Entities::Identity::SecretDigest.hmac(token, key: KEY), "1.2.3.4", "Chrome", NOW ],
                       [ :audit, "school_staff.registered", 41, "User", 41, { school_id: 31, joined_via: "code" }, "1.2.3.4", NOW ] ],
                     @journal
        assert_equal [ "Kouassi", "Aya", "female", "4821" ],
                     [ @registrations.received[:user].last_name, @registrations.received[:user].first_name,
                       @registrations.received[:user].gender, @registrations.received[:pin] ]
        assert_equal Entities::School::Staff::CODE_CAP, @staffs.received[:cap]
        assert_equal 1, @transaction.calls
      end

      test "le rôle est imposé : un rôle glissé dans la saisie n'existe pas pour le DTO" do
        assert_raises(ActiveModel::UnknownAttributeError) { register(role: "team") }
      end

      test "ID-02, ID-04: plafond atteint : le compte créé est annulé dans la transaction, base: cap_reached" do
        result = register(taken_places: 3)

        assert_equal :conflict, result.code
        assert_equal({ base: [ :cap_reached ] }, result.errors)
        assert_empty @journal
        assert_equal 1, @transaction.calls
      end

      test "ID-03: sous le plafond, le compte est créé" do
        assert register(taken_places: 2).success?
      end

      test "ID-05: code d'un établissement en brouillon, désactivé ou inconnu : school_code inclusion, rien n'est écrit" do
        %w[XYZ-789 ABC-234 ZZZ-999].each do |school_code|
          result = register(school_code:)

          assert_equal :invalid, result.code, school_code
          assert_equal({ school_code: [ :inclusion ] }, result.errors, school_code)
        end
        assert_empty @journal
        assert_equal 0, @transaction.calls
      end

      test "un code de classe a son propre message" do
        result = register(school_code: "KFM 37")

        assert_equal :invalid, result.code
        assert_equal [ I18n.t("#{ERRORS}.school_code.classroom_code") ], result.errors[:school_code]
      end

      test "ID-06: numéro déjà lié à un compte : contact taken, rien n'est écrit" do
        result = register(taken_contacts: [ "0701020304" ])

        assert_equal :conflict, result.code
        assert_equal({ contact: [ :taken ] }, result.errors)
        assert_empty @journal
      end

      test "une saisie invalide est refusée avant toute recherche" do
        result = register(pin_confirmation: "1357", gender: "")

        assert_equal :invalid, result.code
        assert_equal [ I18n.t("#{ERRORS}.pin_confirmation.confirmation") ], result.errors[:pin_confirmation]
        assert_equal [ I18n.t("#{ERRORS}.gender.inclusion") ], result.errors[:gender]
        assert_equal 0, @transaction.calls
      end

      test "un acteur connecté ne s'inscrit pas" do
        result = register(actor: Entities::Identity::Actor.new(user_id: 1, role: :teacher))

        assert_equal :forbidden, result.code
        assert_empty @journal
      end
    end
  end
end
