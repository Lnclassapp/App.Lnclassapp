require "test_helper"

module UseCases
  module Identity
    # IE-01, IE-03 to IE-06, IE-08 to IE-13 (ADR-0082, UDR-0078): one use case, two ways in. The school is chosen in its
    # DRENA, or given by an invite link /i/<token> (a colleague, the direction, the team), resolved again on submit. The
    # teacher is attached at once, without any join request, and the way in is recorded (teacher_profiles.joined_via).
    class RegisterTeacherTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 7, 12)
      KEY = "k" * 32
      Clock = Data.define(:now)
      SchoolEntity = Entities::School::School
      InviteLink = Ports::Identity::InviteLinkRepositoryPort::InviteLink
      ERRORS = "activemodel.errors.models.dtos/identity/teacher_registration_input.attributes".freeze

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

        def create_teacher(user:, pin:, material_id:, joined_via:)
          @received = { user:, pin:, material_id:, joined_via: }
          return Shared::Result.failure(:conflict, errors: { contact: [ :taken ] }) if @taken.include?(user.contact)

          @journal << [ :user, user.contact, user.role, material_id, joined_via ]
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

        def find_by_public_id(public_id:) = @schools.find { it.public_id == public_id }

        def attach_teacher(teacher_id:, school_id:, primary:, at:)
          return Shared::Result.failure(:conflict) if @refuse_attach

          @journal << [ :teacher_school, teacher_id, school_id, primary, at ]
          Shared::Result.success
        end
      end

      class FakeDrenas
        include Ports::School::DrenaRepositoryPort

        DRENAS = [ Entities::School::Drena.new(id: 1, public_id: "drn-abj1", name: "Abidjan 1"),
                   Entities::School::Drena.new(id: 2, public_id: "drn-abj2", name: "Abidjan 2") ].freeze

        def find_by_public_id(public_id:) = DRENAS.find { it.public_id == public_id }
      end

      # The colleague 7 teaches at 31 (active), 8 at 32 (inactive), 9 has no school any more. The school 31 has its
      # direction and team tokens, the school 32 (inactive) its team token.
      class FakeInviteLinks
        include Ports::Identity::InviteLinkRepositoryPort

        LINKS = {
          "0a1b2c3d4e5f" => InviteLink.new(school_id: 31, school_active: true, channel: "colleague", referrer_id: 7),
          "aaaaaaaaaaaa" => InviteLink.new(school_id: 32, school_active: false, channel: "colleague", referrer_id: 8),
          "bbbbbbbbbbbb" => InviteLink.new(school_id: nil, school_active: false, channel: "colleague", referrer_id: 9),
          "dddddddddddd" => InviteLink.new(school_id: 31, school_active: true, channel: "direction", referrer_id: nil),
          "eeeeeeeeeeee" => InviteLink.new(school_id: 31, school_active: true, channel: "team", referrer_id: nil),
          "ffffffffffff" => InviteLink.new(school_id: 32, school_active: false, channel: "team", referrer_id: nil)
        }.freeze

        attr_reader :lookups

        def initialize = @lookups = []

        def resolve(token:)
          @lookups << token
          LINKS[token]
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

      # Only record_referral is called: the referrer now comes from the invite link.
      class FakeReferrals
        include Ports::Identity::ReferralRepositoryPort

        def initialize(journal, refuse: false)
          @journal = journal
          @refuse = refuse
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
          SchoolEntity.new(id: 31, public_id: "sch-lmc", drena_id: 1, name: "Lycée Moderne de Cocody", school_type: "public",
                           cycle: "both", status: "active"),
          SchoolEntity.new(id: 32, public_id: "sch-closed", drena_id: 1, name: "Lycée fermé", school_type: "public",
                           cycle: "both", status: "inactive"),
          SchoolEntity.new(id: 33, public_id: "sch-draft", drena_id: 1, name: "Lycée en brouillon", school_type: "public",
                           cycle: "both", status: "draft"),
          SchoolEntity.new(id: 34, public_id: "sch-other", drena_id: 2, name: "Lycée d'Abidjan 2", school_type: "public",
                           cycle: "both", status: "active")
        ]
        @taxonomy = FakeTaxonomy.new(Entities::Catalog::Material.new(id: 5, slug: "svt", name: "SVT", shortname: "SVT",
                                                                     category: "science"))
      end

      def register(actor: nil, taken: [], refuse_attach: false, refuse_referral: false, **attributes)
        @registrations = FakeRegistrations.new(@journal, taken:)
        @invite_links = FakeInviteLinks.new
        dto = Dtos::Identity::TeacherRegistrationInput.new(
          full_name: "KOUASSI Aya Marie", gender: "female", contact: "05 01 02 03 04", pin: "4821", pin_confirmation: "4821",
          drena_public_id: "drn-abj1", school_public_id: "sch-lmc", material_slug: "svt", **attributes
        )
        RegisterTeacher.new(
          registrations: @registrations, schools: FakeSchools.new(@journal, *@schools_list, refuse_attach:),
          drenas: FakeDrenas.new, invite_links: @invite_links, taxonomy: @taxonomy, sessions: FakeSessions.new(@journal),
          referrals: FakeReferrals.new(@journal, refuse: refuse_referral), policy: Policies::Identity::RegisterTeacherPolicy.new,
          transaction: @transaction, digest_key: KEY, clock: Clock.new(NOW)
        ).call(actor:, dto:, ip: "1.2.3.4", user_agent: "Chrome")
      end

      def user_received = @registrations.received[:user]

      test "IE-01: by the standard way, the teacher is created, attached as primary, way « standard », signed in" do
        result = register

        assert result.success?
        assert_equal [ 41, "0501020304", "teacher" ], [ result.value.user.id, result.value.user.contact, result.value.user.role ]
        token = result.value.token
        assert_operator token.length, :>=, 43
        assert_equal [ [ :user, "0501020304", "teacher", 5, "standard" ],
                       [ :teacher_school, 41, 31, true, NOW ],
                       [ :session, 41, Entities::Identity::SecretDigest.hmac(token, key: KEY), "1.2.3.4", "Chrome", NOW ] ],
                     @journal
        assert_equal [ "KOUASSI", "Aya Marie", "female", "4821" ],
                     [ user_received.last_name, user_received.first_name, user_received.gender, @registrations.received[:pin] ]
        assert_equal 1, @transaction.calls
        assert_empty @invite_links.lookups, "sans jeton, aucun lien n'est cherché"
      end

      test "IE-01: no join request is written: the use case has no join request port at all" do
        params = RegisterTeacher.instance_method(:initialize).parameters.map(&:last)

        assert_not_includes params, :join_requests
        assert_includes params, :invite_links
      end

      test "IE-03: the full name, uncorrected, is split at the first word, case kept" do
        register(full_name: "N'GUESSAN  Konan Jean-Baptiste")

        assert_equal [ "N'GUESSAN", "Konan Jean-Baptiste" ], [ user_received.last_name, user_received.first_name ]
      end

      test "IE-04: the corrected name and first names prevail over the split" do
        register(full_name: "KONÉ OUATTARA Awa", last_name: "KONÉ OUATTARA", first_name: "Awa")

        assert_equal [ "KONÉ OUATTARA", "Awa" ], [ user_received.last_name, user_received.first_name ]
      end

      test "IE-05: a one-word full name is refused under the full name, nothing is read nor written" do
        result = register(full_name: "Kouassi")

        assert_equal [ :invalid, { full_name: [ I18n.t("#{ERRORS}.full_name.single_word") ] } ], [ result.code, result.errors ]
        assert_nil @registrations.received
        assert_empty @journal
        assert_equal 0, @transaction.calls
      end

      test "IE-06: by a colleague's link, the school of the link, way « colleague », and the referral counted" do
        result = register(invite_token: " 0A1B2C3D4E5F ", drena_public_id: nil, school_public_id: nil)

        assert result.success?
        assert_equal [ "0a1b2c3d4e5f" ], @invite_links.lookups
        assert_equal [ :user, "0501020304", "teacher", 5, "colleague" ], @journal[0]
        assert_equal [ :teacher_school, 41, 31, true, NOW ], @journal[1]
        assert_equal [ :referral, 7, 41, 31, "link", NOW ], @journal[2]
        assert_equal 1, @transaction.calls
      end

      test "IE-06: a referral refused by the base does not prevent the sign-up" do
        result = register(invite_token: "0a1b2c3d4e5f", refuse_referral: true)

        assert result.success?
        assert_includes @journal, [ :teacher_school, 41, 31, true, NOW ]
        assert_not(@journal.any? { it.first == :referral })
      end

      test "IE-07, IE-08: by the direction's or the team's link, its way, without referrer" do
        { "dddddddddddd" => "direction", "eeeeeeeeeeee" => "team" }.each do |token, channel|
          @journal.clear

          assert register(invite_token: token, drena_public_id: nil, school_public_id: nil).success?, channel
          assert_equal [ [ :user, "0501020304", "teacher", 5, channel ], [ :teacher_school, 41, 31, true, NOW ] ],
                       @journal.first(2), channel
          assert_not(@journal.any? { it.first == :referral }, channel)
        end
      end

      test "ADR-0082 §4.1: with a valid link, the school sent by the form is ignored" do
        assert register(invite_token: "eeeeeeeeeeee", drena_public_id: "drn-abj2", school_public_id: "sch-other").success?

        assert_includes @journal, [ :teacher_school, 41, 31, true, NOW ]
        assert_equal "team", @registrations.received[:joined_via]
      end

      test "IE-09: an invalid link (unknown, inactive school, colleague without school) falls back to the standard way" do
        %w[cccccccccccc aaaaaaaaaaaa bbbbbbbbbbbb ffffffffffff].each do |token|
          @journal.clear

          assert register(invite_token: token).success?, token
          assert_equal [ :user, "0501020304", "teacher", 5, "standard" ], @journal[0], token
          assert_equal [ :teacher_school, 41, 31, true, NOW ], @journal[1], token
          assert_not(@journal.any? { it.first == :referral }, token)
        end
      end

      test "IE-09: an invalid link without a chosen school is refused on the school, nothing written" do
        result = register(invite_token: "aaaaaaaaaaaa", drena_public_id: nil, school_public_id: nil)

        assert_equal [ :invalid, { drena_public_id: [ :blank ], school_public_id: [ :blank ] } ], [ result.code, result.errors ]
        assert_empty @journal
      end

      test "IE-09: a malformed token is not even looked up" do
        assert register(invite_token: "usr-41").success?
        assert_empty @invite_links.lookups
        assert_equal "standard", @registrations.received[:joined_via]
      end

      test "IE-10: without the token (« Ce n'est pas votre établissement ? »), the way is standard, no referral" do
        assert register(invite_token: "").success?

        assert_equal "standard", @registrations.received[:joined_via]
        assert_not(@journal.any? { it.first == :referral })
      end

      test "IE-11: a draft, inactive, unknown school, or one of another DRENA: the same error on the school, no account" do
        %w[sch-closed sch-draft sch-nope sch-other].each do |school_public_id|
          result = register(school_public_id:)

          assert_equal [ :invalid, { school_public_id: [ :inclusion ] } ], [ result.code, result.errors ], school_public_id
        end
        assert_empty @journal
        assert_equal 0, @transaction.calls
      end

      test "IE-11: an unknown DRENA is refused on the DRENA" do
        result = register(drena_public_id: "drn-nope")

        assert_equal [ :invalid, { drena_public_id: [ :inclusion ] } ], [ result.code, result.errors ]
        assert_empty @journal
      end

      test "IE-11: no DRENA nor school chosen: refused by the form, before any read" do
        result = register(drena_public_id: "", school_public_id: "")

        assert_equal [ :invalid, %i[drena_public_id school_public_id] ], [ result.code, result.errors.keys ]
        assert_empty @journal
      end

      test "no oracle: the school is judged only once the subject is known" do
        result = register(school_public_id: "sch-closed", material_slug: "latin")

        assert_equal [ :invalid, { material_slug: [ :inclusion ] } ], [ result.code, result.errors ]
        assert_empty @journal
      end

      test "IE-12: a number already taken: :conflict on the number, no line" do
        result = register(taken: [ "0501020304" ])

        assert_equal [ :conflict, { contact: [ :taken ] } ], [ result.code, result.errors ]
        assert_empty @journal
      end

      test "IE-13: a signed-in person is refused before any read" do
        result = register(actor: Entities::Identity::Actor.new(user_id: 3, role: :team, team_role: "admin"))

        assert_equal :forbidden, result.code
        assert_nil @registrations.received
        assert_empty @invite_links.lookups
        assert_empty @journal
        assert_equal 0, @transaction.calls
      end

      test "the role is forced to teacher: the entity never carries another role" do
        register

        assert_equal "teacher", user_received.role
        assert_nil user_received.team_role
      end

      test "an invalid entry: :invalid with the errors of the form, nothing written" do
        result = register(pin_confirmation: "1357", contact: "")

        assert_equal :invalid, result.code
        assert_equal %i[pin_confirmation contact], result.errors.keys
        assert_empty @journal
      end

      test "atomicity: if the attachment fails, the account is rolled back with it" do
        result = register(refuse_attach: true)

        assert_equal :conflict, result.code
        assert_empty @journal, "aucun compte sans son école principale"
        assert_equal 1, @transaction.calls
      end
    end
  end
end
