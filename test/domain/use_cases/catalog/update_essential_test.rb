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

      def blank_alt_message(number) = I18n.t("activemodel.errors.models.dtos/catalog/essential_input.image_alt_blank", number:)

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

      test "ADR-0105 : les textes de remplacement saisis vont au repository avec la fiche" do
        sent = nil
        @essentials.define_singleton_method(:update) { |essential:| (sent = essential) && Shared::Result.success(essential) }

        update(image_alts: { "img1" => " Une pile " })

        assert_equal [ [ "img1", "Une pile" ] ], sent.images.map { [ it.public_id, it.alt ] }
      end

      # ADR-0074 §4.2, ADR-0105 §4.4 : une fiche en ligne ne perd pas un texte de remplacement et ne reçoit pas d'emplacement.
      test "ADR-0105 : une fiche publiée dont un texte de remplacement est vidé est refusée, la saisie nomme l'image" do
        result = update(image_alts: { "img1" => "Une pile", "img2" => " " })

        assert_equal :invalid, result.code
        assert_equal [ :"image_alts.img2" ], result.errors.keys
        assert_equal blank_alt_message(2), result.errors.values.flatten.first
        assert_equal 0, @essentials.updates
      end

      test "ADR-0105 : une fiche publiée refuse un emplacement d'image, mal écrit ou illisible, sans rien écrire" do
        slot = update(content: "<p>[[image: une pile]]</p>")
        malformed = update(content: "<ul><li>[[image: une pile]]</li></ul>")
        unreadable = update(content: "<p>" * 40_000)

        assert_equal [ :invalid ] * 3, [ slot, malformed, unreadable ].map(&:code)
        messages = %i[image_slots_left image_slots_malformed image_slots_unreadable].map do
          I18n.t("activemodel.errors.models.dtos/catalog/essential_input.attributes.content.#{it}")
        end
        assert_equal messages, [ slot, malformed, unreadable ].map { it.errors.fetch(:content).first }
        assert_equal 0, @essentials.updates
      end

      # Menace n° 15 : le repository rend la fiche relue, textes de la base fusionnés avec la saisie. Une image neuve citée sans sa clé
      # y figure sans texte de remplacement ; la transaction est annulée.
      class RollbackProbe < FakeTransaction
        attr_reader :rolled_back

        def call
          super
        rescue StandardError
          @rolled_back = true
          raise
        end
      end

      def reread_with(*images)
        @essentials.define_singleton_method(:update) do |essential:|
          @updates += 1
          saved = essential.dup
          saved.images = images.map { |public_id, alt| Entities::Shared::ContentImage.new(public_id:, alt:) }
          Shared::Result.success(saved)
        end
      end

      test "menace n° 15 : une fiche publiée dont l'image neuve n'a pas de texte de remplacement une fois relue est refusée, l'écriture annulée" do
        probe = @transaction = RollbackProbe.new
        reread_with([ "img1", "Une pile" ], [ "img2", nil ])

        result = update(image_alts: { "img1" => "Une pile" })

        assert_equal [ :invalid, [ :"image_alts.img2" ] ], [ result.code, result.errors.keys ]
        assert_equal blank_alt_message(2), result.errors.values.flatten.first
        assert_equal [ 1, true ], [ @essentials.updates, probe.rolled_back ]
      end

      test "menace n° 15 : une fiche publiée dont toutes les images relues ont leur texte de remplacement est enregistrée, sans annulation" do
        probe = @transaction = RollbackProbe.new
        reread_with([ "img1", "Une pile" ], [ "img2", "Une lampe" ])

        assert update(image_alts: { "img2" => "Une lampe" }).success?
        assert_not probe.rolled_back
      end

      test "menace n° 15 : une fiche publiée dont le texte relu garde un emplacement d'image est refusée sur le texte" do
        @essentials.define_singleton_method(:update) do |essential:|
          saved = essential.dup
          saved.content = "<p>[[image: une pile]]</p>"
          Shared::Result.success(saved)
        end

        result = update

        assert_equal [ :invalid, [ :content ] ], [ result.code, result.errors.keys ]
      end

      test "ADR-0105 : un brouillon garde ses emplacements et ses textes de remplacement vides" do
        assert update(slug: "genetique-la-mitose", content: "<p>[[image: une pile]]</p>", image_alts: { "img1" => "" }).success?
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
