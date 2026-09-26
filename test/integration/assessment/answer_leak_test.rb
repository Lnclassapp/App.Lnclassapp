require "test_helper"

# TR-cadre-3, AS-39, sécurité n° 29. L'ancienne application mettait en cache la liste des questions avec une clé qui ne
# dépendait que de la question : l'élève qui passait après un enseignant recevait les bonnes réponses cochées. Ici, sous
# cache de fragments actif, l'équipe puis l'enseignant affichent l'exercice avec ses propositions correctes marquées ;
# l'élève qui passe ensuite ne reçoit ni la marque, ni l'identifiant d'une proposition correcte, ni une explication.
class Assessment::AnswerLeakTest < ActionDispatch::IntegrationTest
  setup do
    @exercise = create_exercise(title: "Méiose")
    @exercise.questions.each { it.update!(explanation: "Explication de la question #{it.position}.") }
    @correct_ids = Orm::Answer.where(question: @exercise.questions, correct: true).pluck(:id)
    @mark = I18n.t("assessment.exercises.questions_preview.correct")
  end

  def show_exercise_as(user)
    sign_in_as user
    get exercise_path(@exercise.public_id)
    assert_response :success
    response.body.tap { sign_out }
  end

  test "l'équipe, puis l'enseignant, voient les propositions correctes ; l'élève qui suit n'en reçoit aucune trace" do
    with_fragment_caching do
      [ create_team_member, create_teacher ].each do |user|
        html = show_exercise_as(user)

        assert_equal @correct_ids.size, html.scan(@mark).size, "#{user.role} doit voir chaque proposition correcte marquée"
        @correct_ids.each { |id| assert_includes html, %(id="answer_#{id}") }
        assert_includes html, "Explication de la question 1."
      end

      html = show_exercise_as(create_student)

      assert_includes html, "Méiose"
      assert_includes html, "Proposition 1"
      assert_not_includes html, @mark
      assert_no_match(/data-correct|Explication de la question/, html)
      @correct_ids.each { |id| assert_no_match(/answer_#{id}\b|value="#{id}"|data-answer-id="#{id}"/, html) }
    end
  end
end
