# Fills and hands in a copy in the browser (UDR-0138): on the copy page of a started session, the first `rights` questions get
# « Proposition 1 » (the right one, factory create_exercise), the others « Proposition 2 ». → the session public_id.
module SystemCopyHelper
  ActionDispatch::SystemTestCase.include(self)

  COPY_WAIT = 10

  def hand_in_copy(rights:, questions:)
    assert_current_path %r{\A/sessions/[^/]+\z}, wait: COPY_WAIT
    public_id = current_path.split("/").last
    questions.times { |index| within("#question-#{index + 1}") { choose(index < rights ? "Proposition 1" : "Proposition 2") } }
    click_on I18n.t("assessment.exercise_sessions.show.submit")
    assert_current_path exercise_session_result_path(public_id), wait: COPY_WAIT
    public_id
  end
end
