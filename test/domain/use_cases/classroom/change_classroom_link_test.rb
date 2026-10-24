require "test_helper"

module UseCases
  module Classroom
    # IL-11 (ADR-0085 §4.1) : changer le lien tire un nouveau jeton sous le verrou de la classe ; l'ancien est invalide
    # aussitôt. Un seul lien par classe : le jeton est celui de la classe, pas celui de l'acteur.
    # CA-B6 (ADR code-de-classe-a-six-caracteres §4.3) : le code change avec le lien, d'un seul geste, journalisé sans secret.
    # IL-12 : ManageClassroomMembersPolicy décide, une fois la classe lue sous verrou.
    class ChangeClassroomLinkTest < ActiveSupport::TestCase
      class FakeClassrooms
        include Ports::Classroom::ClassroomRepositoryPort

        attr_reader :locked, :rotated

        def initialize(*classrooms, transaction:)
          @classrooms = classrooms.index_by(&:public_id)
          @transaction = transaction
          @locked = []
          @rotated = []
        end

        # Le verrou n'a de sens que dans la transaction du use case : on retient le nombre de transactions ouvertes.
        def lock_by_public_id(public_id:)
          @locked << [ public_id, @transaction.calls ]
          @classrooms[public_id]&.dup
        end

        # Le lien et le code se changent ensemble, dans le même appel : le faux n'offre pas d'autre geste.
        def regenerate_link_and_code(id:)
          classroom = @classrooms.values.find { it.id == id }
          classroom.link_token = "#{classroom.link_token.reverse[0, 6]}#{format('%06x', @rotated.size + 1)}"
          classroom.join_code = "k7m4q#{@rotated.size + 3}"
          @rotated << id
          Ports::Classroom::ClassroomRepositoryPort::LinkAndCode.new(link_token: classroom.link_token, join_code: classroom.join_code)
        end

        def link_token_of(public_id) = @classrooms.fetch(public_id).link_token
        def join_code_of(public_id) = @classrooms.fetch(public_id).join_code
      end

      class FakeAuditLog
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def initialize = @events = []

        def record(action:, actor_id:, at:, subject_type: nil, subject_id: nil, metadata: {}, ip: nil)
          @events << { action:, actor_id:, at:, subject_type:, subject_id:, metadata: }
          true
        end
      end

      NOW = Time.utc(2026, 10, 24, 9)
      Clock = Data.define(:now)

      setup do
        @transaction = FakeTransaction.new
        @classroom = Entities::Classroom::Classroom.new(id: 11, public_id: "cls-3e2", school_id: 7, name: "3e 2",
                                                        link_token: "a1b2c3d4e5f6", join_code: "abcdef",
                                                        teacher_ids: [ 1, 2 ])
        @classrooms = FakeClassrooms.new(@classroom, transaction: @transaction)
        @audit_log = FakeAuditLog.new
      end

      def actor(role, user_id: 1, school_id: nil) = Entities::Identity::Actor.new(user_id:, role:, school_id:)

      def change(actor, public_id: "cls-3e2")
        ChangeClassroomLink.new(classrooms: @classrooms, audit_log: @audit_log, policy: Policies::Classroom::ManageClassroomMembersPolicy.new,
                                transaction: @transaction, clock: Clock.new(NOW)).call(actor:, public_id:)
      end

      test "IL-11 : l'enseignant de la classe change le lien ; la classe rendue porte le nouveau jeton, l'ancien est remplacé" do
        result = change(actor(:teacher, school_id: 7))

        assert result.success?
        assert_equal "cls-3e2", result.value.public_id
        assert_equal "3e 2", result.value.name
        assert_not_equal "a1b2c3d4e5f6", result.value.link_token
        assert_equal result.value.link_token, @classrooms.link_token_of("cls-3e2")
        assert_equal [ 11 ], @classrooms.rotated
      end

      test "CA-B6 : le code change avec le lien, d'un seul geste ; la classe rendue porte les deux nouvelles valeurs" do
        result = change(actor(:teacher, school_id: 7))

        assert_not_equal "abcdef", result.value.join_code
        assert_equal result.value.join_code, @classrooms.join_code_of("cls-3e2")
        assert Entities::Classroom::JoinCode.valid?(result.value.join_code)
      end

      test "CA-B6 : l'action est journalisée (qui, quelle classe, quand), sans le jeton ni le code" do
        change(actor(:teacher, user_id: 1, school_id: 7))

        event = @audit_log.events.sole
        assert_equal [ "school.changed", 1, NOW, "School", 7 ], event.values_at(:action, :actor_id, :at, :subject_type, :subject_id)
        assert_equal({ change: "classroom_link_and_code_changed", classroom_public_id: "cls-3e2" }, event[:metadata])
        assert_no_match(/a1b2c3d4e5f6|abcdef|#{@classroom.link_token}|#{@classroom.join_code}/, event.to_s)
      end

      test "CA-B6 : un refus ne journalise rien" do
        change(actor(:teacher, user_id: 3))
        change(actor(:student, user_id: 40))
        change(actor(:team), public_id: "inconnue")

        assert_empty @audit_log.events
      end

      test "IL-11 : la classe est lue sous verrou, dans la transaction" do
        change(actor(:teacher, school_id: 7))

        assert_equal [ [ "cls-3e2", 1 ] ], @classrooms.locked
        assert_equal 1, @transaction.calls
      end

      test "IL-11 : un second enseignant de la classe change le même lien, celui de la classe" do
        first = change(actor(:teacher, school_id: 7)).value.link_token
        second = change(actor(:teacher, user_id: 2, school_id: 7)).value.link_token

        assert_not_equal first, second
        assert_equal second, @classrooms.link_token_of("cls-3e2")
        assert_equal [ 11, 11 ], @classrooms.rotated
      end

      test "IL-12 : la direction de l'établissement de la classe et l'équipe changent le lien" do
        assert change(actor(:school_admin, user_id: 5, school_id: 7)).success?
        assert change(actor(:team, user_id: 9)).success?
        assert_equal [ 11, 11 ], @classrooms.rotated
      end

      test "IL-12 : un enseignant qui n'enseigne pas dans la classe reçoit :not_found, le jeton ne change pas" do
        result = change(actor(:teacher, user_id: 3))

        assert_equal :not_found, result.code
        assert_equal "a1b2c3d4e5f6", @classrooms.link_token_of("cls-3e2")
        assert_empty @classrooms.rotated
      end

      test "IL-12 : la direction d'un autre établissement reçoit :not_found" do
        assert_equal :not_found, change(actor(:school_admin, user_id: 5, school_id: 8)).code
        assert_empty @classrooms.rotated
      end

      test "IL-12 : un élève reçoit :forbidden" do
        assert_equal :forbidden, change(actor(:student, user_id: 40)).code
        assert_empty @classrooms.rotated
      end

      test "une classe inconnue : :not_found" do
        assert_equal :not_found, change(actor(:team), public_id: "inconnue").code
        assert_empty @classrooms.rotated
      end

      # UDR-0081 §3.6 : le bloc n'est rendu que sur une classe active ; le lien d'une classe archivée ne sert déjà plus.
      test "une classe archivée garde son jeton : :forbidden, raison classroom_archived" do
        @classroom.status = "archived"

        result = change(actor(:teacher, school_id: 7))

        assert_equal :forbidden, result.code
        assert_equal({ base: [ :classroom_archived ] }, result.errors)
        assert_empty @classrooms.rotated
      end
    end
  end
end
