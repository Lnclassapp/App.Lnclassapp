require "test_helper"

# ADR-0081 §4.3, UDR-0075 §3.5 : l'équipe renomme une illustration de la bibliothèque. Seul le nom change ; le dessin
# reste celui de l'ajout. Les 8 de base n'ont pas de public_id : elles ne se renomment pas (AV-10).
module UseCases
  module Communication
    class RenameIllustrationTest < ActiveSupport::TestCase
      Illustration = Entities::Communication::Illustration
      Input = Dtos::Communication::IllustrationInput
      RETIRED_AT = Time.utc(2026, 10, 5, 9)

      class FakeIllustrations
        include Ports::Communication::IllustrationRepositoryPort

        attr_reader :renames

        def initialize(illustrations)
          @illustrations = illustrations
          @renames = []
        end

        def find_by_public_id(public_id:) = @illustrations.find { it.public_id == public_id }

        def rename(id:, name:)
          @renames << [ id, name ]
          index = @illustrations.index { it.id == id }
          @illustrations[index] = @illustrations[index].with(name:)
        end
      end

      setup do
        @illustrations = FakeIllustrations.new([
          Illustration.new(id: 1, public_id: "ill00000000001", name: "Bus scolaire", view_box: "0 0 64 64", shapes: [], created_by_id: 7),
          Illustration.new(id: 2, public_id: "ill00000000002", name: "Cantine", view_box: "0 0 64 64", shapes: [], created_by_id: 7,
                           retired_at: RETIRED_AT)
        ])
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 9, role: :team, team_role: "field")
      end

      def rename(public_id, name, actor: @team)
        RenameIllustration.new(illustrations: @illustrations, transaction: @transaction,
                               policy: Policies::Communication::ManageIllustrationsPolicy.new)
                          .call(actor:, public_id:, dto: Input.new(name:))
      end

      test "l'équipe renomme « Bus scolaire » : seul le nom change, dans une transaction, et l'illustration est relue" do
        result = rename("ill00000000001", "  Car   scolaire ")

        assert result.success?
        assert_equal [ [ 1, "Car scolaire" ] ], @illustrations.renames
        assert_equal [ "ill00000000001", "Car scolaire", "0 0 64 64" ], [ result.value.public_id, result.value.name, result.value.view_box ]
        assert_equal 1, @transaction.calls
      end

      test "le renommage n'exige pas de fichier ; une illustration retirée garde son nom modifiable" do
        result = rename("ill00000000002", "Cantine scolaire")

        assert_equal [ "Cantine scolaire", RETIRED_AT ], [ result.value.name, result.value.retired_at ]
      end

      test "AV-11 — un enseignant, une direction, un élève ou un visiteur reçoit :forbidden ; rien n'est renommé" do
        [ :teacher, :school_admin, :student ].map { Entities::Identity::Actor.new(user_id: 3, role: it) }.push(nil).each do |someone|
          assert_equal :forbidden, rename("ill00000000001", "Car", actor: someone).code, someone.inspect
        end
        assert_empty @illustrations.renames
        assert_equal 0, @transaction.calls
      end

      test "AV-10 — une illustration de base ou inconnue n'existe pas pour le renommage : :not_found" do
        [ "info", "inconnue", "" ].each { assert_equal :not_found, rename(it, "Car").code, it }
        assert_empty @illustrations.renames
      end

      test "un nom vide ou trop long est refusé sous « Nom » ; rien n'est renommé" do
        assert_equal({ name: [ "Saisissez un nom." ] }, rename("ill00000000001", " ").errors)
        assert_equal({ name: [ "Le nom compte 30 caractères au plus." ] }, rename("ill00000000001", "C" * 31).errors)
        assert_equal :invalid, rename("ill00000000001", nil).code
        assert_empty @illustrations.renames
        assert_equal 0, @transaction.calls
      end
    end
  end
end
