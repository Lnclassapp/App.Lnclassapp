require "test_helper"

module UseCases
  module Identity
    # CP-11, CP-14 (ADR-0063): a teacher whose school has no code for them signs up by its national code (or by the school
    # chosen in its DRENA). ADR-0073: while validation is paused, the request is approved at once — the teacher is attached
    # to the school and signed in, in one transaction.
    class RegisterPendingTeacherTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 28, 12)
      KEY = "k" * 32
      Clock = Data.define(:now)
      SchoolEntity = Entities::School::School

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

        def initialize(journal, taken: [])
          @journal = journal
          @taken = taken
        end

        def create_teacher(user:, pin:, material_id:)
          return Shared::Result.failure(:conflict, errors: { contact: [ :taken ] }) if @taken.include?(user.contact)

          @journal << [ :user, user.contact, user.role, material_id, pin ]
          Shared::Result.success(Entities::Identity::User.new(id: 41, public_id: "usr-41", last_name: user.last_name,
                                                              first_name: user.first_name, contact: user.contact,
                                                              gender: user.gender, role: "teacher"))
        end
      end

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        def initialize(*schools) = @schools = schools
        def find_by_national_code(national_code:) = @schools.find { it.national_code == national_code }
        def find_by_public_id(public_id:) = @schools.find { it.public_id == public_id }
      end

      class FakeJoinRequests
        include Ports::School::JoinRequestRepositoryPort

        def initialize(journal, pending: {}, refuse: false, decided: false)
          @journal = journal
          @pending = pending
          @refuse = refuse
          @decided = decided
        end

        # Le plafond est tenu par le repository, sous verrou (B2) : le faux le reproduit à partir de `pending`.
        def create(teacher_id:, school_id:, at:, max_pending:)
          return Shared::Result.failure(:conflict) if @refuse
          return Shared::Result.failure(:invalid, errors: { base: [ :too_many_pending ] }) if @pending.fetch(school_id, 0) >= max_pending

          @journal << [ :join_request, teacher_id, school_id, at ]
          Shared::Result.success(Entities::School::JoinRequest.new(id: 5, public_id: "req-5", teacher_id:, school_id:,
                                                                   status: "pending", teacher_name: "Awa Koné"))
        end

        def approve(id:, decided_by_id:, via:, at:)
          return Shared::Result.failure(:conflict, errors: { base: [ :already_decided ] }) if @decided

          @journal << [ :approved, id, decided_by_id, via, at ]
          Shared::Result.success
        end
      end

      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        def find_material(slug:) = (Entities::Catalog::Material.new(id: 5, slug: "svt", name: "SVT", shortname: "SVT", category: "science") if slug == "svt")
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
        @schools = FakeSchools.new(
          SchoolEntity.new(id: 31, public_id: "sch-lca", status: "active", national_code: "012345"),
          SchoolEntity.new(id: 32, public_id: "sch-closed", status: "inactive", national_code: "999999"),
          SchoolEntity.new(id: 33, public_id: "sch-draft", status: "draft", national_code: "888888")
        )
      end

      def register(actor: nil, taken: [], pending: {}, refuse: false, decided: false, **attributes)
        dto = Dtos::Identity::PendingTeacherRegistrationInput.new(
          last_name: "Koné", first_name: "Awa", gender: "female", contact: "0501020304", pin: "4821", pin_confirmation: "4821",
          material_slug: "svt", **attributes
        )
        RegisterPendingTeacher.new(
          registrations: FakeRegistrations.new(@journal, taken:), schools: @schools, join_requests: FakeJoinRequests.new(@journal, pending:, refuse:, decided:),
          taxonomy: FakeTaxonomy.new, sessions: FakeSessions.new(@journal), policy: Policies::Identity::RegisterTeacherPolicy.new,
          transaction: @transaction, digest_key: KEY, clock: Clock.new(NOW)
        ).call(actor:, dto:, ip: "1.2.3.4", user_agent: "Chrome")
      end

      test "ADR-0073: by the national code, an account, a request approved at once with no decider, a session — in one transaction" do
        result = register(national_code: "012 345")

        assert result.success?
        token = result.value.token
        assert_equal [ [ :user, "0501020304", "teacher", 5, "4821" ], [ :join_request, 41, 31, NOW ], [ :approved, 5, nil, "auto", NOW ],
                       [ :session, 41, Entities::Identity::SecretDigest.hmac(token, key: KEY), "1.2.3.4", "Chrome", NOW ] ], @journal
        assert_equal 1, @transaction.calls
      end

      test "ADR-0073: an approval refused by the base rolls the whole registration back" do
        result = register(national_code: "012345", decided: true)

        assert_equal [ :conflict, { base: [ :already_decided ] } ], [ result.code, result.errors ]
        assert_empty @journal
      end

      test "CP-11: by the school chosen in its DRENA" do
        assert register(school_public_id: "sch-lca", drena_public_id: "drn-1").success?
        assert_includes @journal, [ :join_request, 41, 31, NOW ]
        assert_includes @journal, [ :approved, 5, nil, "auto", NOW ]
      end

      test "unknown national code, inactive or draft school: the same error on the field, nothing is written" do
        %w[000000 999999 888888].each do |national_code|
          result = register(national_code:)

          assert_equal [ :invalid, { national_code: [ :inclusion ] } ], [ result.code, result.errors ], national_code
        end
        assert_equal [ :invalid, { school_public_id: [ :inclusion ] } ], register(school_public_id: "sch-draft").then { [ it.code, it.errors ] }
        assert_empty @journal
      end

      test "an unknown subject is an error on the subject" do
        result = register(national_code: "012345", material_slug: "latin")

        assert_equal [ :invalid, { material_slug: [ :inclusion ] } ], [ result.code, result.errors ]
      end

      test "M4: the national code is judged only once the rest of the form is valid — no oracle through another error" do
        assert_equal({ material_slug: [ :inclusion ] }, register(national_code: "000000", material_slug: "latin").errors)
        assert_equal [ :pin_confirmation ], register(national_code: "000000", pin_confirmation: "1357").errors.keys
        assert_equal({ national_code: [ :inclusion ] }, register(national_code: "000000").errors)
      end

      test "CP-14, B2: a school that already has 5 pending requests refuses a sixth, under the lock; the account is rolled back" do
        result = register(national_code: "012345", pending: { 31 => 5 })

        assert_equal [ :invalid, { base: [ :too_many_pending ] } ], [ result.code, result.errors ]
        assert_empty @journal
        assert_equal 1, @transaction.calls
        assert register(national_code: "012345", pending: { 31 => 4 }).success?
      end

      test "B2: the cap handed to the repository is the one of the domain" do
        assert_equal 5, Entities::School::JoinRequest::MAX_PENDING_PER_SCHOOL
      end

      test "a signed-in person, a malformed form: refused before any write" do
        assert_equal :forbidden, register(actor: Entities::Identity::Actor.new(user_id: 1, role: :teacher, school_id: 31)).code
        assert_equal :invalid, register.code
        assert_empty @journal
      end

      test "a number already taken, or a request refused by the base: :conflict, and no account is left" do
        assert_equal [ :conflict, { contact: [ :taken ] } ], register(national_code: "012345", taken: [ "0501020304" ]).then { [ it.code, it.errors ] }
        assert_equal :conflict, register(national_code: "012345", refuse: true).code
        assert_empty @journal
      end
    end
  end
end
