require "test_helper"

module Catalog
  # contenu-en-blocs (#318), Lot F : le rendu serveur du kind `argument_highlighter` et du bloc `writing` (le surlignage et les
  # vérifications sont jugés dans un navigateur, voir test/system/catalog/course_sheet_argument_test.rb). Les données sont un
  # fichier importé : rien n'y est du HTML, une valeur étrangère ne casse pas la page.
  class CourseSheetArgumentViewTest < ActionView::TestCase
    PREFIX = "catalog/course_sheets".freeze

    def block_html(block) = render(partial: "#{PREFIX}/block", locals: { block: })
    def highlighter(params, caption: nil) = { "type" => "media", "kind" => "argument_highlighter", "params" => params, "caption" => caption }.compact

    test "les passages marqués deviennent des segments de leur catégorie, le reste du texte est brut, dans l'ordre des numéros" do
      block_html(highlighter({ "text_2" => "{C}Donc,{/C} {T}il faut lire.{/T}", "text_1" => "{R}Certains doutent.{/R} puis", "mode" => "thesis" }))

      assert_select "[data-controller='course-sheet--argument-highlighter']", 1
      assert_select ".sheet-hl-seg", 3
      assert_select ".sheet-hl-seg[data-kind=counter]", "Certains doutent."
      assert_select ".sheet-hl-seg[data-kind=connector]", "Donc,"
      assert_select ".sheet-hl-seg[data-kind=thesis]", "il faut lire."
      assert_equal "Certains doutent. puis Donc, il faut lire.", css_select(".sheet-hl-text").first.text
      assert_select ".sheet-hl-btn", 3
      assert_select ".sheet-hl-btn[data-kind=thesis][aria-pressed=false][data-why=?]", I18n.t("catalog.course_sheets.kinds.argument_highlighter.categories.thesis.why")
      assert_select ".sheet-hl-info[aria-live=polite]", text: /#{Regexp.escape(I18n.t("catalog.course_sheets.kinds.argument_highlighter.idle"))}/
    end

    test "tout est échappé : aucune balise, aucun attribut ni style ne vient des données" do
      block_html(highlighter({ "text_1" => "{A}<img src=x onerror=alert(1)> \"><script>x</script>{/A}" }, caption: "Une *source* <b>"))

      assert_select "img, script", 0
      assert_select "[onerror]", 0
      assert_select "[style]", 0
      assert_select ".sheet-hl-seg", /<img src=x onerror=alert\(1\)>/
      assert_select ".sheet-hl-credit i", "source"
    end

    test "sans passage lisible (réglages absents, étrangers ou mal formés), un message au lieu d'une figure morte" do
      message = ERB::Util.html_escape(I18n.t("catalog.course_sheets.kinds.argument_highlighter.empty"))

      [ nil, { "mode" => "thesis" }, { "text_1" => 12 }, { "text_1" => "{Z}inconnue{/Z} {T}pas fermé" }, { "text_100" => "{T}hors numéro{/T}" } ].each do |params|
        html = block_html({ "type" => "media", "kind" => "argument_highlighter", "params" => params }.compact)

        assert_includes html, message, params.inspect
        assert_no_match(/sheet-hl-seg/, html)
      end
    end

    test "seules les catégories présentes dans le texte ont leur bouton" do
      block_html(highlighter({ "text_1" => "{E}Un fait.{/E} {C}Ainsi,{/C}" }))

      assert_select ".sheet-hl-btn", 2
      assert_select ".sheet-hl-btn[data-kind=example]"
      assert_select ".sheet-hl-btn[data-kind=connector]"
    end

    def writing(extra = {}) = { "type" => "writing", "title" => "Sujet", "prompt" => "**Donne** ton avis." }.merge(extra)

    test "la rédaction n'est ni un formulaire ni un champ nommé, et sa liste suit les réglages du bloc" do
      block_html(writing("connectors" => %w[car donc enfin], "min_paragraphs" => 3, "min_words" => 80))

      assert_select "[data-controller='course-sheet--writing'][data-min-paragraphs='3'][data-min-words='80'][data-min-connectors='3']", 1
      assert_select "form", 0
      assert_select "textarea.sheet-writing-input:not([name])", 1
      assert_select "textarea[aria-label=?]", I18n.t("catalog.course_sheets.blocks.writing.label")
      assert_equal %w[opinion paragraphs connectors example question conclusion words], css_select("li[data-check]").map { it["data-check"] }
      assert_select "li[data-check=paragraphs]", /3 paragraphes/
      assert_select "li[data-check=words]", /80 mots/
      assert_select "li[data-state=todo]", 7
      assert_equal %w[car donc enfin], JSON.parse(css_select("[data-controller='course-sheet--writing']").first["data-connectors"])
      assert_select ".sheet-box-label", "Sujet"
      assert_select ".sheet-text b", "Donne"
    end

    test "la vérification des connecteurs n'apparaît que si la liste en compte au moins trois (le minimum à trouver)" do
      block_html(writing("connectors" => %w[car donc]))
      assert_select "li[data-check=connectors]", 0

      block_html(writing("connectors" => %w[car donc enfin]))
      assert_select "li[data-check=connectors]", 1
    end

    test "la rédaction et le surligneur se remettent à zéro avant la mise en cache de Turbo" do
      block_html(writing)
      assert_select "[data-controller='course-sheet--writing'][data-action~='turbo:before-cache@document->course-sheet--writing#reset']", 1

      block_html(highlighter({ "text_1" => "{T}Je pense.{/T}" }))
      assert_select "[data-controller='course-sheet--argument-highlighter'][data-action~='turbo:before-cache@document->course-sheet--argument-highlighter#reset']", 1
    end

    test "le texte d'attente du surligneur est porté par la vue, pour être rétabli au retour arrière" do
      block_html(highlighter({ "text_1" => "{T}Je pense.{/T}" }))

      assert_select ".sheet-hl-info[data-idle=?]", I18n.t("catalog.course_sheets.kinds.argument_highlighter.idle")
    end

    test "sans connecteurs, sans minimum, la liste ne garde que les vérifications sans réglage ; des valeurs étrangères sont ignorées" do
      block_html(writing("connectors" => [ "car", 4, nil ], "min_words" => "beaucoup", "min_paragraphs" => -2))

      assert_equal %w[opinion example question conclusion], css_select("li[data-check]").map { it["data-check"] }
      assert_equal [ "car" ], JSON.parse(css_select("[data-controller='course-sheet--writing']").first["data-connectors"])

      block_html(writing)
      assert_select "li[data-check]", 4
    end
  end
end
