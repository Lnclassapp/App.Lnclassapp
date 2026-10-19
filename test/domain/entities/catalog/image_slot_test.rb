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

      # Menace n° 13 : le motif des blocs est à coût quadratique sur un « <p> » jamais refermé ; il a un délai par recherche, et
      # tout l'appel a une échéance. Le texte qui dépasse l'un ou l'autre est refusé « trop complexe à relire » (ImageSlot::Unreadable),
      # jamais compté comme un emplacement mal écrit.
      test "un texte hostile (balises jamais refermées) est refusé comme illisible en moins d'une seconde" do
        [ %(<span title="<p>">x</span>) * 20_000, "<p>" * 40_000 ].each do |hostile|
          elapsed = measure { assert_raises(ImageSlot::Unreadable) { ImageSlot.malformed_count(hostile) } }

          assert_operator elapsed, :<, 1.0, "malformed_count a pris #{elapsed.round(2)} s"
        end
      end

      # Chaque recherche réussit vite (le délai par recherche ne la voit pas) mais toutes ensemble tiennent le serveur : 44 s
      # mesurées avant l'échéance globale, pour 203 000 caractères, sous le plafond de 200 Ko.
      test "un texte segmenté (« <li> » × 200 puis « <p></p> », répété) est refusé comme illisible en moins d'une seconde" do
        unit = "<li>" * 200 + "<p></p>"
        segmented = unit * (Essential::CONTENT_MAX * 99 / 100 / unit.size)

        assert_operator segmented.size, :<, Essential::CONTENT_MAX
        elapsed = measure { assert_raises(ImageSlot::Unreadable) { ImageSlot.malformed_count(segmented) } }

        assert_operator elapsed, :<, 1.0, "malformed_count a pris #{elapsed.round(2)} s"
      end

      test "l'échéance globale arrête la lecture à la première correspondance qui la dépasse" do
        assert_raises(ImageSlot::Unreadable) { ImageSlot.malformed_count("<p>a</p><p>b</p>", within: -1) }
        assert_equal 0, ImageSlot.malformed_count("<p>a</p><p>b</p>", within: 5)
      end

      test "un texte long et légitime (plus de 180 Ko de paragraphes, de listes et de titres) est lu en entier" do
        block = "<h2>Titre</h2><p>Un paragraphe de cours assez long, avec <strong>du gras</strong> et des formules.</p>" \
                "<ul><li>Un point</li><li>Un autre point</li></ul>"
        legitimate = block * (190 * 1024 / block.size) + "<p>[[image: une pile]]</p>"

        assert_operator legitimate.size, :>, 180 * 1024
        assert_equal 0, ImageSlot.malformed_count(legitimate)
        assert_equal 1, ImageSlot.scan(legitimate).size
      end

      def measure
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        yield
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      end

      test "un texte nul ou sans emplacement n'en a aucun" do
        assert_empty ImageSlot.scan(nil)
        assert_empty ImageSlot.scan("<p>Rien à insérer.</p>")
      end
    end
  end
end
