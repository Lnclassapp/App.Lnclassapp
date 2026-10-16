require "test_helper"

module UseCases
  module School
    # IE-18 (ADR-0083 §4.3) on GD-23, GD-26, GD-27 (ADR-0071 §4.3): a teacher without a school joins an active school
    # chosen in its DRENA; the school that detached them, an unknown school, a school not active and a school of another
    # DRENA give the very same error. ME-01 to ME-06 (ADR-0094 §4.4): a teacher of one or two schools joins one more, by
    # the DRENA or by a link /i/<jeton>, as a secondary school his session moves to; never a fourth.
    class JoinSchoolWithCodeTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 1, 9)
      Clock = Data.define(:now)
      Status = Data.define(:school_name, :status)

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        attr_reader :attached

        def initialize(*schools, refuse_attach: nil, already: [])
          @schools = schools.index_by(&:public_id)
          @refuse_attach = refuse_attach
          @already = already
          @attached = []
        end

        def find_by_public_id(public_id:) = @schools[public_id]
        def find_by_id(id:) = @schools.values.find { it.id == id }
        def school_ids_for(teacher_id:) = @already

        def attach_teacher_within_cap(teacher_id:, school_id:, primary:, cap:, at:)
          return Shared::Result.failure(:conflict, errors: { base: [ @refuse_attach ] }) if @refuse_attach

          @attached << { teacher_id:, school_id:, primary:, cap:, at: }
          Shared::Result.success
        end
      end

      class FakeInviteLinks
        include Ports::Identity::InviteLinkRepositoryPort

        def initialize(links) = @links = links
        def resolve(token:) = @links[token]
      end

      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        attr_reader :moves

        def initialize = @moves = []
        def set_current_school(id:, school_id:) = (@moves << [ id, school_id ]) && true
      end

      class FakeDrenas
        include Ports::School::DrenaRepositoryPort

        def initialize(*drenas) = @drenas = drenas.index_by(&:public_id)
        def find_by_public_id(public_id:) = @drenas[public_id]
      end

      class FakeDepartures
        include Ports::School::TeacherDepartureRepositoryPort

        def initialize(*departures) = @departures = departures

        def open_for(teacher_id:, school_id:)
          @departures.find { it.teacher_id == teacher_id && it.school_id == school_id && it.open? }
        end
      end

      # JoinRequestRepositoryPort#pending_for: the teacher's request only while it is pending, as the repository reads it.
      class FakeJoinRequests
        include Ports::School::JoinRequestRepositoryPort

        attr_reader :asked

        def initialize(status) = @status = status

        def pending_for(teacher_id:)
          @asked = teacher_id
          Status.new(school_name: "Lycée Classique", status: @status) if @status == "pending"
        end
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def initialize = @events = []
        def record(**event) = (@events << event) && true
      end

      setup do
        @abidjan = Entities::School::Drena.new(id: 1, public_id: "drena-1", name: "Abidjan 1")
        @bouake = Entities::School::Drena.new(id: 2, public_id: "drena-2", name: "Bouaké 1")
        @a = school(31, "active")
        @b = school(32, "active")
        @inactive = school(33, "inactive")
        @draft = school(34, "draft")
        @elsewhere = school(35, "active", drena_id: 2)
        @teacher = Entities::Identity::Actor.new(user_id: 50, role: :teacher)
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
      end

      def school(id, status, drena_id: 1)
        Entities::School::School.new(id:, public_id: "sch-#{id}", drena_id:, name: "Lycée #{id}", school_type: "public",
                                     cycle: "both", status:, school_code: "abc#{id}x")
      end

      def departure(school_id:, reinstated_at: nil)
        Entities::School::TeacherDeparture.new(id: school_id, teacher_id: 50, school_id:, detached_by_id: 7, detached_at: NOW - 86_400,
                                               reinstated_by_id: (7 if reinstated_at), reinstated_at:)
      end

      Link = Ports::Identity::InviteLinkRepositoryPort::InviteLink
      LINKS = {
        "aaaaaaaaaaaa" => Link.new(school_id: 32, school_active: true, channel: "direction", referrer_id: nil),
        "bbbbbbbbbbbb" => Link.new(school_id: 31, school_active: true, channel: "colleague", referrer_id: 9),
        "cccccccccccc" => Link.new(school_id: 33, school_active: false, channel: "team", referrer_id: nil),
        "dddddddddddd" => Link.new(school_id: nil, school_active: false, channel: "colleague", referrer_id: 9)
      }.freeze

      def use_case(departures:, request:, refuse_attach:, already:)
        @schools = FakeSchools.new(@a, @b, @inactive, @draft, @elsewhere, refuse_attach:, already:)
        @join_requests = FakeJoinRequests.new(request)
        @sessions = FakeSessions.new
        @materials = FakeTeacherMaterials.new
        JoinSchoolWithCode.new(schools: @schools, drenas: FakeDrenas.new(@abidjan, @bouake), departures: FakeDepartures.new(*departures),
                               join_requests: @join_requests, invite_links: FakeInviteLinks.new(LINKS), sessions: @sessions,
                               audit_log: @audit, policy: Policies::School::JoinSchoolWithCodePolicy.new,
                               transaction: @transaction, clock: Clock.new(NOW), teacher_materials: @materials)
      end

      def join(school_public_id, drena: "drena-1", actor: @teacher, departures: [ departure(school_id: 31) ], request: nil,
               refuse_attach: nil, already: [])
        use_case(departures:, request:, refuse_attach:, already:)
          .call(actor:, dto: Dtos::School::SchoolJoinInput.new(drena_public_id: drena, school_public_id:), session_id: 5)
      end

      def join_by_link(token, already: [ 34 ], departures: [], refuse_attach: nil)
        use_case(departures:, request: nil, refuse_attach:, already:)
          .call(actor: @teacher, dto: Dtos::School::SchoolInviteJoinInput.new(token:), session_id: 5)
      end

      test "IE-18 : B choisi dans sa DRENA : rattaché à B en école principale, journal school.changed teacher_joined" do
        result = join("sch-32")

        assert result.success?
        assert_equal @b, result.value
        assert_equal [ { teacher_id: 50, school_id: 32, primary: true, cap: 3, at: NOW } ], @schools.attached
        assert_equal [ { action: "school.changed", actor_id: 50, at: NOW, subject_type: "School", subject_id: 32,
                         metadata: { change: "teacher_joined", via: "standard" } } ], @audit.events
        assert_empty @sessions.moves, "le premier établissement est le principal : la session n'a rien à retenir"
      end

      test "ME-02 : un enseignant d'un établissement en ajoute un second : secondaire, et sa session y passe" do
        result = join("sch-32", already: [ 34 ])

        assert_equal @b, result.value
        assert_equal [ false ], @schools.attached.map { it[:primary] }
        assert_equal [ [ 5, 32 ] ], @sessions.moves
      end

      test "EPM-20 : l'établissement ajouté reçoit les matières de l'établissement courant (ADR-0103 §4.4)" do
        join("sch-32", actor: Entities::Identity::Actor.new(user_id: 50, role: :teacher, school_id: 34), already: [ 34 ])

        assert_equal [ [ :inherit, 50, 32, 34, NOW ] ], @materials.calls
      end

      test "EPM-20 : un rattachement refusé ne transmet aucune matière" do
        join("sch-35")

        assert_empty @materials.calls
      end

      test "ME-01 : par le lien de la direction ou d'un collègue : secondaire, la voie dans le journal" do
        assert_equal @b, join_by_link("aaaaaaaaaaaa").value
        assert_equal [ [ 32, false ] ], @schools.attached.map { it.values_at(:school_id, :primary) }
        assert_equal({ change: "teacher_joined", via: "direction" }, @audit.events.last[:metadata])
        assert_equal [ [ 5, 32 ] ], @sessions.moves

        assert_equal @a, join_by_link("bbbbbbbbbbbb").value
        assert_equal({ change: "teacher_joined", via: "colleague" }, @audit.events.last[:metadata])
      end

      test "ME-03, ME-16 : lien inconnu, d'un établissement inactif, sans établissement, ou de l'établissement qui l'a retiré : neutre" do
        [ [ "eeeeeeeeeeee", [] ], [ "cccccccccccc", [] ], [ "dddddddddddd", [] ], [ "bbbbbbbbbbbb", [ departure(school_id: 31) ] ],
          [ "pas-un-jeton", [] ] ].each do |token, departures|
          result = join_by_link(token, departures:)

          assert_equal :invalid, result.code, token
          assert_not_empty result.errors, token
        end
        assert_equal({ base: [ :invite_invalid ] }, join_by_link("eeeeeeeeeeee").errors)
        assert_empty @schools.attached
        assert_empty @audit.events
      end

      test "ME-04, ME-05 : au plafond, ou déjà dans l'établissement (sous verrou) : rien n'est écrit, la raison est dite" do
        assert_equal [ :forbidden, { base: [ :schools_limit ] } ], join("sch-32", already: [ 31, 33, 34 ]).then { [ it.code, it.errors ] }
        %i[already_attached schools_limit].each do |reason|
          result = join_by_link("aaaaaaaaaaaa", refuse_attach: reason)

          assert_equal [ :conflict, { base: [ reason ] } ], [ result.code, result.errors ]
        end
        assert_empty @audit.events
        assert_empty @sessions.moves
      end

      test "IE-18 : l'établissement qui l'a retiré, inconnu, inactif, en brouillon : la même erreur neutre" do
        [ "sch-31", "sch-99", "sch-33", "sch-34" ].each do |public_id|
          result = join(public_id)

          assert_equal :invalid, result.code, public_id
          assert_equal({ school_public_id: [ :inclusion ] }, result.errors, public_id)
          assert_empty @schools.attached
        end
        assert_empty @audit.events
      end

      test "IE-18 : un établissement d'une autre DRENA, ou une DRENA inconnue : la même erreur neutre" do
        [ [ "sch-35", "drena-1" ], [ "sch-32", "drena-2" ], [ "sch-32", "drena-inconnue" ] ].each do |public_id, drena|
          result = join(public_id, drena:)

          assert_equal :invalid, result.code, [ public_id, drena ].inspect
          assert_equal({ school_public_id: [ :inclusion ] }, result.errors)
          assert_empty @schools.attached
        end
        assert join("sch-35", drena: "drena-2").success?
      end

      test "GD-27 : réintégré puis retiré de nouveau, A est refusé ; un départ clos n'empêche pas" do
        assert_equal :invalid, join("sch-31", departures: [ departure(school_id: 31, reinstated_at: NOW - 3600),
                                                            departure(school_id: 31) ]).code
        assert join("sch-31", departures: [ departure(school_id: 31, reinstated_at: NOW - 3600) ]).success?
      end

      test "GD-26 : une demande en attente : forbidden, sans chercher l'établissement" do
        result = join("sch-32", request: "pending")

        assert_equal :forbidden, result.code
        assert_equal 50, @join_requests.asked
        assert_empty @schools.attached
      end

      test "une demande refusée ou approuvée n'empêche pas" do
        assert join("sch-32", request: "rejected").success?
        assert join("sch-32", request: "approved").success?
      end

      test "forbidden : autre rôle, visiteur" do
        assert_equal :forbidden, join("sch-32", actor: Entities::Identity::Actor.new(user_id: 8, role: :school_admin, school_id: 32)).code
        assert_equal :forbidden, join("sch-32", actor: nil).code
        assert_nil @join_requests.asked
        assert_empty @schools.attached
      end

      test "un choix manquant : invalid avec le motif du DTO" do
        result = join("")

        assert_equal :invalid, result.code
        assert_equal({ school_public_id: [ "Choisissez votre établissement." ] }, result.errors)
        assert_empty @schools.attached
      end

      test "un rattachement refusé par la base : conflict, aucun journal" do
        assert_equal :conflict, join("sch-32", refuse_attach: :already_attached).code
        assert_empty @audit.events
      end
    end
  end
end
