require "test_helper"

module UseCases
  module Catalog
    class UpdateEssentialTest < ActiveSupport::TestCase
      Essential = Entities::Catalog::Essential

      # Comme le repository : la mise à jour reprend nom, sous-titre et contenu, jamais le cours, le slug ni le statut.
      class FakeEssentials
        include Ports::Catalog::EssentialRepositoryPort

        attr_reader :stored, :updates

        def initialize(*essentials)
          @stored = essentials
          @updates = 0
        end

        def find_by_slug(slug:) = @stored.find { it.slug == slug }

        def update(essential:)
          @updates += 1
          current = @stored.find { it.id == essential.id }
          if @stored.any? { it.id != current.id && it.course_id == current.course_id && it.name == essential.name }
            return Shared::Result.failure(:conflict, errors: { name: [ :taken ] })
          end

          current.name = essential.name
          current.subtitle = essential.subtitle
          current.content = essential.content
          Shared::Result.success(current)
        end
      end

      setup do
        @essentials = FakeEssentials.new(
          Essential.new(id: 10, slug: "genetique-la-meiose", course_id: 1, name: "La méiose", subtitle: "Deux divisions",
                        content: "<div>Ancien</div>", position: 2, author_id: 3, status: "published", course_status: "published"),
          Essential.new(id: 11, slug: "genetique-la-mitose", course_id: 1, name: "La mitose", position: 3, status: "draft")
        )
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def update(actor: @team, slug: "genetique-la-meiose", **attributes)
        dto = Dtos::Catalog::EssentialInput.new(name: "La Méiose", subtitle: "", content: "<div><em>Nouveau</em></div>", **attributes)
        UpdateEssential.new(essentials: @essentials, transaction: @transaction, policy: Policies::Catalog::ManageContentPolicy.new)
                       .call(actor:, slug:, dto:)
      end

      test "modifie le nom, le sous-titre et le contenu ; le cours, le slug, la position et le statut restent" do
        result = update

        assert result.success?
        essential = @essentials.find_by_slug(slug: "genetique-la-meiose")
        assert_equal [ "La Méiose", nil, "<div><em>Nouveau</em></div>" ], [ essential.name, essential.subtitle, essential.content ]
        assert_equal [ 10, 1, 2, 3, "published" ],
                     [ essential.id, essential.course_id, essential.position, essential.author_id, essential.status ]
        assert_equal 1, @transaction.calls
      end

      test "le repository reçoit la fiche enregistrée, jamais un cours ou un statut venus de la saisie" do
        sent = nil
        @essentials.define_singleton_method(:update) { |essential:| (sent = essential) && Shared::Result.success(essential) }

        update(course_slug: "autre-cours")

        assert_equal [ 10, "genetique-la-meiose", 1, 2, 3, "published", "published" ],
                     [ sent.id, sent.slug, sent.course_id, sent.position, sent.author_id, sent.status, sent.course_status ]
      end

      test "hors équipe, rien ne change, même pour une fiche inconnue" do
        teacher = Entities::Identity::Actor.new(user_id: 8, role: :teacher, school_id: 3)

        assert_equal :forbidden, update(actor: teacher).code
        assert_equal :forbidden, update(actor: nil, slug: "inconnue").code
        assert_equal 0, @essentials.updates
      end

      test "une fiche inconnue est introuvable" do
        assert_equal :not_found, update(slug: "inconnue").code
        assert_equal 0, @transaction.calls
      end

      test "une saisie invalide est refusée sans rien écrire" do
        result = update(name: " ")

        assert_equal [ :invalid, [ :name ] ], [ result.code, result.errors.keys ]
        assert_equal "La méiose", @essentials.find_by_slug(slug: "genetique-la-meiose").name
        assert_equal 0, @essentials.updates
      end

      test "le nom d'une autre fiche du même cours est refusé" do
        result = update(name: "La mitose")

        assert_equal [ :conflict, { name: [ :taken ] } ], [ result.code, result.errors ]
      end
    end
  end
end
