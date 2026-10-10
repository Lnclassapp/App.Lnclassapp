require "test_helper"

# ADR-0089 §4.3 : un emplacement est un paragraphe dont tout le texte est « [[image: description]] ».
module Entities
  module Catalog
    class ImageSlotTest < ActiveSupport::TestCase
      test "les emplacements seuls dans leur paragraphe sont lus, dans l'ordre, description nettoyée" do
        html = "<h2>Le circuit</h2><p>[[image: une pile et une lampe]]</p><p>Texte.</p><p> [[image:  un interrupteur ouvert ]] </p>"

        assert_equal [ "une pile et une lampe", "un interrupteur ouvert" ], ImageSlot.scan(html).map(&:description)
      end

      test "un emplacement au milieu d'une phrase, vide ou trop long n'en est pas un" do
        html = "<p>Voir [[image: une pile]] ici.</p><p>[[image: ]]</p><p>[[image: #{'a' * 151}]]</p>"

        assert_empty ImageSlot.scan(html)
      end

      test "un texte nul ou sans emplacement n'en a aucun" do
        assert_empty ImageSlot.scan(nil)
        assert_empty ImageSlot.scan("<p>Rien à insérer.</p>")
      end
    end
  end
end
