require "test_helper"

# UDR-0145 §3.1 : une `Card` par source de lecture, construite par un seul helper.
module Assessment
  class ExerciseCardsHelperTest < ActionView::TestCase
    helper ComponentsHelper, DueDateHelper, BadgesHelper, Catalog::ContentStatusHelper

    Treated = Queries::Classroom::StudentClassroomQuery::TreatedRow
    Overview = Queries::Classroom::ClassroomOverviewQuery
    Counts = Queries::Classroom::AssignmentFollowUpQuery::Counts

    def treated(score)
      Treated.new("ex2", "Les fonctions", "Maths", "maths", "science", score, "sess9", Time.current, "evaluation")
    end

    def assignment(counts: nil, due_on: nil)
      Overview::AssignmentRow.new(public_id: "as1", exercise_title: "La méiose", material_name: "SVT", material_category: "science",
                                  due_on:, counts:, comprehension: nil, exercise_type: "evaluation", material_slug: "svt")
    end

    def text(html) = Nokogiri::HTML.fragment(html.to_s).text.squish

    test "traité à 16/20 : note verte, Acquis, Voir ma copie vers le résultat (CA-3)" do
      card = exercise_card_for_treated(treated(80))

      assert_nil card.dom_id
      assert_equal exercise_session_result_path("sess9"), card.href
      assert_equal "Voir ma copie", card.action
      assert_equal "16/20 · Acquis", text(card.status)
      assert_includes card.status, "text-success"
      assert_equal [ "Maths", "maths", "Évaluation" ], [ card.material_name, card.material_slug, card.type_label ]
    end

    test "traité à 13/20 : note en encre, jamais verte ; en difficulté sous 10/20" do
      assert_includes exercise_card_for_treated(treated(67)).status, "text-ink"
      assert_not_includes exercise_card_for_treated(treated(67)).status, "text-success"
      assert_equal "4/20 · En difficulté", text(exercise_card_for_treated(treated(20)).status)
    end

    test "traité à 70 % : 14/20 en vert" do
      assert_includes exercise_card_for_treated(treated(70)).status, "text-success"
    end

    test "assignation suivie, en retard : date absolue, N en retard, progression, Voir le suivi (CA-6)" do
      card = exercise_card_for_assignment(assignment(counts: Counts.new(done: 20, late: 0, pending: 7), due_on: Time.zone.today - 2),
                                          classroom_public_id: "cl1")

      assert_equal "assignment_as1", card.dom_id
      assert_equal classroom_assignment_path("cl1", "as1"), card.href
      assert_equal "Voir le suivi", card.action
      assert_equal [ 20, 27 ], card.progress
      assert_match(/Pour .*7 en retard/, text(card.status))
      assert_equal [ "SVT", "svt", "Évaluation" ], [ card.material_name, card.material_slug, card.type_label ]
    end

    test "assignation suivie, pas encore échue : N pas encore ; tous l'ont fait : rien de plus que la date" do
      pending = exercise_card_for_assignment(assignment(counts: Counts.new(done: 1, late: 0, pending: 2), due_on: Time.zone.today + 4),
                                             classroom_public_id: "cl1")
      done = exercise_card_for_assignment(assignment(counts: Counts.new(done: 3, late: 0, pending: 0)), classroom_public_id: "cl1")

      assert_match(/2 pas encore/, text(pending.status))
      assert_equal "Sans date limite", text(done.status)
    end

    test "une ligne sans type lève : un type manquant ne se tait pas" do
      row = assignment.with(exercise_type: nil)

      assert_raises(ArgumentError) { exercise_card_for_assignment(row, classroom_public_id: "cl1") }
    end

    test "chaque type de question et d'exercice a son libellé en français" do
      Entities::Assessment::Question::TYPES.each do |type|
        assert I18n.exists?("assessment.exercises.show.question_formats.#{type}", :fr), type
      end
      Entities::Assessment::Exercise::TYPES.each do |type|
        assert I18n.exists?("assessment.exercises.show.exercise_types.#{type}", :fr), type
      end
    end

    test "une carte montre toujours une illustration, de repli sans matière connue" do
      card = exercise_card_for_treated(treated(70).with(material_slug: nil))

      html = Nokogiri::HTML.fragment(render(partial: "assessment/exercises/card", locals: { card: })).css("span[aria-hidden] img")

      assert_equal 1, html.size
    end

    test "assignation sans droit de suivi : ni lien, ni action, ni progression" do
      card = exercise_card_for_assignment(assignment, classroom_public_id: "cl1")

      assert_nil card.href
      assert_nil card.action
      assert_nil card.progress
      assert_equal "Sans date limite", text(card.status)
    end
  end
end
