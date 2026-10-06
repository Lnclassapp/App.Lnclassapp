require "test_helper"

# ADR-0081 §4.3, AV-10 : l'équipe retire une illustration. Elle sort du choix des auteurs, mais n'est jamais supprimée :
# les annonces qui la portent la gardent jusqu'à leur fin. Un second retrait garde la première date. Les 8 de base
# n'ont pas de public_id : elles ne se retirent pas.
module UseCases
  module Communication
    class RetireIllustrationTest < ActiveSupport::TestCase
      Illustration = Entities::Communication::Illustration
      NOW = Time.utc(2026, 10, 6, 10)
      FIRST = Time.utc(2026, 10, 5, 9)
      Clock = Data.define(:now)

      # Comme l'adaptateur : seule une illustration encore offerte prend la date.
      class FakeIllustrations
        include Ports::Communication::IllustrationRepositoryPort

        attr_reader :retirements

        def initialize(illustrations)
          @illustrations = illustrations
          @retirements = []
        end

        def find_by_public_id(public_id:) = @illustrations.find { it.public_id == public_id }

        def retire(id:, at:)
          @retirements << [ id, at ]
          index = @illustrations.index { it.id == id }
          @illustrations[index] = @illustrations[index].then { it.retired? ? it : it.with(retired_at: at) }
        end
      end

      setup do
        @illustrations = FakeIllustrations.new([
          Illustration.new(id: 1, public_id: "ill00000000001", name: "Bus scolaire", view_box: "0 0 64 64", shapes: [], created_by_id: 7),
          Illustration.new(id: 2, public_id: "ill00000000002", name: "Cantine", view_box: "0 0 64 64", shapes: [], created_by_id: 7,
                           retired_at: FIRST)
        ])
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 9, role: :team, team_role: "admin")
      end

      def retire(public_id, actor: @team)
        RetireIllustration.new(illustrations: @illustrations, transaction: @transaction,
                               policy: Policies::Communication::ManageIllustrationsPolicy.new, clock: Clock.new(NOW))
                          .call(actor:, public_id:)
      end

      test "AV-10 — l'équipe retire « Bus scolaire » : retirée maintenant, dans une transaction, et relue" do
        result = retire("ill00000000001")

        assert result.success?
        assert_equal [ [ 1, NOW ] ], @illustrations.retirements
        assert_equal [ "ill00000000001", NOW ], [ result.value.public_id, result.value.retired_at ]
        assert result.value.retired?
        assert_equal 1, @transaction.calls
      end

      test "AV-10 — retirer de nouveau une illustration retirée garde sa première date" do
        assert_equal FIRST, retire("ill00000000002").value.retired_at
      end

      test "AV-11 — un enseignant, une direction, un élève ou un visiteur reçoit :forbidden ; rien n'est retiré" do
        [ :teacher, :school_admin, :student ].map { Entities::Identity::Actor.new(user_id: 3, role: it) }.push(nil).each do |someone|
          assert_equal :forbidden, retire("ill00000000001", actor: someone).code, someone.inspect
        end
        assert_empty @illustrations.retirements
        assert_equal 0, @transaction.calls
      end

      test "AV-10 — une illustration de base ou inconnue ne se retire pas : :not_found" do
        [ "info", "holidays", "inconnue" ].each { assert_equal :not_found, retire(it).code, it }
        assert_empty @illustrations.retirements
      end
    end
  end
end
