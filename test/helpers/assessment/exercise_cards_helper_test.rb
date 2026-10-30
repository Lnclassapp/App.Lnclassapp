require "test_helper"

# UDR-0145 §3.1 : une `Card` par source de lecture, construite par un seul helper.
module Assessment
  class ExerciseCardsHelperTest < ActionView::TestCase
    helper ComponentsHelper, DueDateHelper, BadgesHelper, Catalog::ContentStatusHelper

    Home = Queries::Classroom::StudentHomeQuery
    Treated = Queries::Classroom::StudentClassroomQuery::TreatedRow
    Lesson = Queries::Catalog::PrepareInterrosQuery
    Overview = Queries::Classroom::ClassroomOverviewQuery
    Counts = Queries::Classroom::AssignmentFollowUpQuery::Counts

    def assigned(started: nil, due_on: Time.zone.today + 3, exercise_type: "fixation")
      Home::ExerciseRow.new(public_id: "ex1", title: "La fixation du CO2", material_name: "SVT", material_category: "science",
                            material_slug: "svt", exercise_type:, badge_level: nil, best_score_percent: nil, completed_count: 0,
                            started_session_public_id: started, due_on:)
    end

    def treated(score)
      Treated.new("ex2", "Les fonctions", "Maths", "maths", "science", score, "sess9", Time.current, "evaluation")
    end

    def lesson(state: nil, status: "published", exercise_type: "fixation", count: 6)
      Lesson::ExerciseRow.new(public_id: "ex3", title: "Les acides", exercise_type:, status:, questions_count: count, student_state: state)
    end

    def assignment(counts: nil, due_on: nil)
      Overview::AssignmentRow.new(public_id: "as1", exercise_title: "La méiose", material_name: "SVT", material_category: "science",
                                  due_on:, counts:, comprehension: nil, exercise_type: "evaluation", material_slug: "svt")
    end

    def state(kind, due_on: nil, score_percent: nil) = Lesson::StudentState.new(kind:, due_on:, score_percent:)

    def text(html) = Nokogiri::HTML.fragment(html.to_s).text.squish

    test "assigné non commencé : titre, SVT, Fixation, échéance, Commencer, lien vers l'exercice (CA-1)" do
      card = exercise_card_for_assigned(assigned)

      assert_equal "exercise-ex1", card.dom_id
      assert_equal exercise_path("ex1"), card.href
      assert_equal [ "La fixation du CO2", "SVT", "svt", "Fixation", "Commencer" ],
                   [ card.title, card.material_name, card.material_slug, card.type_label, card.action ]
      assert_match(/À rendre/, text(card.status))
      assert_nil card.meta
      assert_nil card.progress
    end

    test "assigné commencé : Reprendre (CA-2) ; une évaluation se dit Évaluation ; sans échéance, pas d'état" do
      card = exercise_card_for_assigned(assigned(started: "s1", due_on: nil, exercise_type: "evaluation"))

      assert_equal "Reprendre", card.action
      assert_equal "Évaluation", card.type_label
      assert_nil card.status
    end

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

    test "leçon, élève, à revoir : pastille À revoir et Revoir (CA-4)" do
      card = exercise_card_for_lesson(lesson(state: state(:to_review)), material_slug: "svt", team: false, student: true)

      assert_equal "À revoir", text(card.status)
      assert_equal "Revoir", card.action
      assert_equal "exercise-ex3", card.dom_id
      assert_equal "6 questions", card.meta
      assert_nil card.material_name
      assert_equal [ "svt", "Fixation" ], [ card.material_slug, card.type_label ]
    end

    test "leçon, élève, à rendre : échéance, Commencer" do
      card = exercise_card_for_lesson(lesson(state: state(:due, due_on: Time.zone.today + 2)), material_slug: "svt", team: false, student: true)

      assert_match(/À rendre/, text(card.status))
      assert_equal "Commencer", card.action
    end

    test "leçon, élève, note : vert dès 14/20 et Commencer ; encre sous 14/20 ; sous 10/20 : Refaire (CA-4)" do
      acquired = exercise_card_for_lesson(lesson(state: state(:score, score_percent: 70)), material_slug: "svt", team: false, student: true)
      middle = exercise_card_for_lesson(lesson(state: state(:score, score_percent: 55)), material_slug: "svt", team: false, student: true)
      low = exercise_card_for_lesson(lesson(state: state(:score, score_percent: 40)), material_slug: "svt", team: false, student: true)

      assert_equal "14/20", text(acquired.status)
      assert_includes acquired.status, "text-success"
      assert_equal "Commencer", acquired.action
      assert_includes middle.status, "text-ink"
      assert_equal "Commencer", middle.action
      assert_equal "8/20", text(low.status)
      assert_includes low.status, "text-ink"
      assert_equal "Refaire", low.action
    end

    test "leçon, élève, sans état : pas de pastille, Commencer" do
      card = exercise_card_for_lesson(lesson, material_slug: "svt", team: false, student: true)

      assert_nil card.status
      assert_equal "Commencer", card.action
    end

    test "leçon, enseignant : Voir l'exercice, sans état (CA-5)" do
      card = exercise_card_for_lesson(lesson, material_slug: "svt", team: false, student: false)

      assert_equal "Voir l'exercice", card.action
      assert_nil card.status
    end

    test "leçon, équipe : le statut éditorial et Voir l'exercice (CA-7)" do
      card = exercise_card_for_lesson(lesson(status: "draft"), material_slug: "svt", team: true, student: false)

      assert_match(/Brouillon/, text(card.status))
      assert_equal "Voir l'exercice", card.action
    end

    test "leçon : une seule question se dit au singulier" do
      card = exercise_card_for_lesson(lesson(count: 1), material_slug: "svt", team: false, student: true)

      assert_equal "1 question", card.meta
    end

    # grade_on_20 arrondit : 48 % fait déjà 10/20, 47 % fait 9/20.
    test "le seuil de Refaire est 10/20 : 48 % → Commencer, 47 % → Refaire" do
      at_ten = exercise_card_for_lesson(lesson(state: state(:score, score_percent: 48)), material_slug: "svt", team: false, student: true)
      below = exercise_card_for_lesson(lesson(state: state(:score, score_percent: 47)), material_slug: "svt", team: false, student: true)

      assert_equal [ "Commencer", "Refaire" ], [ at_ten.action, below.action ]
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
      card = exercise_card_for_lesson(lesson, material_slug: nil, team: false, student: true)

      html = Nokogiri::HTML.fragment(render(partial: "assessment/exercises/card", locals: { card: })).css("li span[aria-hidden] img")

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
