require "test_helper"

module Entities
  module Catalog
    # UDR-0139 §3.2 : la coupe de la fiche de révision. 150 mots de texte, coupe après le premier bloc qui atteint le seuil ;
    # une formule vaut un mot, une figure aucun.
    class RevisionPreviewTest < ActiveSupport::TestCase
      def words(count) = Array.new(count) { "mot" }.join(" ")
      def paragraph(count) = { "type" => "paragraph", "text" => words(count) }
      def page(*blocks, header: nil) = { "header" => header, "sections" => [ { "title" => "Titre", "blocks" => blocks } ] }.compact

      def preview(*blocks) = RevisionPreview.for_sheet([ page(*blocks) ])

      test "a word is a run of letters or digits, a formula is one word, a glossary mark is its word" do
        assert_equal 0, RevisionPreview.count_words(nil)
        assert_equal 0, RevisionPreview.count_words("  — ... ")
        assert_equal 4, RevisionPreview.count_words("Le petit triangle AMN")
        assert_equal 3, RevisionPreview.count_words("$\\frac{AM}{AB} + 2$ vaut $0,5$ ")
        assert_equal 4, RevisionPreview.count_words("Deux droites [[secantes|sécantes]] croisent")
        assert_equal 3, RevisionPreview.count_words("un **deux** *trois*")
      end

      test "a glossary mark with a several-word label counts every word of the label" do
        assert_equal 4, RevisionPreview.count_words("Un [[angle_droit|angle droit]] ici")
      end

      test "an escaped dollar sign is a price, not a formula" do
        assert_equal 4, RevisionPreview.count_words("Il coûte 5 \\$ ici")
        assert_equal 5, RevisionPreview.count_words("1 \\$ puis $x$ et 2 \\$")
      end

      test "every type of block of a sheet document goes through for_sheet" do
        %w[paragraph box simple steps table figure media exercise practice writing].each do |type|
          assert_nothing_raised { preview({ "type" => type }) }
        end
        assert_raises(ArgumentError) { preview({ "type" => "inconnu" }) }
      end

      test "the cut falls after the first block that brings the total to 150 or more, at the end of the block" do
        sheet = preview(paragraph(100), paragraph(60), paragraph(10), paragraph(10))

        assert_predicate sheet, :cut?
        assert_not sheet.rest?(0, 0, 0)
        assert_not sheet.rest?(0, 0, 1), "le bloc qui passe le seuil reste entier"
        assert sheet.rest?(0, 0, 2)
        assert sheet.rest?(0, 0, 3)
        assert_equal 181, sheet.total
      end

      test "a block that brings the total to exactly 150 words ends the visible part" do
        sheet = preview(paragraph(149), paragraph(5))

        assert_not sheet.rest?(0, 0, 0)
        assert sheet.rest?(0, 0, 1)
      end

      test "a single very long block is shown whole: there is nothing after it" do
        sheet = preview(paragraph(600))

        assert_not_predicate sheet, :cut?
        assert_not sheet.rest?(0, 0, 0)
      end

      test "up to 150 words in all, there is no cut" do
        sheet = preview(paragraph(100), paragraph(20))
        assert_not_predicate sheet, :cut?
        assert_not sheet.rest?(0, 0, 1)

        exact = preview(paragraph(100), paragraph(49))
        assert_equal 150, exact.total
        assert_not_predicate exact, :cut?
      end

      test "figures, media and exercises count for no word; they are hidden when they follow the cut" do
        figure = { "type" => "media", "kind" => "thales_figure" }
        exercise = { "type" => "exercise", "title" => "Un exercice avec des mots #{words(40)}" }
        sheet = preview(paragraph(100), figure, exercise, paragraph(60), figure)

        assert_equal 161, sheet.total
        assert_not sheet.rest?(0, 0, 1), "la figure compte zéro : le seuil n'est pas atteint"
        assert_not sheet.rest?(0, 0, 3)
        assert sheet.rest?(0, 0, 4)
      end

      test "boxes, steps, tables and simple explanations count their text" do
        box = { "type" => "box", "label" => "Propriété", "paragraphs" => [ words(20), words(10) ] }
        steps = { "type" => "steps", "label" => "Méthode", "items" => [ words(10), words(10) ] }
        table = { "type" => "table", "caption" => "Cap", "headers" => %w[A B], "rows" => [ [ words(2), words(3) ] ] }
        simple = { "type" => "simple", "text" => words(5) }
        sheet = preview(box, steps, table, simple)

        assert_equal 1 + 31 + 21 + 8 + 5, sheet.total
      end

      test "the titles of the page and of the sections count with the block that follows them" do
        header = { "title" => words(20), "intro" => words(30) }
        sheet = RevisionPreview.for_sheet([ page(paragraph(100), paragraph(5), header:) ])

        assert_equal 20 + 30 + 1 + 100 + 5, sheet.total
        assert_not sheet.rest?(0, 0, 0)
        assert sheet.rest?(0, 0, 1), "50 + 1 + 100 atteint 150 dès le premier bloc"
      end

      test "a page or a section that lies entirely after the cut is rest as a whole" do
        first = { "sections" => [ { "title" => "S1", "blocks" => [ paragraph(100), paragraph(60) ] },
                                  { "title" => "S2", "blocks" => [ paragraph(10) ] } ] }
        second = page(paragraph(10))
        sheet = RevisionPreview.for_sheet([ first, second ])

        assert_not sheet.rest?(0)
        assert_not sheet.rest?(0, 0)
        assert sheet.rest?(0, 1)
        assert sheet.rest?(1)
        assert sheet.rest?(1, 0, 0)
      end

      test "texts: the lesson text and the notions are cut at the end of a paragraph, titles included" do
        sheet = RevisionPreview.for_texts([ { title: nil, blocks: [ words(100), words(20) ] },
                                            { title: "La notion", blocks: [ words(40), words(5) ] },
                                            { title: "Autre", blocks: [ words(5) ] } ])

        assert_predicate sheet, :cut?
        assert_not sheet.rest?(0, 1)
        assert_not sheet.rest?(1, 0), "2 + 120 + 40 atteint 150 au premier paragraphe de la notion"
        assert sheet.rest?(1, 1)
        assert sheet.rest?(2)
      end

      test "no block, no cut" do
        assert_not_predicate RevisionPreview.for_sheet([]), :cut?
        assert_not_predicate RevisionPreview.for_texts([]), :cut?
      end

      def notion_sheet(remember: "un", steps: %w[a b], statement: "x", example_steps: %w[c d], pitfall: "p", figure: nil, practice: nil)
        NotionSheet.new(remember:, method_steps: steps, example_statement: statement, example_steps:, pitfall:, figure_key: figure, practice:)
      end

      def practice = NotionPractice.new(statement: "Calcule.", questions: [], digest: "0123456789abcdef")

      test "notions: the blocks of the template are counted in reading order, a formula is one word, a figure none" do
        sheet = notion_sheet(remember: "Pour $a$ et $b$ positifs", steps: [ words(2), words(3) ], statement: words(4), example_steps: [ words(1), words(1) ],
                             pitfall: words(5), figure: "f")
        preview = RevisionPreview.for_notions([ sheet ])

        assert_equal 5 + 5 + 4 + 2 + 5, preview.total
      end

      test "notions: the cut falls after the first block that reaches 150 words and the rest is keyed by notion and block" do
        long = notion_sheet(remember: words(100), steps: [ words(30), words(30) ], figure: "f")
        other = notion_sheet(remember: words(10))
        preview = RevisionPreview.for_notions([ long, other ])

        assert_predicate preview, :cut?
        assert_not preview.rest?(0, RevisionPreview::REMEMBER)
        assert_not preview.rest?(0, RevisionPreview::METHOD), "le bloc qui passe le seuil reste entier"
        assert preview.rest?(0, RevisionPreview::FIGURE)
        assert preview.rest?(0, RevisionPreview::EXAMPLE)
        assert preview.rest?(0, RevisionPreview::PITFALL)
        assert preview.rest?(1), "la notion entière après la coupe"
      end

      test "CA-10: the practice block sits between the example and the pitfall and counts no word" do
        assert_equal [ 0, 1, 2, 3, 4, 5 ], [ RevisionPreview::REMEMBER, RevisionPreview::METHOD, RevisionPreview::FIGURE,
                                              RevisionPreview::EXAMPLE, RevisionPreview::PRACTICE, RevisionPreview::PITFALL ].sort
        assert_operator RevisionPreview::EXAMPLE, :<, RevisionPreview::PRACTICE
        assert_operator RevisionPreview::PRACTICE, :<, RevisionPreview::PITFALL
        sheet = notion_sheet(remember: words(3), steps: [ words(1), words(1) ], statement: words(1), example_steps: [ words(1), words(1) ],
                             pitfall: words(2), practice:)

        assert_equal 3 + 2 + 3 + 2, RevisionPreview.for_notions([ sheet ]).total
      end

      test "CA-10: a cut before the practice hides the whole block, a cut after it keeps it whole, and it is never the block that crosses the limit" do
        before = notion_sheet(remember: words(160), practice:)
        other = notion_sheet(remember: words(5))
        cut_early = RevisionPreview.for_notions([ before, other ])
        assert cut_early.rest?(0, RevisionPreview::PRACTICE)
        assert cut_early.rest?(0, RevisionPreview::PITFALL)

        after_example = notion_sheet(statement: words(160), practice:)
        cut_late = RevisionPreview.for_notions([ after_example, other ])
        assert_not cut_late.rest?(0, RevisionPreview::EXAMPLE), "le bloc qui passe le seuil reste entier"
        assert cut_late.rest?(0, RevisionPreview::PRACTICE)
        assert_predicate cut_late, :cut?

        after = notion_sheet(pitfall: words(160), practice:)
        cut_after = RevisionPreview.for_notions([ after, other ])
        assert_not cut_after.rest?(0, RevisionPreview::PRACTICE), "la coupe tombe après le bloc : il est visible en entier"
        assert_not cut_after.rest?(0, RevisionPreview::PITFALL)
      end

      test "CA-2: a notion without practice has no practice block key" do
        preview = RevisionPreview.for_notions([ notion_sheet(remember: words(160)), notion_sheet ])

        assert_not preview.rest?(0, RevisionPreview::PRACTICE), "une clé inconnue reste visible"
      end

      test "notions: a short lesson has no cut" do
        assert_not_predicate RevisionPreview.for_notions([ notion_sheet, notion_sheet ]), :cut?
      end
    end
  end
end
