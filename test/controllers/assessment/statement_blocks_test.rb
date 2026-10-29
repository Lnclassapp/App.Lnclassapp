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

  def sheet = get(exercise_session_path(create_exercise_session(student: @student, exercise: @exercise).public_id))

  def result
    session = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 100)
    create_attempt(session:, question: @exercise.questions.first, correct: true)
    get exercise_session_result_path(session.public_id)
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

  test "sans blocs, aucune page ne change" do
    sheet
    assert_select "[data-statement-block]", 0
    result
    assert_select "[data-statement-block]", 0
    assert_select "#session_statement", 0
  end

  test "I9 : un texte de bloc est échappé partout" do
    with_blocks([ { "type" => "paragraph", "text" => "<script>alert(1)</script> **gras**" },
                  { "type" => "box", "label" => "<img src=x onerror=alert(2)>", "paragraphs" => [ "<b>x</b>" ] },
                  { "type" => "table", "caption" => "<i>c</i>", "headers" => [ "<u>h</u>" ], "rows" => [ [ "<script>z</script>" ] ] } ])

    [ -> { sheet }, -> { result }, -> { get exercise_path(@exercise.public_id) } ].each do |visit|
      visit.call

      assert_response :success
      assert_select "script", text: /alert|z/, count: 0
      assert_select "img[onerror]", 0
      assert_select "[data-statement-block] b, [data-statement-block] u, [data-statement-block] i", 0
      assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
    end
  end

  test "I9 : un type inconnu n'est pas rendu et ne plante pas" do
    with_blocks([ { "type" => "iframe", "text" => "intrus" }, "texte", nil, { "type" => "paragraph", "text" => "On observe une lentille." } ])

    [ -> { sheet }, -> { result }, -> { get exercise_path(@exercise.public_id) } ].each do |visit|
      visit.call

      assert_response :success
      assert_select "p", text: "On observe une lentille."
      assert_no_match(/intrus/, response.body)
    end
  end
end
