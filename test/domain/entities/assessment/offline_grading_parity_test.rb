require "test_helper"

# CA-6 — hors-connexion Lot B (ADR §4.4) : le correcteur JavaScript (app/javascript/offline/grader.js) rend, pour chaque cas de la
# table partagée, le même verdict que les règles du domaine (QuestionKinds::*, Grading). Le même fichier est joué par
# test/javascript/offline/grader.test.js : un écart d'un côté casse la CI.
class Entities::Assessment::OfflineGradingParityTest < ActiveSupport::TestCase
  TABLE = JSON.parse(Rails.root.join("test/fixtures/files/offline/grading_cases.json").read)
  BLANK_KINDS = UseCases::Assessment::SubmitExerciseCopy::BLANK_KINDS

  TABLE["questions"].each do |entry|
    test "cas « #{entry["name"]} »" do
      assert_equal entry["expected"].transform_keys(&:to_s), outcome(entry["question"], entry["response"]).slice(*entry["expected"].keys),
                   "le domaine ne rend pas le verdict attendu par la table"
    end
  end

  TABLE["scores"].each do |entry|
    test "note « #{entry["name"]} »" do
      graded = entry["cases"].filter_map do |reference|
        points, name = reference.start_with?("@") ? reference.delete_prefix("@").split(":", 2) : [ nil, reference ]
        case_ = TABLE["questions"].find { it["name"] == name } or flunk("cas inconnu : #{name}")
        question = entity(case_["question"].merge("points" => points || case_["question"]["points"]))
        next unless question.auto_graded?

        [ question.points, share(question, outcome(case_["question"], case_["response"])) ]
      end

      assert_equal entry["percent"], Entities::Assessment::Grading.points_percent(graded)
    end
  end

  test "la table couvre chaque type de question" do
    assert_equal Entities::Assessment::Question::TYPES.sort, TABLE["questions"].map { it.dig("question", "question_type") }.uniq.sort
  end

  private

  def entity(raw)
    # Le paquet ne porte pas d'identifiant : le rang (indice dans answers) en tient lieu, comme dans display.
    answers = raw["answers"].each_with_index.map do |answer, rank|
      Entities::Assessment::Answer.new(id: rank, position: answer["position"], content: answer["content"], correct: answer["correct"],
                                       match_content: answer["match_content"], blank: answer["blank"])
    end
    Entities::Assessment::Question.new(id: raw["id"], position: 1, content: raw["content"], explanation: nil, question_type: raw["question_type"], answers:,
                                       numeric_tolerance: (BigDecimal(raw["numeric_tolerance"]) if raw["numeric_tolerance"]), points: BigDecimal(raw["points"]),
                                       unit: raw["unit"])
  end

  def share(question, outcome)
    return Rational(0) unless outcome["well_formed"]

    Entities::Assessment::Grading.share_of(blanks: question.blanks, correct: outcome["correct"], blank_results: outcome["blank_results"])
  end

  # Ce que SubmitExerciseCopy fait d'une réponse postée, pour une question, avec l'ordre d'affichage de la table à la place du mélange.
  def outcome(raw, response)
    question = entity(raw)
    return { "graded" => false } unless question.auto_graded?

    input = Dtos::Assessment::CopyInput.new(session_public_id: "x", answers: { question.id.to_s => response }).answers[question.id]
    return { "answered" => false, "well_formed" => nil, "blank_results" => nil, "correct" => false } if input.nil?

    given = answer_for(question, raw["display"], input)
    return { "answered" => true, "well_formed" => false, "blank_results" => nil, "correct" => false } unless input.valid? && question.well_formed?(given) && !too_long?(question, given)

    results = multi_blank?(question) ? question.blank_results(given) : [ question.correct?(given) ]
    { "answered" => true, "well_formed" => true, "blank_results" => results, "correct" => results.all? }
  end

  def multi_blank?(question) = question.blanks > 1 && BLANK_KINDS.include?(question.kind)

  def answer_for(question, display, input)
    if multi_blank?(question)
      posted = input.blanks + Array.new([ question.blanks - input.blanks.size, 0 ].max, "")
      return posted unless question.kind.equal?(Entities::Assessment::QuestionKinds::Select)

      return posted.map { |index| index.strip.empty? ? nil : (index.match?(/\A\d+\z/) && index.to_i < display.size ? display[index.to_i] : :invalid_pick) }
    end

    case question.kind::INPUT
    when :response_text then input.response_text.to_s
    when :display_order then Entities::Assessment::AnswerShuffle.pick(display, input.display_order)
    else Entities::Assessment::AnswerShuffle.select(display, input.display_order)
    end
  end

  def too_long?(question, given)
    question.kind::INPUT == :response_text && !question.kind.equal?(Entities::Assessment::QuestionKinds::Written) && given.length > Dtos::Assessment::AttemptInput::RESPONSE_TEXT_MAX
  end
end
