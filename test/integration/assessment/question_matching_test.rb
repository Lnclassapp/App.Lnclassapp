require "test_helper"

# Lot G (ADR-0091 §4.4, UDR-0087) : relier de bout en bout, sans navigateur. La gauche dans l'ordre des positions, la droite
# mélangée ; la page poste, pour chaque élément de gauche, l'indice d'affichage choisi, jamais un id (CA-9). Trois paires
# justes : juste (CA-8). « Ton choix » rend les paires de l'élève. L'équipe saisit trois paires (CA-13).
class Assessment::QuestionMatchingTest < ActionDispatch::IntegrationTest
  DISTINCT_ANSWER_ID = 914_273_001
  PAIRS = [ %w[3(x+1) 3x+3], %w[2(x-4) 2x-8], %w[5(2+x) 10+5x] ].freeze

  setup do
    # Des ids de réponse qu'aucun nombre de la page ne peut valoir (position, « 1 sur 2 », tracé d'icône) : sans cela, un
    # id petit passe pour une fuite, et une vraie fuite d'un id petit passerait pour une position.
    Orm::Answer.connection.execute("ALTER SEQUENCE #{Orm::Answer.sequence_name} RESTART WITH #{DISTINCT_ANSWER_ID}")
    @exercise = create_exercise(title: "Développer", questions: 0)
    @question = create_kind_question(exercise: @exercise, question_type: "matching", answers: PAIRS, content: "Relie.")
    create_kind_question(exercise: @exercise, question_type: "matching", answers: [ %w[a 1], %w[b 2], %w[c 3] ], content: "Encore.")
    @student = create_student_for(@exercise.essential.course)
    @session = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student
  end

  # Pour chaque gauche, dans l'ordre, l'indice d'affichage de la droite voulue.
  def indices(rights)
    ids = @question.answers.order(:position).map(&:id)
    shuffled = Entities::Assessment::AnswerShuffle.for(session_id: @session.id, question_id: @question.id, ids:, avoid: ids)
    rights.map { |right| shuffled.index(ids[PAIRS.index { it.last == right }]) }
  end

  # La copie rendue d'un seul envoi (ADR-0112) : cette question seule, l'autre reste vide.
  def answer(rights, order = indices(rights)) = post(exercise_session_copy_path(@session.public_id),
                                                      params: { copy: { answers: { @question.id.to_s => { display_order: order } } } })

  test "CA-9 : la gauche dans l'ordre, la droite mélangée, une liste par élément de gauche ; aucun id ni ordre révélateur" do
    get exercise_session_path(@session.public_id)

    matching = "#question-1 "
    assert_equal PAIRS.map(&:first), css_select("#{matching}[data-assessment--matching-target=left] span.flex-1").map { it.text.strip }
    assert_equal PAIRS.map(&:last).sort, css_select("#{matching}[data-assessment--matching-target=right] span.flex-1").map { it.text.strip }.sort
    assert_select "#{matching}select[name='copy[answers][#{@question.id}][display_order][]']", 3
    answer_ids = Orm::Answer.where(question_id: @question.id).pluck(:id).map(&:to_s)
    values = css_select("#copy-form #question-1 [value]").map { it["value"] } - [ @question.id.to_s ]
    assert_empty answer_ids & values
    assert_equal [ "", "0", "1", "2" ], css_select("#{matching}select").first.css("option").map { it["value"].to_s }
  end

  test "CA-8 : trois paires justes, juste ; « Ton choix » rend les paires" do
    answer PAIRS.map(&:last)

    assert_equal [ true, @question.answers.order(:position).map(&:id) ],
                 Orm::QuestionAttempt.find_by!(question: @question).values_at(:correct, :selected_answer_ids)
    follow_redirect!
    assert_select "#question_review_#{@question.id} ul li", 3
    assert_select "#question_review_#{@question.id} li", text: /3\(x\+1\)\s*→.*3x\+3/
  end

  test "une paire fausse : faux, sans rien marquer ; un élément de gauche non relié : 422, rien n'est écrit" do
    answer PAIRS.map(&:last), [ "", "0", "1" ]
    assert_response :unprocessable_entity
    assert_equal 0, Orm::QuestionAttempt.count

    answer [ "2x-8", "3x+3", "10+5x" ]
    assert_equal false, Orm::QuestionAttempt.find_by!(question: @question).correct
    follow_redirect!
    assert_select "#question_review_#{@question.id} li", text: /3\(x\+1\)\s*→.*2x-8/
    assert_select "[data-correct]", 0
  end

  test "CA-13 : l'équipe crée un relier de trois paires, enregistré et jouable ; deux côtés droits égaux sont refusés" do
    essential = create_essential
    sign_in_as create_team_member
    params = ->(pairs) do
      { exercise: { title: "Relier", exercise_type: "fixation", questions_attributes: {
        "0" => { content: "Relie.", question_type: "matching",
                 answers_attributes: pairs.each_with_index.to_h { |(left, right), index| [ index.to_s, { content: left, match_content: right, correct: "1" } ] } }
      } } }
    end

    post teams_essential_exercises_path(essential.slug), params: params.([ %w[a 1], %w[b 1], %w[c 3] ]), as: :turbo_stream
    assert_response :unprocessable_entity

    post teams_essential_exercises_path(essential.slug), params: params.([ %w[a 1], %w[b 2], %w[c 3] ]), as: :turbo_stream
    question = Orm::Exercise.find_by!(title: "Relier").questions.sole
    assert_equal [ %w[a 1], %w[b 2], %w[c 3] ], question.answers.order(:position).pluck(:content, :match_content)
    assert_empty Repositories::Assessment::ExerciseRepository.new.find(id: question.exercise_id).questions.sole.structure_errors
  end

  # UDR-0087 §3.7 : l'aide des imports (l'import d'exercices seuls est retiré, ADR-0113) montre un exemple de chaque nouveau type, avec tolerance et match.
  test "l'aide de l'import montre les quatre nouveaux types" do
    sign_in_as create_team_member

    %w[essentials course_tree].each do |kind|
      get new_teams_import_path(kind:)
      assert_select "#import-help-question-kinds pre", 4
      assert_select "#import-help-question-kinds", text: /"tolerance": 0.1/
      assert_select "#import-help-question-kinds", text: /"match": "3x \+ 3"/
    end
  end

  test "aucun id de cette question n'apparaît dans la page, où que ce soit" do
    get exercise_session_path(@session.public_id)

    Orm::Answer.where(question_id: @question.id).pluck(:id).each { assert_no_match(/\b#{it}\b/, response.body) }
  end

  test "la correction de l'élève ne marque aucune solution" do
    answer [ "2x-8", "3x+3", "10+5x" ]
    follow_redirect!
    assert_select "[data-correct]", 0
  end
end
