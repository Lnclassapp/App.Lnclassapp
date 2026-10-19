require "test_helper"

# ADR-0105 §4.3 : un emplacement est un paragraphe dont tout le texte est « [[image: description]] ».
module Entities
  module Catalog
    class ImageSlotTest < ActiveSupport::TestCase
      test "les emplacements seuls dans leur paragraphe sont lus, dans l'ordre, description nettoyée" do
        html = "<h2>Le circuit</h2><p>[[image: une pile et une lampe]]</p><p>Texte.</p><p> [[image:  un interrupteur ouvert ]] </p>"

        assert_equal [ "une pile et une lampe", "un interrupteur ouvert" ], ImageSlot.scan(html).map(&:description)
      end

      test "un emplacement enregistré par Trix, dans un <div>, est lu aussi" do
        assert_equal [ "une pile" ], ImageSlot.scan("<div>Texte</div><div>[[image: une pile]]</div>").map(&:description)
      end

      test "un emplacement au milieu d'une phrase, vide ou trop long n'en est pas un" do
        html = "<p>Voir [[image: une pile]] ici.</p><p>[[image: ]]</p><p>[[image: #{'a' * 151}]]</p>"

        assert_empty ImageSlot.scan(html)
      end

      test "malformed_count compte les blocs « [[image: …]] » que le motif ne lit pas : trop long, dans une liste, vide, en gras" do
        html = "<p>[[image: une pile]]</p><p>[[image: #{'a' * 151}]]</p><ul><li>[[image: une lampe]]</li></ul><p>[[image: ]]</p>" \
               "<h3><strong>[[image: un titre]]</strong></h3><p>Voir [[image: ceci]] dans la phrase.</p>"

        assert_equal 4, ImageSlot.malformed_count(html)
        assert_equal 0, ImageSlot.malformed_count("<p>[[image: une pile]]</p>")
        assert_equal 0, ImageSlot.malformed_count(nil)
      end

      # Menace n° 13 : le motif des blocs est à coût quadratique sur un « <p> » jamais refermé ; il a un délai (0,5 s), et le
      # texte qui le dépasse est compté comme mal écrit, donc refusé.
      test "un texte hostile (balises jamais refermées) est refusé en moins d'une seconde, sans tenir le serveur" do
        [ %(<span title="<p>">x</span>) * 20_000, "<p>" * 40_000 ].each do |hostile|
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          count = ImageSlot.malformed_count(hostile)
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

          assert_operator count, :>, 0
          assert_operator elapsed, :<, 1.0, "malformed_count a pris #{elapsed.round(2)} s"
        end
      end

      test "un texte nul ou sans emplacement n'en a aucun" do
        assert_empty ImageSlot.scan(nil)
        assert_empty ImageSlot.scan("<p>Rien à insérer.</p>")
      end
    end
  end
end
