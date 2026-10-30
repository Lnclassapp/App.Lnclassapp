require "test_helper"

# correction-comme-en-classe, Lot E (CA-25, menace I9 côté rendu) : le sujet en blocs — le document encadré et le tableau — s'affiche
# sur la feuille, le résultat et la page de l'exercice ; tout texte est échappé, un type inconnu n'est pas rendu, le tableau défile seul.
class Assessment::StatementBlocksTest < ActionDispatch::IntegrationTest
  BLOCKS = [
    { "type" => "paragraph", "text" => "On observe une lentille." },
    { "type" => "box", "label" => "Voir de près et de loin", "paragraphs" => [ "Un œil qui accommode.", "Le cristallin change de forme." ] },
    { "type" => "table", "caption" => "Mesures de la lentille", "headers" => %w[Objet Distance Image Nature],
      "rows" => [ %w[A 10 5 réelle], %w[B 20 4 virtuelle] ] }
  ].freeze

  setup do
    @exercise = create_exercise(title: "Lentilles", questions: 1)
    @course = @exercise.essential.course
    @student = create_student_for(@course)
    sign_in_as @student
  end

  def with_blocks(blocks) = @exercise.update!(statement_blocks: blocks)

  # Écrit sans passer par la validation : un sujet hostile peut déjà être en base (menace I9, côté rendu).
  def with_raw_blocks(blocks) = @exercise.update_columns(statement_blocks: blocks)

  def each_page
    [ -> { sheet }, -> { result }, -> { get exercise_path(@exercise.public_id) } ].each do |visit|
      visit.call
      assert_response :success
      yield
    end
  end

  def capture_log
    io = StringIO.new
    previous = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = previous
  end

  def sheet
    @started ||= create_exercise_session(student: @student, exercise: @exercise)
    get exercise_session_path(@started.public_id)
  end

  def result
    @completed ||= create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 100).tap do |session|
      create_attempt(session:, question: @exercise.questions.first, correct: true)
    end
    get exercise_session_result_path(@completed.public_id)
  end

  def assert_blocks
    assert_response :success
    assert_select "p", text: "On observe une lentille."
    assert_select "[data-statement-block=box]" do
      assert_select "p", text: "Voir de près et de loin"
      assert_select "p", text: "Un œil qui accommode."
    end
    assert_select "[data-statement-block=table].overflow-x-auto" do
      assert_select "caption", text: "Mesures de la lentille"
      assert_select "th[scope=col]", 4
      assert_select "tbody tr", 2
      assert_select "td", text: "virtuelle"
    end
  end

  test "CA-25 : la feuille de l'élève montre le document et le tableau" do
    with_blocks(BLOCKS)
    sheet

    assert_blocks
  end

  test "CA-25 : le résultat montre le document et le tableau" do
    with_blocks(BLOCKS)
    result

    assert_blocks
  end

  test "CA-25 : la page de l'exercice montre le document et le tableau" do
    with_blocks(BLOCKS)
    get exercise_path(@exercise.public_id)

    assert_blocks
  end

  test "sans blocs, aucune section n'est rendue sur les trois pages" do
    [ nil, [] ].each do |blocks|
      with_raw_blocks(blocks)

      each_page do
        assert_select "[data-statement-block]", 0
        assert_select "#session_statement", 0
      end
    end
  end

  test "le professeur de la classe qui lit le résultat d'un élève voit le sujet" do
    classroom = create_classroom(level: @course.level, series: @course.series)
    student = create_student(classroom:)
    with_blocks(BLOCKS)
    session = create_exercise_session(student:, exercise: @exercise, status: "completed", score_percent: 100)
    create_attempt(session:, question: @exercise.questions.first, correct: true)
    sign_in_as create_teacher(classrooms: [ classroom ])

    get exercise_session_result_path(session.public_id)

    assert_response :success
    assert_select "#session_statement [data-statement-block=table]"
    assert_select "#session_statement [data-statement-block=box]"
  end

  test "I9 : un texte de bloc est échappé partout" do
    with_blocks([ { "type" => "paragraph", "text" => "<script>alert(1)</script> **gras**" },
                  { "type" => "box", "label" => "<img src=x onerror=alert(2)>", "paragraphs" => [ "<b>x</b>" ] },
                  { "type" => "table", "caption" => "<i>c</i>", "headers" => [ "<u>h</u>" ], "rows" => [ [ "<script>z</script>" ] ] } ])

    each_page do
      assert_select "script", text: /alert\(/, count: 0
      assert_select "script", text: /<script>z/, count: 0
      assert_select "img[onerror]", 0
      assert_select "[data-statement-block] b, [data-statement-block] u, [data-statement-block] i", 0
      [ "&lt;script&gt;alert(1)&lt;/script&gt;",
        "&lt;img src=x onerror=alert(2)&gt;",
        "&lt;i&gt;c&lt;/i&gt;",
        "&lt;u&gt;h&lt;/u&gt;",
        "&lt;script&gt;z&lt;/script&gt;" ].each { |escaped| assert_includes response.body, escaped }
    end
  end

  test "un tableau sans légende n'a pas de caption et se nomme par le titre traduit" do
    with_blocks([ { "type" => "table", "headers" => %w[a b], "rows" => [ %w[1 2] ] } ])

    each_page do
      assert_select "[data-statement-block=table] caption", 0
      assert_select "[data-statement-block=table][aria-label=?]", I18n.t("assessment.exercise_sessions.show.statement")
    end
  end

  test "I9 : un type inconnu n'est pas rendu, ne plante pas et laisse une trace sans le texte" do
    with_raw_blocks([ { "type" => "iframe#{"x" * 100}", "text" => "intrus" }, "texte", nil, { "type" => "paragraph", "text" => "On observe une lentille." } ])

    log = capture_log do
      each_page do
        assert_select "p", text: "On observe une lentille."
        assert_no_match(/intrus/, response.body)
      end
    end

    assert_includes log, "bloc ignoré"
    assert_includes log, "iframe#{"x" * 34}\""
    assert_not_includes log, "x" * 35
    assert_not_includes log, "intrus"
  end

  test "I9 : au plus dix blocs sont rendus" do
    with_raw_blocks(Array.new(11) { |index| { "type" => "paragraph", "text" => "P#{index + 1}" } })

    each_page do
      assert_select "p", text: "P10"
      assert_select "p", text: "P11", count: 0
    end
  end

  test "le ton du document encadré : connu, absent ou invalide" do
    box = ->(tone) { { "type" => "box", "label" => "L", "paragraphs" => [ "t" ] }.merge(tone) }

    with_raw_blocks([ box.call("tone" => "remember") ])
    sheet
    assert_select "[data-statement-block=box].border-success"

    with_raw_blocks([ box.call({}) ])
    sheet
    assert_select "[data-statement-block=box].border-brand"

    with_raw_blocks([ box.call("tone" => "x\" onclick=\"y") ])
    sheet
    assert_select "[data-statement-block=box].border-brand"
    assert_select "[onclick]", 0
  end
end
