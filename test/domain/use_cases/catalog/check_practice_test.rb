require "test_helper"

module UseCases
  module Catalog
    # CA-4 (aucune ligne écrite), CA-6 (verdict par case), CA-7 (empreinte) — ADR entraînement corrigé sans trace §4. Le use case juge
    # l'entraînement d'une notion sans aucun port d'écriture.
    class CheckPracticeTest < ActiveSupport::TestCase
      Notion = Struct.new(:slug, :name, :status, :course_status, :level_id, :series_id, :practice) do
        def readable_chain_published? = status == "published" && course_status == "published"
      end

      class FakeNotions
        include Ports::Catalog::EssentialRepositoryPort

        attr_reader :asked

        def initialize(notion) = @notion = notion

        def practice_for(course_slug:, notion_slug:, statuses:)
          @asked = [ course_slug, notion_slug, statuses ]
          @notion if @notion && statuses.include?(@notion.status)
        end
      end

      Student = Data.define(:role, :user_id) do
        def student? = true
        def team? = false
      end
      Staff = Data.define(:role, :user_id) do
        def student? = false
        def team? = true
      end

      def student = Student.new(role: "student", user_id: 1)

      def audience(level_id: 3, series_id: nil) = Entities::Catalog::LevelAudience.new(pairs: [ [ level_id, series_id ] ])

      def build(*questions, status: "published", course_status: "published", level_id: 3)
        @practice = practice_of(*questions)
        @notions = FakeNotions.new(Notion.new("simplifier", "Simplifier", status, course_status, level_id, nil, @practice))
        check_practice_with(@notions)
      end

      def check(use_case, responses, actor: student, digest: @practice.digest, audience: self.audience)
        use_case.call(actor:, audience:, course_slug: "racines", notion_slug: "simplifier", digest:, responses:)
      end

      def blanks(*texts) = { "blanks" => texts.each_with_index.to_h { |text, index| [ index.to_s, text ] } }

      test "un chiffré à une case : juste, à revoir ou à compléter selon la saisie, unité comprise" do
        use_case = build(numeric_question)

        assert_equal [ :correct ], check(use_case, { "0" => blanks("4,8 cm") }).value.questions.first.verdicts
        assert_equal [ :wrong ], check(use_case, { "0" => blanks("5") }).value.questions.first.verdicts
        assert_equal [ :wrong ], check(use_case, { "0" => blanks("abc") }).value.questions.first.verdicts
        assert_equal [ :blank ], check(use_case, { "0" => blanks("  ") }).value.questions.first.verdicts
        assert_equal [ :blank ], check(use_case, {}).value.questions.first.verdicts
      end

      test "un texte à trous à une case ignore la casse et les accents" do
        use_case = build(fill_blank_question)

        assert_equal [ :correct ], check(use_case, { "0" => blanks("  HYPOTÉNUSE ") }).value.questions.first.verdicts
        assert_equal [ :wrong ], check(use_case, { "0" => blanks("cathète") }).value.questions.first.verdicts
      end

      test "un choix unique est jugé sur l'indice d'affichage posté, jamais sur l'identifiant" do
        use_case = build(choice_question)
        question = @practice.questions.first
        right = display_index(@practice, question, 0)
        wrong = display_index(@practice, question, 1)

        assert_equal [ :correct ], check(use_case, { "0" => { "ids" => [ right.to_s ] } }).value.questions.first.verdicts
        assert_equal [ :wrong ], check(use_case, { "0" => { "ids" => [ wrong.to_s ] } }).value.questions.first.verdicts
        assert_equal [ :wrong ], check(use_case, { "0" => { "ids" => [ "99" ] } }).value.questions.first.verdicts
        assert_equal [ :blank ], check(use_case, { "0" => { "ids" => [] } }).value.questions.first.verdicts
      end

      test "remettre dans l'ordre : juste seulement dans le bon ordre, à compléter si un rang est vide" do
        use_case = build(ordering_question)
        question = @practice.questions.first
        good = question.ids_by_position.map { display_index(@practice, question, it).to_s }

        assert_equal [ :correct ], check(use_case, { "0" => { "order" => good } }).value.questions.first.verdicts
        assert_equal [ :wrong ], check(use_case, { "0" => { "order" => good.reverse } }).value.questions.first.verdicts
        assert_equal [ :wrong ], check(use_case, { "0" => { "order" => [ "0", "0", "0" ] } }).value.questions.first.verdicts
        assert_equal [ :blank ], check(use_case, { "0" => { "order" => [ good[0], "", good[2] ] } }).value.questions.first.verdicts
      end

      test "relier : chaque élément de gauche relié au sien" do
        use_case = build(matching_question)
        question = @practice.questions.first
        good = question.ids_by_position.map { display_index(@practice, question, it).to_s }

        assert_equal [ :correct ], check(use_case, { "0" => { "order" => good } }).value.questions.first.verdicts
        assert_equal [ :wrong ], check(use_case, { "0" => { "order" => good.rotate } }).value.questions.first.verdicts
      end

      test "une réponse rédigée n'a pas de verdict mais un corrigé" do
        result = check(build(written_question), { "0" => { "text" => "Parce que..." } }).value.questions.first

        assert_equal [], result.verdicts
        assert_equal PracticeHelper::EXPLANATION, result.explanation
      end

      test "le corrigé donne la bonne réponse de chaque case et l'explication" do
        result = check(build(numeric_question, choice_question), {}).value

        assert_equal [ "4,8 cm" ], result.questions.first.expected
        assert_equal [ "7" ], result.questions.last.expected
        assert_equal [ 1, 2 ], result.questions.map(&:number)
      end

      test "le bilan : tout juste, à revoir, ou à compléter" do
        use_case = build(numeric_question, fill_blank_question)

        assert_equal :all_correct, check(use_case, { "0" => blanks("4,8"), "1" => blanks("hypoténuse") }).value.status
        assert_equal :some_wrong, check(use_case, { "0" => blanks("4,8"), "1" => blanks("x") }).value.status
        assert_equal :incomplete, check(use_case, { "0" => blanks("4,8") }).value.status
        assert_equal :some_wrong, check(use_case, { "0" => blanks("1"), "1" => blanks("") }).value.status
      end

      test "CA-7: une empreinte qui n'est plus celle de la notion est un conflit, rien n'est jugé" do
        use_case = build(numeric_question)

        result = check(use_case, { "0" => blanks("4,8") }, digest: "0000000000000000")

        assert_equal :conflict, result.code
      end

      test "une notion introuvable, brouillon pour un élève, ou une leçon non publiée est refusée sans rien révéler" do
        assert_equal :not_found, check(build(numeric_question, status: "draft"), {}).code
        assert_equal :not_found, check(build(numeric_question, course_status: "draft"), {}).code
        missing = check_practice_with(FakeNotions.new(nil))
        assert_equal :not_found, missing.call(actor: student, audience:, course_slug: "x", notion_slug: "y", digest: "a", responses: {}).code
      end

      test "un élève d'un autre niveau reçoit not_found" do
        assert_equal :not_found, check(build(numeric_question), {}, audience: audience(level_id: 99)).code
      end

      test "l'équipe lit aussi les brouillons" do
        use_case = build(numeric_question, status: "draft", course_status: "draft")
        staff = Staff.new(role: "team", user_id: 2)

        assert check(use_case, {}, actor: staff, audience: nil).success?
        assert_includes @notions.asked.last, "draft"
      end

      test "CA-4: aucune ligne n'est écrite, et le use case n'a aucun port d'écriture" do
        use_case = check_practice_with(Repositories::Catalog::EssentialRepository.new)
        course = create_course(level: create_level(name: "3ème", position: 4))
        practice = Entities::Catalog::NotionPractice.from_raw(raw_practice(numeric_question))
        create_essential(course:, name: "Simplifier",
                         sheet: { "remember" => "a", "method" => [ "b" ], "example" => {}, "pitfall" => "c", "practice" => raw_practice(numeric_question) })
        tables = ActiveRecord::Base.connection.tables - %w[schema_migrations ar_internal_metadata]
        counts = -> { tables.to_h { [ it, ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{it}") ] } }
        before = counts.call

        result = use_case.call(actor: student, audience: Entities::Catalog::LevelAudience.new(pairs: [ [ course.level_id, nil ] ]),
                               course_slug: course.slug, notion_slug: Orm::Essential.last.slug, digest: practice.digest,
                               responses: { "0" => blanks("4,8") })

        assert result.success?, result.errors.inspect
        assert_equal before, counts.call
        assert_equal %i[notions policy level_policy], CheckPractice.instance_method(:initialize).parameters.map(&:last), "aucun port d'écriture injecté"
      end

      test "plusieurs cases : un verdict par case" do
        use_case = build(two_blank_numeric_question)

        assert_equal [ :correct, :wrong ], check(use_case, { "0" => blanks("4,8 cm", "5") }).value.questions.first.verdicts
        assert_equal [ :correct, :blank ], check(use_case, { "0" => blanks("4,8", "") }).value.questions.first.verdicts
        assert_equal :some_wrong, check(use_case, { "0" => blanks("4,8", "5") }).value.status
        assert_equal [ "4,8 cm", "3 cm" ], check(use_case, {}).value.questions.first.expected
      end

      test "une liste laissée vide, illisible ou hors bornes est une case à compléter, jamais une exception" do
        [ 1, 2 ].each do |blanks|
          use_case = build(select_question(blanks:))

          [ "", "abc", "99", "-1", " " ].each do |value|
            given = { "blanks" => (0...blanks).to_h { [ it.to_s, value ] } }
            verdicts = check(use_case, { "0" => given }).value.questions.first.verdicts

            assert_equal Array.new(blanks, :blank), verdicts, "#{blanks} case(s), saisie #{value.inspect}"
          end
        end
      end

      # Les propositions d'un entraînement à listes : leurs indices d'affichage, par identifiant (0 : juste de la case 0, 1 : faux, 2 : juste de la case 1, 3 : faux).
      def picks(*ids) = ids.each_with_index.to_h { |id, blank| [ blank.to_s, id.nil? ? "" : display_index(@practice, @practice.questions.first, id).to_s ] }

      test "une liste à une case : juste ou fausse selon la proposition choisie, sur l'indice d'affichage posté" do
        use_case = build(select_question)

        assert_equal [ :correct ], check(use_case, { "0" => { "blanks" => picks(0) } }).value.questions.first.verdicts
        assert_equal [ :wrong ], check(use_case, { "0" => { "blanks" => picks(1) } }).value.questions.first.verdicts
        assert_equal [ :blank ], check(use_case, { "0" => { "blanks" => "x" } }).value.questions.first.verdicts
      end

      test "des listes à plusieurs cases : un verdict par case, une case laissée vide est à compléter" do
        use_case = build(select_question(blanks: 2))

        assert_equal [ :correct, :correct ], check(use_case, { "0" => { "blanks" => picks(0, 2) } }).value.questions.first.verdicts
        assert_equal [ :correct, :wrong ], check(use_case, { "0" => { "blanks" => picks(0, 3) } }).value.questions.first.verdicts
        assert_equal [ :wrong, :blank ], check(use_case, { "0" => { "blanks" => picks(1, nil) } }).value.questions.first.verdicts
      end

      test "une saisie qui n'est pas un ensemble de réponses, un choix ou un ordre illisible sont jugés sans exception" do
        assert_equal [ :blank ], check(build(numeric_question), nil).value.questions.first.verdicts
        assert_equal [ :wrong ], check(build(choice_question), { "0" => { "ids" => [ "abc" ] } }).value.questions.first.verdicts
        assert_equal [ :wrong ], check(build(ordering_question), { "0" => { "order" => [ "a", "b", "c" ] } }).value.questions.first.verdicts
      end

      test "une bonne réponse écrite is_correct est reconnue comme correct" do
        raw = choice_question.merge("answers" => [ { "content" => "7", "is_correct" => true }, { "content" => "8", "is_correct" => false } ])
        question = Entities::Catalog::NotionPractice.from_raw(raw_practice(raw)).questions.first

        assert_equal [ true, false ], question.answers.map(&:correct)

        use_case = build(raw)
        right = display_index(@practice, @practice.questions.first, 0)

        assert_equal [ :correct ], check(use_case, { "0" => { "ids" => [ right.to_s ] } }).value.questions.first.verdicts
      end
    end
  end
end
