require "test_helper"

# CA-01 à CA-05 et CA-09 — UDR-0139 §3.2. La fiche de révision dans la page de la leçon : coupée après 150 mots en fin de
# bloc, toute présente dans le HTML (« Voir plus » ne fait aucune requête), repli sur le texte des notions, états vide et court.
class Catalog::RevisionSheetTest < ActionDispatch::IntegrationTest
  REST = "[data-catalog--revision-more-target='rest']".freeze

  setup do
    @course = create_course(name: "Propriétés de Thalès", content: "")
    @student = create_student_for(@course)
  end

  def words(count, prefix = "mot") = Array.new(count) { prefix }.join(" ")

  def sheet_document(*paragraph_sizes, extra_blocks: [])
    blocks = paragraph_sizes.each_with_index.map { |size, index| { "type" => "paragraph", "text" => "#{words(size, "p#{index}")} fin#{index}" } }
    { "pages" => [ { "sections" => [ { "title" => "Le cours", "blocks" => blocks + extra_blocks } ] } ], "glossary" => {} }
  end

  def open_course(user = @student)
    sign_in_as user
    get course_path(@course.slug)
    assert_response :success
  end

  def t(key, **) = I18n.t("catalog.courses.show.#{key}", **)

  test "CA-01: the sheet sits in the page before « Prépare interros », cut at the end of the first block that reaches 150 words" do
    create_course_sheet(course: @course, document: sheet_document(100, 100, 100, 100, 100, 100))

    open_course

    assert_select "section#fiche-de-revision h2", text: t("revision_title")
    assert_operator response.body.index("id=\"fiche-de-revision\""), :<, response.body.index("id=\"prepare-interros\"")
    assert_select "section#fiche-de-revision .sheet-screen[data-sheet-theme]"
    assert_select "section#fiche-de-revision p.sheet-text", count: 6
    # Le 1er bloc porte 101 mots (avec le titre de section), le 2e en fait 201 : la coupe tombe après lui.
    assert_select "#{REST} p.sheet-text", count: 4
    assert_select "p.sheet-text", text: /fin1\z/ do |visible|
      assert_empty visible.select { |paragraph| paragraph.ancestors.any? { it["data-catalog--revision-more-target"] == "rest" } }
    end
    assert_select "p.sheet-text", text: /fin2\z/ do |hidden|
      assert(hidden.first.ancestors.any? { it["data-catalog--revision-more-target"] == "rest" })
    end
    assert_select "[data-controller~='catalog--revision-more']" do
      assert_select "button[aria-expanded='false'][data-action='catalog--revision-more#toggle'][data-catalog--revision-more-target='button']",
                    text: t("revision_more")
      assert_select "[data-catalog--revision-more-target='fade']"
      assert_select "p.sr-only[aria-live='polite'][data-catalog--revision-more-target='status']"
    end
  end

  test "CA-01: the controller receives the three texts of the button" do
    create_course_sheet(course: @course, document: sheet_document(100, 100, 100))

    open_course

    assert_select "[data-controller~='catalog--revision-more'][data-catalog--revision-more-more-value='#{t("revision_more")}']" \
                  "[data-catalog--revision-more-less-value='#{t("revision_less")}']" \
                  "[data-catalog--revision-more-shown-value='#{t("revision_shown")}']"
  end

  test "CA-02: without JavaScript the whole sheet is in the HTML, nothing is hidden by the server and the button is masked" do
    create_course_sheet(course: @course, document: sheet_document(100, 100, 100, 100, 100, 100))

    open_course

    6.times { |index| assert_includes response.body, "fin#{index}" }
    assert_select "#{REST}[hidden]", 0
    assert_select "section#fiche-de-revision .sheet-page[hidden], section#fiche-de-revision .sheet-section[hidden]", 0
    assert_select "button[data-catalog--revision-more-target='button'][hidden]"
    assert_select "[data-catalog--revision-more-target='fade'][hidden]"
  end

  test "CA-01: a page and a section that lie after the cut are rest as a whole" do
    long = { "type" => "paragraph", "text" => words(160) }
    document = { "pages" => [ { "sections" => [ { "title" => "Un", "blocks" => [ long ] }, { "title" => "Deux", "blocks" => [ long ] } ] },
                              { "sections" => [ { "title" => "Trois", "blocks" => [ long ] } ] } ], "glossary" => {} }
    create_course_sheet(course: @course, document:)

    open_course

    assert_select ".sheet-section#{REST} h3", text: /Deux/
    assert_select ".sheet-page#{REST} h3", text: /Trois/
    assert_select ".sheet-section h3", text: /Un/
    assert_select "section.sheet-section[data-catalog--revision-more-target='rest']", count: 1
    assert_select "div.sheet-page[data-catalog--revision-more-target='rest']", count: 1
  end

  test "CA-04: a sheet of 120 words is whole, with no « Voir plus »" do
    create_course_sheet(course: @course, document: sheet_document(60, 59))

    open_course

    assert_select "p.sheet-text", count: 2
    assert_select REST, 0
    assert_select "[data-controller~='catalog--revision-more']", 0
    assert_select "button", text: t("revision_more"), count: 0
  end

  test "CA-04: a lesson with neither sheet nor text says the sheet is coming" do
    open_course

    assert_select "section#fiche-de-revision", text: /#{Regexp.escape(t("revision_empty"))}/
    assert_select "button", text: t("revision_more"), count: 0
  end

  test "CA-03: without a sheet, the lesson text then each notion under its title, in the order of the notions, with no link to a notion" do
    @course.update!(content: "<p>Introduction de la leçon.</p>")
    create_essential(course: @course, name: "Seconde notion", position: 2, content: "<p>Texte de la seconde.</p>")
    create_essential(course: @course, name: "Première notion", position: 1, content: "<p>Texte de la première.</p>")
    create_essential(course: @course, name: "Notion cachée", position: 3, status: "draft", content: "<p>Brouillon.</p>")
    sign_in_as create_teacher(classrooms: [ create_classroom(level: @course.level, series: @course.series) ], material: @course.material)

    get course_path(@course.slug)

    assert_response :success
    assert_select "section#fiche-de-revision" do
      assert_select "h3", text: "Première notion"
      assert_select "h3", count: 2
      assert_select "[data-controller~='math']"
    end
    body = response.body
    assert_operator body.index("Introduction de la leçon."), :<, body.index("Première notion")
    assert_operator body.index("Première notion"), :<, body.index("Texte de la première.")
    assert_operator body.index("Texte de la première."), :<, body.index("Seconde notion")
    assert_not_includes body, "Brouillon."
    assert_select "section#fiche-de-revision a", 0
    assert_select "a[href*='/essentials/']", 0
    assert_select "button", text: t("revision_more"), count: 0
  end

  test "CA-03: a long text is cut at the end of a paragraph, the rest is marked and all present" do
    @course.update!(content: "<p>#{words(100)} fin0</p><p>#{words(60)} fin1</p><p>fin2</p>")
    create_essential(course: @course, name: "Notion", content: "<p>fin3</p>")

    open_course

    4.times { |index| assert_includes response.body, "fin#{index}" }
    assert_select "#{REST}[hidden]", 0
    assert_select REST, count: 2 # le paragraphe « fin2 », puis la notion entière (intertitre compris)
    assert_select "#{REST} h3", text: "Notion"
    assert_select "button[aria-expanded='false']", text: t("revision_more")
    assert_select "[data-catalog--revision-more-target='fade'][hidden]"
  end

  test "CA-05: the header of the sheet is not a second h1 in the page of the lesson" do
    document = sheet_document(100, 100, 100)
    document["pages"][0]["header"] = { "title" => "La propriété de Thalès", "intro" => "Une intro." }
    create_course_sheet(course: @course, document:)

    open_course

    assert_select "h1", count: 1
    assert_select "section#fiche-de-revision h3.sheet-h1", text: "La propriété de Thalès"
  end

  test "CA-05: the page names its two sections « Fiche de révision » and « Prépare interros » for every role, with no old name" do
    create_course_sheet(course: @course, document: sheet_document(100, 100, 100))
    teacher = create_teacher(classrooms: [ create_classroom(level: @course.level, series: @course.series) ], material: @course.material)

    [ @student, teacher, create_team_member ].each do |user|
      open_course(user)

      assert_select "h1", count: 1
      assert_select "h2", text: "Fiche de révision"
      assert_select "h2", text: "Prépare interros"
      [ "Fiche de cours", "Révisions de la leçon", "Fiche à revoir" ].each do |old_name|
        assert_select "h1, h2, h3, button, #course_header a", text: /#{old_name}/, count: 0
      end
      delete session_path
    end
  end

  test "CA-09: no « Assigner » button inside the sheet, even when it holds practice exercises" do
    practice = { "type" => "practice", "kind" => "bank", "title" => "Je m'entraîne",
                 "bank" => [ { "prompt" => "2 + 2 ?", "answer" => 4, "solution" => "4" } ] }
    create_course_sheet(course: @course, document: sheet_document(30, extra_blocks: [ practice ]))
    open_course(create_teacher(classrooms: [ create_classroom(level: @course.level, series: @course.series) ], material: @course.material))

    assert_select "section#fiche-de-revision .sheet-practice"
    assert_select "section#fiche-de-revision button, section#fiche-de-revision a", text: /Assigner/, count: 0
  end
end
