require "test_helper"

module Entities
  module Catalog
    # ADR-0115, menace I9 : le sujet d'un exercice, une liste de blocs (paragraph, box, table), dix au plus.
    class StatementBlocksTest < ActiveSupport::TestCase
      def statement_blocks(count = 1) = Array.new(count) { { "type" => "paragraph", "text" => "Un énoncé" } }

      test "un sujet de dix blocs est accepté, de onze refusé" do
        assert_empty StatementBlocks.errors(statement_blocks(10))
        assert_equal [ :too_many ], StatementBlocks.errors(statement_blocks(11)).map(&:reason)
      end

      test "un sujet accepte le document encadré et le tableau" do
        blocks = [ { "type" => "box", "label" => "Voir de près et de loin", "paragraphs" => [ "Un texte." ] },
                   { "type" => "table", "caption" => "Mesures", "headers" => %w[a b c d], "rows" => [ %w[1 2 3 4], %w[5 6 7 8] ] } ]

        assert_empty StatementBlocks.errors(blocks)
      end

      test "un sujet refuse un type de bloc hors paragraph, box et table" do
        %w[steps figure media exercise practice writing simple inconnu].each do |type|
          errors = StatementBlocks.errors([ { "type" => type, "text" => "x" } ])

          assert_equal [ :unknown_type ], errors.map(&:reason), type
          assert_equal 1, errors.first.position
        end
      end

      test "un sujet refuse du HTML, un lien et ce qui n'est pas une liste de blocs" do
        assert_equal [ :html_forbidden ], StatementBlocks.errors([ { "type" => "paragraph", "text" => "<script>x</script>" } ]).map(&:reason)
        assert_equal [ :url_forbidden ], StatementBlocks.errors([ { "type" => "paragraph", "text" => "http://x.fr" } ]).map(&:reason)
        assert_equal [ :wrong_type ], StatementBlocks.errors("paragraph").map(&:reason)
        assert_equal [ :wrong_type ], StatementBlocks.errors([ "paragraph" ]).map(&:reason)
      end

      test "un sujet refuse une clé inconnue, une clé absente, un tableau de mauvaise taille et une formule ouverte" do
        assert_equal [ :unknown_key ], StatementBlocks.errors([ { "type" => "paragraph", "text" => "x", "extra" => 1 } ]).map(&:reason)
        assert_includes StatementBlocks.errors([ { "type" => "paragraph" } ]).map(&:reason), :missing_key
        assert_includes StatementBlocks.errors([ { "type" => "table", "headers" => %w[a b], "rows" => [ %w[1] ] } ]).map(&:reason), :wrong_size
        assert_equal [ :unbalanced_math ], StatementBlocks.errors([ { "type" => "paragraph", "text" => "$x" } ]).map(&:reason)
      end

      test "un sujet signale chaque type inconnu à sa position" do
        errors = StatementBlocks.errors([ { "type" => "iframe" }, { "type" => "paragraph", "text" => "x" }, { "type" => "script" } ])

        assert_equal [ :unknown_type, :unknown_type ], errors.map(&:reason)
        assert_equal [ 1, 3 ], errors.map(&:position)
      end

      test "un sujet de onze blocs inconnus ne signale que le nombre de blocs" do
        assert_equal [ :too_many ], StatementBlocks.errors(Array.new(11) { { "type" => "iframe" } }).map(&:reason)
      end

      test "un type inconnu trop long est tronqué à 40 caractères dans l'erreur" do
        assert_equal "a" * 40, StatementBlocks.errors([ { "type" => "a" * 100 } ]).first.detail
      end

      test "un sujet trop lourd est refusé" do
        rows = Array.new(30) { Array.new(8) { "a" * 2000 } }
        blocks = Array.new(10) { { "type" => "table", "headers" => Array.new(8) { "h" }, "rows" => rows } }

        assert_equal [ :too_large ], StatementBlocks.errors(blocks).map(&:reason)
      end

      test "un sujet dont le contenu ne se sérialise pas en JSON est refusé sans lever" do
        errors = StatementBlocks.errors([ { "type" => "paragraph", "text" => Float::NAN } ])

        assert_equal [ [ nil, :wrong_type, "json" ] ], errors.map { [ it.position, it.reason, it.detail ] }
      end

      test "un texte vide, trop long ou aux marques [[ ]] est refusé à sa position" do
        paragraph = ->(text) { StatementBlocks.errors([ { "type" => "paragraph", "text" => "ok" }, { "type" => "paragraph", "text" => text } ]) }

        assert_equal [ [ 2, :blank, "text" ] ], paragraph.("   ").map { [ it.position, it.reason, it.detail ] }
        assert_equal [ [ 2, :too_long, "text" ] ], paragraph.("a" * 2001).map { [ it.position, it.reason, it.detail ] }
        assert_equal [ [ 2, :malformed_mark, "text" ] ], paragraph.("voir [[x]]").map { [ it.position, it.reason, it.detail ] }
        assert_equal [ [ 2, :wrong_type, "text" ] ], paragraph.(12).map { [ it.position, it.reason, it.detail ] }
      end

      test "un bloc box refuse un ton inconnu et des paragraphes absents, vides, trop nombreux ou mal typés" do
        box = ->(**changes) { StatementBlocks.errors([ { "type" => "box", "label" => "Retenir", "paragraphs" => [ "Un texte." ] }.merge(changes.stringify_keys) ]) }

        assert_empty box.(tone: "remember")
        assert_equal [ [ :invalid_value, "tone" ] ], box.(tone: "danger").map { [ it.reason, it.detail ] }
        assert_equal [ [ :wrong_type, "paragraphs" ] ], box.(paragraphs: "Un texte.").map { [ it.reason, it.detail ] }
        assert_equal [ [ :blank, "paragraphs" ] ], box.(paragraphs: []).map { [ it.reason, it.detail ] }
        assert_equal [ [ :too_many, "paragraphs" ] ], box.(paragraphs: Array.new(11) { "Un texte." }).map { [ it.reason, it.detail ] }
      end

      test "un tableau refuse des en-têtes ou des lignes qui ne sont pas des listes, sans lever" do
        table = ->(headers, rows) { StatementBlocks.errors([ { "type" => "table", "headers" => headers, "rows" => rows } ]).map { [ it.reason, it.detail ] } }

        assert_equal [ [ :wrong_type, "headers" ] ], table.("a", [ %w[1] ])
        assert_equal [ [ :wrong_type, "rows" ] ], table.(%w[a], "1")
        assert_equal [ [ :wrong_type, "rows" ] ], table.(%w[a], [ "1" ])
        assert_equal [ [ :blank, "rows" ] ], table.(%w[a], [ [] ])
        assert_empty table.(%w[a b], [ [ "1", "" ] ])
      end

      test "un sujet vide ou absent est valide" do
        assert_empty StatementBlocks.errors(nil)
        assert_empty StatementBlocks.errors([])
      end
    end
  end
end
