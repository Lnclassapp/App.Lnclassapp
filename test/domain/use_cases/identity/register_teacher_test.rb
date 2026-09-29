require "test_helper"

module UseCases
  module Identity
    class RegisterTeacherTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      KEY = "k" * 32
      Clock = Data.define(:now)
      SchoolEntity = Entities::School::School

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

      class FakeRegistrations
        include Ports::Identity::RegistrationRepositoryPort

        attr_reader :received

        def initialize(journal, taken: [])
          @journal = journal
          @taken = taken
        end

        def create_teacher(user:, pin:, material_id:)
          @received = { user:, pin:, material_id: }
          return Shared::Result.failure(:conflict, errors: { contact: [ :taken ] }) if @taken.include?(user.contact)

          @journal << [ :user, user.contact, user.role, material_id ]
          Shared::Result.success(Entities::Identity::User.new(id: 41, public_id: "usr-41", last_name: user.last_name,
                                                              first_name: user.first_name, contact: user.contact,
                                                              gender: user.gender, role: "teacher"))
        end
      end

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        def initialize(journal, *schools, refuse_attach: false)
          @journal = journal
          @schools = schools
          @refuse_attach = refuse_attach
        end

        def find_by_school_code(school_code:) = @schools.find { it.school_code == school_code }

        def attach_teacher(teacher_id:, school_id:, primary:, at:)
          return Shared::Result.failure(:conflict) if @refuse_attach

          @journal << [ :teacher_school, teacher_id, school_id, primary, at ]
          Shared::Result.success
        end
      end

      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        def initialize(*materials) = @materials = materials
        def find_material(slug:) = @materials.find { it.slug == slug }
      end

      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        def initialize(journal) = @journal = journal

        def create(user_id:, token_digest:, ip:, user_agent:, at:)
          @journal << [ :session, user_id, token_digest, ip, user_agent, at ]
          9
        end
      end

      # Referrers by token (ADR-0063) : the teacher 7 teaches in the school 31 (active), the teacher 8 in the school 32.
      class FakeReferrals
        include Ports::Identity::ReferralRepositoryPort

        REFERRERS = {
          "0a1b2c3d4e5f" => Ports::Identity::ReferralRepositoryPort::Referrer.new(user_id: 7, school_id: 31, school_active: true),
          "aaaaaaaaaaaa" => Ports::Identity::ReferralRepositoryPort::Referrer.new(user_id: 8, school_id: 32, school_active: false),
          "bbbbbbbbbbbb" => Ports::Identity::ReferralRepositoryPort::Referrer.new(user_id: 9, school_id: 31, school_active: false)
        }.freeze

        attr_reader :lookups

        def initialize(journal, refuse: false)
          @journal = journal
          @refuse = refuse
          @lookups = []
        end

        def find_referrer(token:)
          @lookups << token
          REFERRERS[token]
        end

        def record_referral(referrer_id:, referee_id:, school_id:, source:, at:)
          return Shared::Result.failure(:conflict) if @refuse

          @journal << [ :referral, referrer_id, referee_id, school_id, source, at ]
          Shared::Result.success
        end
      end

      setup do
        @journal = []
        @transaction = JournalTransaction.new(@journal)
        @schools_list = [
          SchoolEntity.new(id: 31, public_id: "sch-lca", drena_id: 1, name: "Lycée Classique d'Abidjan", school_type: "public",
                           cycle: "both", status: "active", school_code: "k7m4qz"),
          SchoolEntity.new(id: 32, public_id: "sch-closed", drena_id: 1, name: "Lycée fermé", school_type: "public",
                           cycle: "both", status: "inactive", school_code: "abc234"),
          SchoolEntity.new(id: 33, public_id: "sch-draft", drena_id: 2, name: "Lycée en brouillon", school_type: "public",
                           cycle: "both", status: "draft", school_code: "xyz789")
        ]
        @taxonomy = FakeTaxonomy.new(Entities::Catalog::Material.new(id: 5, slug: "svt", name: "SVT", shortname: "SVT",
                                                                     category: "science"))
      end

      def register(actor: nil, taken: [], refuse_attach: false, refuse_referral: false, **attributes)
        @registrations = FakeRegistrations.new(@journal, taken:)
        @referrals = FakeReferrals.new(@journal, refuse: refuse_referral)
        dto = Dtos::Identity::TeacherRegistrationInput.new(
          last_name: "Koné", first_name: "Awa", gender: "female", contact: "05 01 02 03 04", pin: "4821",
          pin_confirmation: "4821", school_code: "K7M-4QZ", material_slug: "svt", **attributes
        )
        RegisterTeacher.new(
          registrations: @registrations, schools: FakeSchools.new(@journal, *@schools_list, refuse_attach:), taxonomy: @taxonomy, sessions: FakeSessions.new(@journal), referrals: @referrals, policy: Policies::Identity::RegisterTeacherPolicy.new,
          transaction: @transaction, digest_key: KEY, clock: Clock.new(NOW)
        ).call(actor:, dto:, ip: "1.2.3.4", user_agent: "Chrome")
      end

      test "crée l'enseignant avec sa matière, le rattache à son école principale et ouvre sa session" do
        result = register

        assert result.success?
        assert_equal [ 41, "0501020304", "teacher" ], [ result.value.user.id, result.value.user.contact, result.value.user.role ]
        token = result.value.token
        assert_operator token.length, :>=, 43
        assert_equal [ [ :user, "0501020304", "teacher", 5 ],
                       [ :teacher_school, 41, 31, true, NOW ],
                       [ :session, 41, Entities::Identity::SecretDigest.hmac(token, key: KEY), "1.2.3.4", "Chrome", NOW ] ],
                     @journal
        assert_equal [ "Koné", "Awa", "female", "4821" ],
                     [ @registrations.received[:user].last_name, @registrations.received[:user].first_name,
                       @registrations.received[:user].gender, @registrations.received[:pin] ]
        assert_equal 1, @transaction.calls
      end

      test "CP-01: sans jeton, aucun parrain n'est cherché" do
        register

        assert_empty @referrals.lookups
        assert_not(@journal.any? { it.first == :referral })
      end

      test "CP-02: le parrain d'un lien valide est enregistré après le rattachement, dans la transaction" do
        result = register(ref: " 0A1B2C3D4E5F ")

        assert result.success?
        assert_equal [ :teacher_school, 41, 31, true, NOW ], @journal[1]
        assert_equal [ :referral, 7, 41, 31, "link", NOW ], @journal[2]
        assert_equal 1, @transaction.calls
      end

      test "CP-03: jeton inconnu, d'un autre établissement ou d'un établissement inactif : inscrit, sans parrain" do
        %w[cccccccccccc aaaaaaaaaaaa bbbbbbbbbbbb].each do |ref|
          @journal.clear

          assert register(ref:).success?, ref
          assert_not(@journal.any? { it.first == :referral }, ref)
        end
      end

      test "CP-03: un jeton mal formé n'est même pas cherché" do
        assert register(ref: "usr-41").success?
        assert_empty @referrals.lookups
      end

      test "CP-03: un parrainage refusé par la base n'empêche pas l'inscription" do
        result = register(ref: "0a1b2c3d4e5f", refuse_referral: true)

        assert result.success?
        assert_includes @journal, [ :teacher_school, 41, 31, true, NOW ]
      end

      test "le rôle est imposé à teacher : l'entité transmise ne porte jamais un autre rôle" do
        register

        assert_equal "teacher", @registrations.received[:user].role
        assert_nil @registrations.received[:user].team_role
      end

      test "une personne déjà connectée est refusée avant toute lecture" do
        result = register(actor: Entities::Identity::Actor.new(user_id: 3, role: :team, team_role: "admin"))

        assert_equal :forbidden, result.code
        assert_nil @registrations.received
        assert_empty @journal
        assert_equal 0, @transaction.calls
      end

      test "une saisie invalide : :invalid avec les erreurs du formulaire, rien n'est écrit" do
        result = register(pin_confirmation: "1357", contact: "")

        assert_equal :invalid, result.code
        assert_equal %i[pin_confirmation contact], result.errors.keys
        assert_empty @journal
      end

      test "CE-01: l'établissement est celui du code, saisi n'importe comment (ADR-0057)" do
        result = register(school_code: " k7m 4qz ")

        assert result.success?
        assert_includes @journal, [ :teacher_school, 41, 31, true, NOW ]
      end

      test "CE-03: code inconnu, établissement désactivé ou en brouillon : la même erreur sur le code, aucun compte" do
        %w[zzz999 abc234 xyz789].each do |school_code|
          result = register(school_code:)

          assert_equal [ :invalid, { school_code: [ :inclusion ] } ], [ result.code, result.errors ], school_code
        end
        assert_empty @journal
        assert_equal 0, @transaction.calls
      end

      test "CE-04: un code au mauvais format est refusé par le formulaire, avant toute recherche" do
        result = register(school_code: "KFM37")

        assert_equal [ :invalid, [ :school_code ] ], [ result.code, result.errors.keys ]
        assert_empty @journal
      end

      test "un code inconnu et une matière inconnue : :invalid sur chacun" do
        result = register(school_code: "zzz999", material_slug: "latin")

        assert_equal [ :invalid, { school_code: [ :inclusion ], material_slug: [ :inclusion ] } ], [ result.code, result.errors ]
        assert_empty @journal
      end

      test "un numéro déjà pris : :conflict sur le numéro, aucune ligne" do
        result = register(taken: [ "0501020304" ])

        assert_equal [ :conflict, { contact: [ :taken ] } ], [ result.code, result.errors ]
        assert_empty @journal
      end

      test "atomicité : si le rattachement à l'école échoue, le compte créé est annulé avec lui" do
        result = register(refuse_attach: true)

        assert_equal :conflict, result.code
        assert_empty @journal, "aucun compte sans son école principale"
        assert_equal 1, @transaction.calls
      end
    end
  end
end
