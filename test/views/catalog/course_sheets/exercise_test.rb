require "test_helper"

module Catalog
  # contenu-en-blocs (#318), Lot C : le rendu serveur des blocs `exercise` et `practice` (les verdicts sont jugés côté navigateur,
  # voir test/system/catalog/course_sheet_exercise_test.rb).
  class CourseSheetExerciseViewTest < ActionView::TestCase
    PREFIX = "catalog/course_sheets".freeze
    CTRL = "course-sheet--exercise".freeze

    def reference_blocks = JSON.parse(Rails.root.join("test/fixtures/files/course_sheets/reference.json").read)["pages"].flat_map { it["sections"] }.flat_map { it["blocks"] }
    def reference_block(type, kind: nil) = reference_blocks.find { it["type"] == type && (kind.nil? || it["kind"] == kind) }
    def block_html(block) = render(partial: "#{PREFIX}/block", locals: { block: })
    def t_sheet(key, **) = I18n.t("catalog.course_sheets.#{key}", **)

    test "l'exercice de référence rend titre, énoncé, champs numériques et à choix, boutons et textes d'interface" do
      block_html(reference_block("exercise"))

      assert_select "[data-controller='#{CTRL}']", 1
      assert_select ".sheet-card-title", "Exercice 4"
      assert_select "input.sheet-input[inputmode=decimal][data-input=numeric]", 2
      assert_select "input[data-field-id=e4an][data-answer='3.6']"
      assert_select "input[data-field-id=e4mn][data-answer='4.2']"
      assert_select "[data-input=choice][data-field-id=e6][data-answer='0'][data-frozen=true] button", 2
      assert_select "[data-input=choice] button[data-index='1']", "non parallèles"
      assert_select "button[data-action='click->#{CTRL}#check']", t_sheet("exercise.check")
      assert_select "[data-#{CTRL}-target=message][aria-live=polite]"
    end

    test "les textes d'interface et la tolérance viennent de la locale et du domaine" do
      block_html(reference_block("exercise"))

      assert_select "[data-#{CTRL}-tolerance-value='#{Entities::Catalog::NumericAnswer::TOLERANCE}']"
      assert_select "[data-#{CTRL}-incomplete-value=?]", t_sheet("exercise.incomplete")
      assert_select "[data-#{CTRL}-correct-value=?]", t_sheet("exercise.correct")
      assert_select "[data-#{CTRL}-wrong-value=?]", t_sheet("exercise.wrong")
      assert_select "[data-#{CTRL}-all-correct-value=?]", t_sheet("exercise.all_correct")
      assert_select "[data-#{CTRL}-some-wrong-value=?]", t_sheet("exercise.some_wrong")
    end

    test "Indice et Correction sont des boutons repliés qui commandent leur panneau" do
      block_html(reference_block("exercise"))

      %w[hint correction].each do |part|
        assert_select "button[aria-expanded=false][data-#{CTRL}-target=#{part}Button]", t_sheet("exercise.#{part}")
        assert_select "[hidden][data-#{CTRL}-target=#{part}]"
      end
      assert_select "[data-#{CTRL}-target=hint]", /Écris d'abord les trois rapports\./
      assert_select "[data-#{CTRL}-target=correction]", /AN = 3,6 cm/
    end

    test "sans indice ni correction, aucun bouton ni panneau" do
      block = reference_block("exercise").except("hint", "correction")
      block_html(block)

      assert_select "[data-#{CTRL}-target=hintButton], [data-#{CTRL}-target=correctionButton], [data-#{CTRL}-target=hint], [data-#{CTRL}-target=correction]", 0
      assert_select "button[data-action='click->#{CTRL}#check']", 1
    end

    test "un choix non figé n'a pas data-frozen, chaque bouton annonce son état" do
      block = { "type" => "exercise", "title" => "Q", "prompt" => "P", "fields" => [
        { "id" => "c1", "input" => "choice", "label" => "Choisis", "options" => [ "a", "b", "c" ], "answer" => 2 }
      ] }
      block_html(block)

      assert_select "[data-input=choice]:not([data-frozen])", 1
      assert_select "[role=group][aria-labelledby] button[type=button][aria-pressed=false]", 3
    end

    test "le HTML et les scripts du document sont échappés, jamais interprétés" do
      block = { "type" => "exercise", "title" => "<script>x()</script>", "prompt" => "<img src=x onerror=y>", "fields" => [
        { "id" => "n", "input" => "numeric", "label" => "\"><b>", "answer" => 1 }
      ], "hint" => "<i>h</i>", "correction" => "<u>c</u>" }
      html = block_html(block)

      assert_no_match(/<script|<img|<i>|<u>|<b>/, html)
    end

    test "la banque rend le bloc Je m'entraîne avec ses énoncés, ses textes et son score à zéro" do
      block_html(reference_block("practice", kind: "bank"))
      ctrl = "course-sheet--practice"

      assert_select "[data-controller='#{ctrl}'][data-#{ctrl}-kind-value=bank]", 1
      bank = JSON.parse(css_select("[data-controller='#{ctrl}']").first["data-#{ctrl}-bank-value"])
      assert_equal [ { "prompt" => "Calculer 2 + 2.", "answer" => 4, "solution" => "2 + 2 = 4." } ], bank
      assert_select "[data-#{ctrl}-score-template-value=?]", t_sheet("practice.score", ok: "{ok}", total: "{total}")
      assert_select "[data-#{ctrl}-target=score]", t_sheet("practice.score", ok: 0, total: 0)
      assert_select "button[data-action='click->#{ctrl}#check']", t_sheet("practice.check")
      assert_select "button[data-action='click->#{ctrl}#toggleSolution']", t_sheet("practice.solution")
      assert_select "button[data-action='click->#{ctrl}#next']", t_sheet("practice.next")
      assert_select "input[data-action*='keydown.enter->#{ctrl}#check']"
      assert_select ".sheet-practice-badge", "Banque d'énoncés"
    end

    test "le générateur thales_ratio rend le même bloc sans banque (le générateur est du Lot D)" do
      block_html(reference_block("practice", kind: "thales_ratio"))
      ctrl = "course-sheet--practice"

      assert_select "[data-controller='#{ctrl}'][data-#{ctrl}-kind-value=thales_ratio]", 1
      assert_select "[data-#{ctrl}-bank-value]", 0
      assert_select ".sheet-practice-badge", "Un énoncé au hasard"
    end
  end
end
