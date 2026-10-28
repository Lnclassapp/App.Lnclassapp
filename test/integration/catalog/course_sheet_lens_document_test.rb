require "test_helper"

# contenu-en-blocs (chantier 318), Lot E : la fiche Lentilles livrée avec les seeds passe par la vraie chaîne d'import et se lit
# (sept figures fixes, simulateur, entraînement, sept exercices) ; le rendu serveur des figures tient ses valeurs par défaut et ses
# bornes quand le document les oublie. Les gestes sont jugés dans un navigateur par test/system/catalog/course_sheet_lens_test.rb.
class Catalog::CourseSheetLensDocumentTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PATH = Rails.root.join("db/seeds/data/course_sheets/lentilles.json")
  LESSON_PATH = Rails.root.join("docs/contenus/lecons-traitees/3eme/physique-chimie/les-lentilles.json")
  SIMULATOR = "[data-controller~='course-sheet--lens-simulator']".freeze
  CONSTRUCTION = "[data-controller~='course-sheet--lens-construction']".freeze

  setup do
    @lesson = JSON.parse(LESSON_PATH.read)["courses"].first
    @course = create_course(name: @lesson["name"], level: create_level(name: @lesson["level_name"]), material: create_material(name: @lesson["material_name"]))
    @document = JSON.parse(PATH.read)
  end

  def import(document, kind: "course_sheet")
    file = Rack::Test::UploadedFile.new(StringIO.new(document.to_json), "application/json", original_filename: "lentilles.json")
    perform_enqueued_jobs do
      post teams_imports_path, params: { import: { kind:, files: [ file ] } }, as: :turbo_stream
    end
    Orm::ImportReport.order(:id).last
  end

  # Une fiche d'une page, avec les blocs donnés, lue par un élève de la leçon.
  def read_blocks(*blocks)
    document = @document.merge("pages" => [ { "sections" => [ { "title" => "Essai", "blocks" => blocks } ] } ])
    Orm::CourseSheet.create!(course: @course, theme: "teal", document:)
    sign_in_as create_student_for(@course)
    get course_sheet_path(@course.slug)
    assert_response :success
  end

  test "the file targets the slug of the lesson the demo seeds, and the seeds import it for real" do
    assert_equal @course.slug, @document["course"]
    sign_in_as create_team_member(team_role: "content")

    report = import(@document)

    assert_equal [ "completed", 1, 0 ], [ report.status, report.imported_count, report.error_count ], report.inspect
    assert_equal "teal", Orm::CourseSheet.find_by!(course_id: @course.id).theme
  end

  test "the lesson imports through the course-tree chain, then the sheet lands on that very lesson" do
    @course.destroy!
    sign_in_as create_team_member(team_role: "content")

    lesson_report = import(JSON.parse(LESSON_PATH.read), kind: "course_tree")
    course = Orm::Course.find_by!(slug: @document["course"])
    sheet_report = import(@document)

    assert_equal [ "completed", 0 ], [ lesson_report.status, lesson_report.error_count ], lesson_report.inspect
    assert_equal [ "completed", 1, 0 ], [ sheet_report.status, sheet_report.imported_count, sheet_report.error_count ], sheet_report.inspect
    assert_equal [ course.id ], Orm::CourseSheet.pluck(:course_id)
    assert_equal "Les lentilles", course.name
  end

  test "the imported sheet reads: three pages, seven figures, the simulator, the construction, seven exercises, the lexicon" do
    sign_in_as create_team_member(team_role: "content")
    import(@document)
    sign_out
    sign_in_as create_student_for(@course)

    get course_sheet_path(@course.slug)

    assert_response :success
    assert_select "[data-screen-label]", 3
    assert_select "h1", text: "Les lentilles"
    assert_select ".sheet-lens-diagram", 7
    assert_select ".sheet-lens-diagram svg", 13
    assert_select "#{SIMULATOR} svg circle[data-hit]", 3
    assert_select "#{CONSTRUCTION} svg circle[data-hit='marker']", 1
    assert_select ".sheet-card[data-controller~='course-sheet--exercise']", 7
    assert_select "button.sheet-word", 17
    assert_select ".sheet-screen[data-course-sheet--glossary-glossary-value*='Image virtuelle']"
    assert_select "p", text: I18n.t("catalog.course_sheets.block.unavailable"), count: 0
  end

  test "the simulator starts from the document values, written for the server: real image, object beyond 2F, photo" do
    read_blocks({ "type" => "media", "kind" => "lens_simulator", "params" => { "d" => 8, "h" => 2, "f" => 3, "grid" => false } })

    assert_select "#{SIMULATOR}[data-d='8.0'][data-h='2.0'][data-f='3.0'][data-grid='false']"
    assert_select "#{SIMULATOR} [data-role='grid'][data-visible='false']"
    assert_select "#{SIMULATOR} [data-role='application']", text: I18n.t("catalog.course_sheets.kinds.lens_simulator.js.application_photo")
    assert_select "#{SIMULATOR} [data-role='oap']", text: I18n.t("catalog.course_sheets.kinds.lens_simulator.js.oap_real", value: "4,8")
    assert_select "#{SIMULATOR} [data-role='size']", text: "2 cm / 1,2 cm"
    assert_select "#{SIMULATOR} .sheet-lens-ray[data-virtual='true']", 0
    assert_select "#{SIMULATOR} button[data-preset='photo'][aria-current='true']"
    assert_select "#{SIMULATOR} [data-role='image'][data-visible='true']"
  end

  test "the simulator draws the virtual image with dashes, and no image at the focus" do
    read_blocks({ "type" => "media", "kind" => "lens_simulator", "params" => { "d" => 2, "h" => 1.5, "f" => 4 } },
                { "type" => "media", "kind" => "lens_simulator", "params" => { "d" => 3, "h" => 1.5, "f" => 3 } })

    virtual, focus = css_select(SIMULATOR)
    assert_equal [ "2.0", "3.0" ], [ virtual, focus ].map { it["data-d"] }
    assert_select virtual, "[data-role='nature']", text: I18n.t("catalog.course_sheets.kinds.lens_simulator.js.nature_virtual")
    assert_select virtual, ".sheet-lens-ray[data-virtual='true']", 4
    assert_select virtual, "button[data-preset='magnifier'][aria-current='true']"
    assert_select focus, "[data-role='nature']", text: I18n.t("catalog.course_sheets.kinds.lens_simulator.js.nature_none")
    assert_select focus, "[data-role='image'][data-visible='false']"
    assert_select focus, "[data-role='oap']", text: I18n.t("catalog.course_sheets.kinds.lens_simulator.js.oap_infinite")
    assert_select focus, "[data-role='status']", text: I18n.t("catalog.course_sheets.kinds.lens_simulator.js.status_none")
  end

  test "an image too far to be drawn says so instead of leaving an empty figure" do
    read_blocks({ "type" => "media", "kind" => "lens_simulator", "params" => { "d" => 3.1, "h" => 1.5, "f" => 3 } })

    assert_select "#{SIMULATOR} [data-role='image'][data-visible='false']"
    assert_select "#{SIMULATOR} [data-role='status'][data-tone='warning']", text: I18n.t("catalog.course_sheets.kinds.lens_simulator.js.status_far")
    assert_select "#{SIMULATOR} [data-role='oap']", text: I18n.t("catalog.course_sheets.kinds.lens_simulator.js.oap_real", value: "93")
    assert_select "#{SIMULATOR} .sheet-lens-ray", 5
  end

  test "a simulator without params, with out-of-range or unreadable params, starts inside the bounds" do
    read_blocks({ "type" => "media", "kind" => "lens_simulator" },
                { "type" => "media", "kind" => "lens_simulator", "params" => { "d" => 99, "h" => -3, "f" => "trois" } },
                { "type" => "media", "kind" => "lens_simulator", "params" => "texte" })

    assert_select "#{SIMULATOR}[data-d='8.0'][data-h='2.0'][data-f='3.0'][data-grid='true']", 2
    assert_select "#{SIMULATOR}[data-d='14.5'][data-h='0.5'][data-f='3.0']", 1
  end

  test "the construction starts on its first prompt, with the solution hidden and the score at zero" do
    read_blocks({ "type" => "media", "kind" => "lens_construction" })

    assert_select "#{CONSTRUCTION}[data-f='2'][data-d='3'][data-h='1.5']"
    assert_select "#{CONSTRUCTION} [data-role='prompt']", text: I18n.t("catalog.course_sheets.kinds.lens_construction.js.prompt", f: 2, h: "1,5", d: 3)
    assert_select "#{CONSTRUCTION} [data-role='score']", text: I18n.t("catalog.course_sheets.practice.score", ok: 0, total: 0)
    assert_select "#{CONSTRUCTION} [data-role='solution'][data-visible='false'] .sheet-lens-ray", 5
    assert_select "#{CONSTRUCTION} [data-role='message']:empty"
  end

  test "a figure without params is the families figure, a figure outside the closed list says it is unavailable" do
    read_blocks({ "type" => "figure", "kind" => "lens_diagrams" },
                { "type" => "figure", "kind" => "lens_diagrams", "params" => { "diagram" => "../../etc/passwd" } },
                { "type" => "figure", "kind" => "lens_diagrams", "params" => [ "focal" ] },
                { "type" => "figure", "kind" => "lens_diagrams", "params" => { "diagram" => "focal" } })

    assert_select ".sheet-lens-diagram[data-diagram='families']", 2
    assert_select ".sheet-lens-diagram[data-diagram='focal']", 1
    assert_select ".sheet-lens-diagram", 3
    assert_select "p.sheet-muted", text: I18n.t("catalog.course_sheets.block.unavailable"), count: 1
  end
end
