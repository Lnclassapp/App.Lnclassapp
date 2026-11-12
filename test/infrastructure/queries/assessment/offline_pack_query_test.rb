require "test_helper"

# hors-connexion Lot B (ADR §4.4, menace C3) — le paquet de corrigé : questions avec bonnes réponses, ordre d'affichage, empreinte stable.
class Queries::Assessment::OfflinePackQueryTest < ActiveSupport::TestCase
  setup do
    @exercise = create_exercise(questions: 1)
    @exercise.questions.first.update!(explanation: "Parce que.", points: 2)
    create_kind_question(exercise: @exercise, question_type: "numeric", answers: [ "4.8" ], numeric_tolerance: "0.5", content: "Mesure ?")
    @exercise.questions.order(:position).last.update!(unit: "cm")
    create_kind_question(exercise: @exercise, question_type: "ordering", answers: %w[Un Deux Trois], content: "Ordonne")
    @query = Queries::Assessment::OfflinePackQuery.new
  end

  test "le paquet porte les questions avec leurs bonnes réponses, explications, points, unité et marge" do
    pack = @query.call(public_id: @exercise.public_id)

    assert_equal @exercise.public_id, pack.exercise_public_id
    assert_equal 3, pack.questions.size
    choice = pack.questions.first
    assert_equal "choice", choice[:kind]
    assert_equal "Parce que.", choice[:explanation]
    assert_equal "2.0", choice[:points]
    assert_equal [ true, false, false, false ], choice[:answers].pluck(:correct)
    numeric = pack.questions.second
    assert_equal "cm", numeric[:unit]
    assert_equal "0.5", numeric[:numeric_tolerance]
    assert_equal [ "4.8" ], numeric[:answers].pluck(:content)
  end

  test "l'ordre d'affichage est celui du mélange de l'exercice, sans jamais donner la solution d'un ordre" do
    pack = @query.call(public_id: @exercise.public_id)

    choice, _numeric, ordering = pack.questions
    ids = @exercise.questions.find(choice[:id]).answers.order(:position, :id).pluck(:id)
    shuffled = Entities::Assessment::AnswerShuffle.for(session_id: @exercise.id, question_id: choice[:id], ids:)
    assert_equal shuffled.map { ids.index(it) }, choice[:display]
    solution = ordering[:answers].each_index.to_a
    assert_equal solution, ordering[:display].sort
    assert_not_equal solution, ordering[:display]
  end

  test "le paquet ne porte aucun identifiant de proposition : des rangs locaux" do
    pack = @query.call(public_id: @exercise.public_id)

    assert(pack.questions.all? { |question| question[:answers].none? { it.key?(:id) } })
    assert(pack.questions.all? { |question| question[:display].nil? || question[:display].all? { it.between?(0, question[:answers].size - 1) } })
  end

  test "l'empreinte tient en 16 hexadécimaux, ne change pas d'un appel à l'autre et change quand une question change" do
    first = @query.call(public_id: @exercise.public_id)
    second = @query.call(public_id: @exercise.public_id)
    assert_match(/\A\h{16}\z/, first.digest)
    assert_equal first.digest, second.digest

    @exercise.questions.order(:position).first.update!(content: "Autre énoncé")
    assert_not_equal first.digest, @query.call(public_id: @exercise.public_id).digest
  end

  test "l'empreinte ne dépend pas de l'ordre des clés" do
    assert_equal Queries::Assessment::OfflinePackQuery.digest([ { "b" => 1, "a" => [ { "d" => 1, "c" => 2 } ] } ]),
                 Queries::Assessment::OfflinePackQuery.digest([ { "a" => [ { "c" => 2, "d" => 1 } ], "b" => 1 } ])
  end

  test "la feuille de la copie hors ligne ne porte aucune bonne réponse ni explication, sans session" do
    sheet = @query.sheet(public_id: @exercise.public_id)

    assert_nil sheet.session_public_id
    assert_equal 3, sheet.questions.size
    serialized = sheet.questions.map(&:to_h).to_s
    assert_not_includes serialized, "Parce que."
    assert_not_includes serialized, "4.8"
    assert_equal [ 0, 1, 2, 3 ], sheet.questions.first.answers.map(&:index).sort
    assert(sheet.questions.all? { |question| question.answers.all? { it.id.nil? } })
  end

  test "un exercice absent rend nil" do
    assert_nil @query.call(public_id: "absent")
    assert_nil @query.sheet(public_id: "absent")
  end

  test "la feuille montre, par type, les éléments dans l'ordre d'affichage du paquet, sans identifiant ni solution" do
    matching = create_kind_question(exercise: @exercise, question_type: "matching", answers: [ %w[G1 D1], %w[G2 D2], %w[G3 D3] ], content: "Relie")
    select = create_kind_question(exercise: @exercise, question_type: "select", answers: [ "bleu" ], content: "Le ciel est ___.")
    select.answers.create!(position: 2, content: "vert", correct: false)
    written = create_kind_question(exercise: @exercise, question_type: "written", answers: [], content: "Explique", explanation: "Corrigé")
    written.update!(starter: "Je pense que")
    fill = create_kind_question(exercise: @exercise, question_type: "fill_blank", answers: [ "Abidjan" ], content: "Capitale : ___")
    image = create_question_image(question: fill, alt: "Carte")

    pack = @query.call(public_id: @exercise.public_id)
    sheet = @query.sheet(public_id: @exercise.public_id)

    by_id = sheet.questions.index_by(&:id)
    ordering = by_id.fetch(@exercise.questions.find_by(question_type: "ordering").id)
    ordering_pack = pack.questions.find { it[:kind] == "ordering" }
    assert_equal ordering_pack[:display].map { ordering_pack[:answers][it][:content] }, ordering.items.map(&:content)
    relier = by_id.fetch(matching.id)
    assert_equal %w[G1 G2 G3], relier.prompts
    assert_equal %w[D1 D2 D3], relier.items.map(&:content).sort
    assert_equal [ 0, 1, 2 ], relier.items.map(&:index)
    assert_equal %w[bleu vert], by_id.fetch(select.id).answers.map(&:content).sort
    assert_equal "Je pense que", by_id.fetch(written.id).starter
    assert_equal image.public_id, by_id.fetch(fill.id).image.public_id
    assert_equal [ "matching" ], pack.questions.map { it[:kind] }.grep("matching")
    assert_nil pack.questions.find { it[:kind] == "written" }[:display]
  end
end
