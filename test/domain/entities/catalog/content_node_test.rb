require "test_helper"
require_relative "../../../support/domain/taxonomy_fixture"

module Entities
  module Catalog
    class ContentNodeTest < ActiveSupport::TestCase
      setup { @lookup = TaxonomyFixture.lookup }

      def answers(*flags) = flags.map { |correct| { "content" => "p", "is_correct" => correct } }

      def question(type = "single_choice", answers: answers(true, false))
        { "content" => "Question ?", "question_type" => type, "answers" => answers }
      end

      def exercise(**overrides)
        { "title" => "Mitose", "exercise_type" => "fixation", "questions" => [ question ] }.merge(overrides)
      end

      def course(**overrides)
        { "name" => "Génétique", "level_name" => "Tle", "series_name" => "D", "material_name" => "Physique Chimie",
          "status" => "publié", "essentials" => [ { "name" => "ADN", "exercises" => [ exercise ] } ] }.merge(overrides)
      end

      def codes(errors) = errors.map { [ it.path, it.code ] }

      test "un exercice : au moins une question, cohérence de l'ADR-0039" do
        assert_empty ContentNode.validate_exercise(exercise("questions" => [ question("true_false"), question("multiple_correct_2", answers: answers(true, true, false)) ]), path: "e")
        assert_equal [ [ "e.questions", "blank" ] ], codes(ContentNode.validate_exercise(exercise("questions" => nil), path: "e"))

        errors = ContentNode.validate_exercise(exercise("questions" => [ question("true_false", answers: answers(true, false, false)),
                                                                         question("essay"), { "question_type" => "single_choice", "answers" => [ { "content" => "", "correct" => true }, { "content" => "b", "correct" => false } ] } ]),
                                               path: "exercises[1]")

        assert_equal [ [ "exercises[1].questions[0].answers", "question_structure" ], [ "exercises[1].questions[1].question_type", "invalid_value" ],
                       [ "exercises[1].questions[2].content", "blank" ], [ "exercises[1].questions[2].answers[0].content", "blank" ] ], codes(errors)
        assert_equal({ rule: :true_false_needs_two_answers }, errors.first.params)
      end

      test "une leçon : nom obligatoire, sous-titre facultatif, niveau, matière et série du référentiel" do
        lesson = ->(**changes) { { "name" => "Racines", "level_name" => "Tle", "material_name" => "Physique-Chimie" }.merge(changes.stringify_keys) }

        assert_equal [ [ "l", "schema" ] ], codes(ContentNode.validate_lesson("x", path: "l", lookup: @lookup))
        assert_empty ContentNode.validate_lesson(lesson.call, path: "l", lookup: @lookup)
        assert_empty ContentNode.validate_lesson(lesson.call(subtitle: "  ", series_name: "D"), path: "l", lookup: @lookup)
        assert_equal [ [ "l.subtitle", "too_long" ] ], codes(ContentNode.validate_lesson(lesson.call(subtitle: "a" * 500), path: "l", lookup: @lookup))
        assert_equal [ [ "l.name", "blank" ], [ "l.level_name", "unknown_level" ], [ "l.material_name", "unknown_material" ] ],
                     codes(ContentNode.validate_lesson({ "name" => " " }, path: "l", lookup: @lookup))
      end

      test "une série facultative doit exister et être liée au niveau" do
        lesson = ->(level, series) { { "name" => "Racines", "level_name" => level, "material_name" => "Physique-Chimie", "series_name" => series } }
        errors = ->(level, series) { ContentNode.validate_lesson(lesson.call(level, series), path: "l", lookup: @lookup) }

        assert_empty errors.call("Tle", "D")
        assert_equal [ [ "l.series_name", "unknown_series" ] ], codes(errors.call("Tle", "Z9"))
        assert_equal({ value: "Z9" }, errors.call("Tle", "Z9").first.params)
        assert_equal [ [ "l.series_name", "series_not_allowed" ] ], codes(errors.call("3ème", "D"))
        assert_equal({ value: "D" }, errors.call("3ème", "D").first.params)
        assert_equal [ [ "l.level_name", "unknown_level" ] ], codes(errors.call("CM2", "D"))
      end

      test "une notion qui n'est pas un objet est une erreur de schéma" do
        assert_equal [ [ "n", "schema" ] ], codes(ContentNode.validate_notion([], path: "n"))
        assert_equal [ [ "n.name", "blank" ] ], codes(ContentNode.validate_notion(revision_notion(" ").except("exercise", "figure"), path: "n"))
      end

      test "les figures de la leçon : liste, objets valides, clés uniques" do
        figure = revision_figure

        assert_empty ContentNode.validate_figures(nil, "c")
        assert_empty ContentNode.validate_figures("x", "c")
        assert_empty ContentNode.validate_figures([ figure ], "c")
        assert_equal [ [ "c.figures[1]", "figure_invalid" ] ], codes(ContentNode.validate_figures([ figure, "x" ], "c"))
        assert_equal [ [ "c.figures[1].key", "figure_invalid" ] ], codes(ContentNode.validate_figures([ figure, figure ], "c"))
        assert_equal({ param: "key" }, ContentNode.validate_figures([ figure, figure ], "c").first.params)
        assert_equal [ [ "c.figures[0].description", "figure_invalid" ] ], codes(ContentNode.validate_figures([ figure.merge("description" => "court") ], "c"))
      end

      test "une figure citée doit être dans la leçon" do
        assert_empty ContentNode.validate_figure_citation(nil, [], "p")
        assert_empty ContentNode.validate_figure_citation("", [], "p")
        assert_empty ContentNode.validate_figure_citation("a", [ "a" ], "p")
        assert_equal [ [ "p", "figure_missing" ] ], codes(ContentNode.validate_figure_citation("b", [ "a" ], "p"))
        assert_equal({ key: "b" }, ContentNode.validate_figure_citation("b", [ "a" ], "p").first.params)
      end

      test "un exercice v3 qui n'est pas un objet est une erreur de schéma, une question qui n'en est pas une est signalée une fois" do
        assert_equal [ [ "e", "schema" ] ], codes(ContentNode.validate_exercise_v3(nil, path: "e"))
        questions = Array.new(5) { question } + [ "q" ]
        errors = ContentNode.validate_exercise_v3(exercise("questions" => questions.map { it.is_a?(Hash) ? it.merge("explanation" => "a" * 25) : it }), path: "e")

        assert_equal [ [ "e.questions[5]", "schema" ] ], codes(errors)
      end

      test "le sujet en blocs : forme de la liste, type inconnu, règle d'un bloc" do
        errors = ->(blocks) { ContentNode.validate_exercise(exercise("statement_blocks" => blocks), path: "e") }

        assert_empty errors.call(nil)
        assert_equal [ [ "e.statement_blocks", "schema" ] ], codes(errors.call("paragraph"))
        assert_equal [ [ "e.statement_blocks[0].type", "invalid_value" ] ], codes(errors.call([ { "type" => "iframe" } ]))
        assert_equal({ value: "iframe" }, errors.call([ { "type" => "iframe" } ]).first.params)
        bad = errors.call([ { "type" => "paragraph", "text" => "ok" }, { "type" => "paragraph", "text" => "<b>x</b>" } ])
        assert_equal [ [ "e.statement_blocks[1]", "invalid_value" ] ], codes(bad)
        assert_equal({ value: "html_forbidden : text" }, bad.first.params)
      end

      test "points, unité, amorce et critères d'une question doivent avoir la forme du schéma" do
        errors = ->(**changes) { ContentNode.validate_exercise(exercise("questions" => [ question.merge(changes.stringify_keys) ]), path: "e") }

        assert_empty errors.call(question_type: "numeric", answers: [ { "content" => "4,5", "correct" => true } ], points: 2, unit: "cm")
        assert_empty errors.call(question_type: "written", answers: [], explanation: "Un corrigé type assez long.", starter: "Je pense que", criteria: [ "clarté" ])
        assert_equal [ [ "e.questions[0].points", "schema" ] ], codes(errors.call(points: "deux"))
        assert_equal [ [ "e.questions[0].points", "schema" ] ], codes(errors.call(points: Float::INFINITY))
        assert_equal [ [ "e.questions[0].unit", "schema" ], [ "e.questions[0].starter", "schema" ] ], codes(errors.call(unit: 5, starter: [ "x" ]))
        assert_equal [ [ "e.questions[0].criteria", "schema" ] ], codes(errors.call(criteria: "clarté"))
        assert_equal [ [ "e.questions[0].criteria", "schema" ] ], codes(errors.call(criteria: [ 1 ]))
      end

      test "la description de l'image d'une question ne peut pas être faite d'espaces" do
        errors = ->(image) { ContentNode.validate_exercise(exercise("questions" => [ question.merge("image" => image) ]), path: "e") }

        assert_empty errors.call(nil)
        assert_empty errors.call("description" => "Un schéma de la cellule")
        assert_equal [ [ "e.questions[0].image.description", "blank" ] ], codes(errors.call("description" => "   "))
      end

      test "tolerance et match sont refusés hors de leur type de question" do
        errors = ->(**changes) { ContentNode.validate_exercise(exercise("questions" => [ question.merge(changes.stringify_keys) ]), path: "e") }
        numeric = { "question_type" => "numeric", "answers" => [ { "content" => "4,5", "correct" => true } ] }
        matching = { "question_type" => "matching", "answers" => %w[a b c].each_with_index.map { |content, index| { "content" => content, "match" => (index + 1).to_s, "correct" => true } } }

        assert_equal [ [ "e.questions[0].tolerance", "question_structure" ] ], codes(errors.call(tolerance: 0.5))
        assert_equal({ rule: :tolerance_not_allowed }, errors.call(tolerance: 0.5).first.params)
        assert_empty errors.call(tolerance: nil)
        assert_empty errors.call(**numeric.symbolize_keys, tolerance: 0.5, points: 2)
        assert_empty errors.call(**matching.symbolize_keys)
        misplaced = errors.call(answers: [ { "content" => "a", "match" => "1", "is_correct" => true }, { "content" => "b", "is_correct" => false } ])
        assert_equal [ [ "e.questions[0].answers[0].match", "question_structure" ] ], codes(misplaced)
        assert_equal({ rule: :match_not_allowed }, misplaced.first.params)
      end

      test "un exercice refuse un type inconnu et nomme la valeur" do
        errors = ContentNode.validate_exercise(exercise("exercise_type" => "devoir"), path: "e")

        assert_equal [ [ "e.exercise_type", "invalid_value" ] ], codes(errors)
        assert_equal({ value: "devoir" }, errors.first.params)
      end

      test "un nœud qui n'est pas un objet est une erreur de schéma" do
        assert_equal [ [ "e", "schema" ] ], codes(ContentNode.validate_exercise([], path: "e"))
        assert_equal [ [ "e.questions[0]", "schema" ], [ "e.questions[1].answers", "schema" ] ],
                     codes(ContentNode.validate_exercise(exercise("questions" => [ "q", question(answers: [ "a" ]) ]), path: "e"))
      end
    end
  end
end
