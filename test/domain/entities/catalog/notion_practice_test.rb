require "test_helper"

# ADR-0119 entraînement de notion corrigé sans trace (§4, §6) : la forme de `practice`, son empreinte, sa copie sans correction.
module Entities
  module Catalog
    class NotionPracticeTest < ActiveSupport::TestCase
      def question(**changes)
        { "content" => "AN (cm) = ___", "question_type" => "numeric", "unit" => "cm", "tolerance" => 0.01,
          "hint" => "Écris l'égalité des trois rapports.", "explanation" => "AN = AC × AM / AB = 4,8 cm, par le théorème de Thalès.",
          "answers" => [ { "content" => "4,8", "correct" => true, "blank" => 0 } ] }.merge(changes.stringify_keys)
      end

      def choice(**changes)
        { "content" => "Combien font 2 + 2 ?", "question_type" => "single_choice",
          "explanation" => "On additionne les deux termes : 2 + 2 = 4, la bonne réponse est donc 4.",
          "answers" => [ { "content" => "4", "correct" => true }, { "content" => "5", "correct" => false } ] }.merge(changes.stringify_keys)
      end

      def raw(**changes) = { "statement" => "Les droites (MN) et (BC) sont parallèles.", "questions" => [ question, choice ] }.merge(changes.stringify_keys)

      def paths(errors) = errors.map { it.first(2) }

      test "un entraînement de la fabrique n'a aucune erreur" do
        assert_empty NotionPractice.errors_for(raw)
      end

      test "from_raw construit des questions d'évaluation dont l'identifiant est la position" do
        practice = NotionPractice.from_raw(raw)

        assert_equal "Les droites (MN) et (BC) sont parallèles.", practice.statement
        assert_equal [ 0, 1 ], practice.questions.map(&:id)
        assert_kind_of Assessment::Question, practice.questions.first
        assert_equal "Écris l'égalité des trois rapports.", practice.questions.first.hint
        assert_equal 0, practice.questions.first.answers.first.blank
        assert_equal 16, practice.digest.length
      end

      test "from_raw d'une valeur qui n'est pas un objet rend nil" do
        assert_nil NotionPractice.from_raw(nil)
        assert_nil NotionPractice.from_raw("texte")
      end

      test "ce qui n'est pas un objet est refusé sans lever" do
        assert_equal [ [ "$", "schema" ] ], paths(NotionPractice.errors_for("texte"))
        assert_equal [ [ "$", "schema" ] ], paths(NotionPractice.errors_for([]))
      end

      test "de 1 à 6 questions" do
        assert_equal [ [ "questions", "invalid_count" ] ], paths(NotionPractice.errors_for(raw(questions: [])))
        assert_equal [ [ "questions", "invalid_count" ] ], paths(NotionPractice.errors_for(raw(questions: nil)))
        assert_equal [ [ "questions", "invalid_count" ] ], paths(NotionPractice.errors_for(raw(questions: Array.new(7) { choice })))
        assert_empty NotionPractice.errors_for(raw(questions: Array.new(6) { choice }))
        assert_empty NotionPractice.errors_for(raw(questions: [ choice ]))
      end

      test "points, image et criteria sont refusés : l'entraînement n'est pas noté et ne porte aucun fichier" do
        %w[points image criteria].each do |key|
          errors = NotionPractice.errors_for(raw(questions: [ question(key => "x") ]))

          assert_equal [ [ "questions[0].#{key}", "invalid_value" ] ], paths(errors), key
        end
      end

      test "chaque question suit les règles de structure des exercices notés" do
        errors = NotionPractice.errors_for(raw(questions: [ choice("answers" => [ { "content" => "4", "correct" => true } ]) ]))

        assert_equal "questions[0].answers", errors.first.first
        assert_equal "question_structure", errors.first[1]
      end

      test "un type inconnu est une valeur non valide" do
        assert_equal [ [ "questions[0].question_type", "invalid_value" ] ], paths(NotionPractice.errors_for(raw(questions: [ choice("question_type" => "poem") ])))
      end

      test "la marge ne vaut que pour un chiffré, le côté droit que pour relier" do
        assert_equal [ [ "questions[0].tolerance", "question_structure" ] ], paths(NotionPractice.errors_for(raw(questions: [ choice("tolerance" => 1) ])))
        paired = choice("answers" => [ { "content" => "4", "correct" => true, "match" => "x" }, { "content" => "5", "correct" => false } ])

        assert_equal [ [ "questions[0].answers", "question_structure" ] ], paths(NotionPractice.errors_for(raw(questions: [ paired ])))
      end

      test "les types des clés facultatives sont vérifiés sans lever" do
        wrong = choice("tolerance" => "x", "unit" => 3, "starter" => 4)

        assert_equal [ [ "questions[0].tolerance", "schema" ], [ "questions[0].unit", "schema" ], [ "questions[0].starter", "schema" ] ],
                     paths(NotionPractice.errors_for(raw(questions: [ wrong ])))
        assert_equal [ [ "questions[0].answers", "schema" ] ], paths(NotionPractice.errors_for(raw(questions: [ choice("answers" => nil) ])))
      end

      test "un énoncé ou une proposition vide est refusé" do
        blank = choice("content" => " ", "answers" => [ { "content" => "", "correct" => true }, { "content" => "5", "correct" => false } ])

        assert_includes paths(NotionPractice.errors_for(raw(questions: [ blank ]))), [ "questions[0].content", "blank" ]
        assert_includes paths(NotionPractice.errors_for(raw(questions: [ blank ]))), [ "questions[0].answers[0].content", "blank" ]
      end

      test "le corrigé est obligatoire, de 20 à 2 000 caractères" do
        assert_equal [ [ "questions[0].explanation", "blank" ] ], paths(NotionPractice.errors_for(raw(questions: [ choice("explanation" => " ") ])))
        assert_equal [ [ "questions[0].explanation", "too_short" ] ], paths(NotionPractice.errors_for(raw(questions: [ choice("explanation" => "court") ])))
        assert_equal [ [ "questions[0].explanation", "too_long" ] ], paths(NotionPractice.errors_for(raw(questions: [ choice("explanation" => "a" * 2_001) ])))
      end

      test "l'indice est facultatif et compte 500 caractères au plus" do
        assert_empty NotionPractice.errors_for(raw(questions: [ choice("hint" => "a" * 500) ]))
        assert_equal [ [ "questions[0].hint", "too_long" ] ], paths(NotionPractice.errors_for(raw(questions: [ choice("hint" => "a" * 501) ])))
        assert_equal [ [ "questions[0].hint", "schema" ] ], paths(NotionPractice.errors_for(raw(questions: [ choice("hint" => 4) ])))
      end

      test "blank est un entier de 0 à 5" do
        wrong = ->(value) { choice("answers" => [ { "content" => "4", "correct" => true, "blank" => value }, { "content" => "5", "correct" => false } ]) }

        assert_equal [ [ "questions[0].answers[0].blank", "invalid_value" ] ], paths(NotionPractice.errors_for(raw(questions: [ wrong.(6) ])))
        assert_equal [ [ "questions[0].answers[0].blank", "invalid_value" ] ], paths(NotionPractice.errors_for(raw(questions: [ wrong.(-1) ])))
        assert_equal [ [ "questions[0].answers[0].blank", "schema" ] ], paths(NotionPractice.errors_for(raw(questions: [ wrong.("0") ])))
      end

      test "l'énoncé est un texte de 1 200 caractères au plus" do
        assert_equal [ [ "statement", "too_long" ] ], paths(NotionPractice.errors_for(raw(statement: "a" * 1_201)))
        assert_equal [ [ "statement", "schema" ] ], paths(NotionPractice.errors_for(raw(statement: 3)))
        assert_empty NotionPractice.errors_for(raw.except("statement"))
      end

      test "des questions qui ne sont pas des objets ne font pas lever" do
        assert_equal [ [ "questions[0]", "schema" ] ], paths(NotionPractice.errors_for(raw(questions: [ "texte" ])))
        assert_equal [ [ "questions[0].answers", "schema" ] ], paths(NotionPractice.errors_for(raw(questions: [ choice("answers" => [ 3 ]) ])))
      end

      test "l'empreinte est stable : l'ordre des clés ne la change pas, le contenu oui" do
        reordered = raw.to_a.reverse.to_h.merge("questions" => raw["questions"].map { it.to_a.reverse.to_h })

        assert_equal NotionPractice.from_raw(raw).digest, NotionPractice.from_raw(reordered).digest
        assert_equal NotionPractice.from_raw(raw).digest, NotionPractice.from_raw(JSON.parse(raw.to_json)).digest
        refute_equal NotionPractice.from_raw(raw).digest, NotionPractice.from_raw(raw(statement: "Autre")).digest
        assert_match(/\A\h{16}\z/, NotionPractice.from_raw(raw).digest)
      end

      test "without_correction ne garde ni correct, ni explication, ni réponses saisies" do
        shown = NotionPractice.from_raw(raw).without_correction
        number, pick = shown.questions

        assert_empty number.answers, "un chiffré perd sa valeur attendue"
        assert_nil number.explanation
        assert_equal "Écris l'égalité des trois rapports.", number.hint, "l'indice n'est pas une réponse"
        assert_equal %w[4 5], pick.answers.map(&:content), "un QCM garde le texte de ses propositions"
        assert_equal [ nil, nil ], pick.answers.map(&:correct)
        assert_nil pick.explanation
        assert_equal NotionPractice.from_raw(raw).digest, shown.digest
      end

      test "without_correction vide aussi un texte à trous et un rédigé, et garde les options d'une liste" do
        fill = { "content" => "Le triangle est ___.", "question_type" => "fill_blank", "explanation" => "Il a un angle droit : il est rectangle, donc ABC l'est.",
                 "answers" => [ { "content" => "rectangle", "correct" => true } ] }
        select = { "content" => "Il est ___.", "question_type" => "select", "explanation" => "Il a un angle droit : il est rectangle, donc ABC l'est.",
                   "answers" => [ { "content" => "rectangle", "correct" => true }, { "content" => "isocèle", "correct" => false } ] }
        shown = NotionPractice.from_raw(raw(questions: [ fill, select ])).without_correction

        assert_empty shown.questions.first.answers
        assert_equal %w[rectangle isocèle], shown.questions.last.answers.map(&:content)
        assert_equal [ nil, nil ], shown.questions.last.answers.map(&:correct)
      end
    end
  end
end
