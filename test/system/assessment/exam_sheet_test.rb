require "application_system_test_case"

# UDR-0157 (#390) : le sujet, la copie et le résultat d'un exercice sont une feuille de cahier en noir,
# blanc et gris : papier #fbf6e9, aucun bleu, vert ni rouge calculé, « Juste » et « Faux » écrits, aucun défilement horizontal.
class Assessment::ExamSheetTest < ApplicationSystemTestCase
  PAPER = "rgb(251, 246, 233)".freeze
  # Tout élément de la feuille : couleur, fond et bords, rendus en rgb(a) par le navigateur.
  CHROMA_SCRIPT = <<~JS.freeze
    (() => {
      const bad = [];
      const props = ["color", "backgroundColor", "borderTopColor", "borderRightColor", "borderBottomColor", "borderLeftColor",
                     "outlineColor", "textDecorationColor", "fill", "stroke"];
      document.querySelectorAll(".exam-sheet, .exam-sheet *").forEach((el) => {
        const style = getComputedStyle(el);
        props.forEach((prop) => {
          const m = (style[prop] || "").match(/^rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)/);
          if (!m || style[prop] === "#{PAPER}") return;
          const [r, g, b] = [m[1], m[2], m[3]].map(Number);
          if (Math.max(r, g, b) - Math.min(r, g, b) > 8) bad.push(`${el.tagName}.${el.className} ${prop} ${style[prop]}`);
        });
      });
      return bad.slice(0, 10);
    })()
  JS

  setup do
    @exercise = create_exercise(title: "Méiose", questions: 2, statement: "Étudie la méiose.")
    @questions = @exercise.questions.order(:position).to_a
    @student = create_student_for(@exercise.essential.course)
    sign_in_as @student
  end

  test "le sujet : feuille, cartouche, titre unique, consigne sans durée ni tentative, aucune couleur" do
    visit exercise_path(@exercise.public_id)

    assert_selector ".exam-sheet .sheet-cahier"
    assert_selector "#exam-header", text: /Interrogation.*Lnclass/m
    assert_selector "h1", count: 1, text: "Méiose"
    assert_selector "#exam-instructions", text: "2 questions"
    assert_no_text(/minutes|tentative/i)
    assert_achromatic
    assert_no_overflow
  end

  test "la copie : cartouche, consigne, phrase de verrouillage, un seul bouton, aucune couleur" do
    session = create_exercise_session(student: @student, exercise: @exercise)
    visit exercise_session_path(session.public_id)

    assert_selector ".exam-sheet #exam-header", text: "Interrogation"
    assert_selector "h1", count: 1, text: "Méiose"
    assert_selector "#exam-instructions", text: "2 questions"
    assert_no_selector "#exam-instructions", text: "barème"
    assert_no_selector "#exam-instructions", text: /minutes|tentative/i
    assert_text I18n.t("assessment.exercise_sessions.show.lock_warning")
    assert_button I18n.t("assessment.exercise_sessions.show.submit"), count: 1
    assert_achromatic
    assert_no_overflow
  end

  test "la consigne donne le barème dès qu'une question ne vaut pas 1 point" do
    @questions.first.update!(points: 2)
    session = create_exercise_session(student: @student, exercise: @exercise)
    visit exercise_session_path(session.public_id)

    assert_selector "#exam-instructions", text: "2 questions"
    assert_no_selector "#exam-instructions", text: "barème"
  end

  test "le résultat : « Juste » et « Faux » en texte, aucune couleur" do
    session = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 50)
    @questions.each_with_index { |question, index| create_attempt(session:, question:, correct: index.zero?) }

    visit exercise_session_result_path(session.public_id)
    click_on I18n.t("components.reveal.more") if page.has_button?(I18n.t("components.reveal.more"), wait: 1)

    assert_selector ".exam-sheet .sheet-cahier"
    assert_selector "#session_review", text: I18n.t("assessment.session_results.show.correct")
    assert_selector "#session_review", text: I18n.t("assessment.session_results.show.wrong")
    assert_achromatic
    assert_no_overflow
  end

  private

  def assert_achromatic
    assert_selector "head link[href*='exam_sheet']", visible: false
    assert_equal PAPER, page.evaluate_script("getComputedStyle(document.querySelector('.sheet-cahier')).backgroundColor")
    # Garde-fou : le détecteur voit bien une couleur chromatique, et les variables du thème sont neutralisées.
    page.execute_script("const d = document.createElement('i'); d.id = 'canary'; d.style.color = 'rgb(200, 30, 30)'; document.querySelector('.exam-sheet').append(d)")
    assert_not_empty page.evaluate_script(CHROMA_SCRIPT)
    page.execute_script("document.getElementById('canary').remove()")
    assert_equal "#1a1a1a", page.evaluate_script("getComputedStyle(document.querySelector('.exam-sheet')).getPropertyValue('--color-brand').trim()")
    assert_empty page.evaluate_script(CHROMA_SCRIPT), "couleur chromatique dans la feuille"
  end

  def assert_no_overflow
    [ [ 375, 900 ], [ 768, 900 ], [ 1280, 900 ] ].each do |size|
      page.current_window.resize_to(*size)
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "défilement horizontal à #{size.first} px"
    end
  end
end
