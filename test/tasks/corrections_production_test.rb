require "test_helper"
require "rake"

# Chantier corrections-production : le script reporte les corrections par les use cases « Modifier le texte », jamais par SQL, et ne force
# jamais une valeur qui n'est pas l'« Avant ».
class CorrectionsProductionTest < ActiveSupport::TestCase
  setup do
    referential = seed_referential
    @series = referential[:series].values.first
    @level = referential[:levels].fetch("3eme")
    @material = referential[:materials].fetch("mathematiques")
    @team = create_team_member(team_role: "content", second_factor: false)
    @actor = Repositories::Identity::UserRepository.new.actor_for(user_id: @team.id)
    @course = create_course(level: @level, material: @material, name: "Calcul littéral")
    notion = revision_notion("Notion un")
    sheet = notion.slice("method", "example", "pitfall").merge("remember" => "Ancien retenu.")
    @notion = create_essential(course: @course, name: "Notion un", sheet:)
    @exercise = create_exercise(essential: @notion, title: "Exo un")
    @question = @exercise.questions.order(:position).first
    @question.update!(explanation: "Ancienne explication.")
  end

  def data(*changes, course: { "name" => "Calcul littéral", "level_name" => @level.name, "material_name" => @material.name })
    { "lessons" => [ { "file" => "3eme/mathematiques/calcul-litteral.json", "course" => course, "changes" => changes } ] }
  end

  def notion_change(avant: "Ancien retenu.", apres: "Nouveau retenu.")
    { "kind" => "notion", "path" => "notions[0].remember", "notion" => 0, "field" => "remember", "avant" => avant, "apres" => apres }
  end

  def explanation_change(avant: "Ancienne explication.", apres: "Nouvelle explication.")
    { "kind" => "exercise", "path" => "notions[0].exercise[0].questions[0].explanation", "group" => "notion", "notion" => 0, "exercise" => 0,
      "question" => 0, "field" => "explanation", "avant" => avant, "apres" => apres }
  end

  def key_change(answer: 1, avant: false)
    { "kind" => "exercise", "path" => "notions[0].exercise[0].questions[0].answers[#{answer}].correct", "group" => "notion", "notion" => 0,
      "exercise" => 0, "question" => 0, "answer" => answer, "field" => "correct", "avant" => avant, "apres" => !avant }
  end

  def run_script(payload, apply: false)
    transaction = Repositories::Shared::Transaction.new
    audit_log = Repositories::Identity::AuditLogRepository.new
    policy = Policies::Catalog::ManageContentPolicy.new
    out = StringIO.new
    runner = Contenus::CorrectionsProduction.new(
      data: payload, actor: @actor, out:,
      notion_use_case: UseCases::Catalog::CorrectNotionText.new(essentials: Repositories::Catalog::EssentialRepository.new, audit_log:, transaction:, policy:, clock: Time.zone),
      exercise_use_case: UseCases::Assessment::CorrectExerciseText.new(exercises: Repositories::Assessment::ExerciseRepository.new, audit_log:, transaction:, policy:, clock: Time.zone)
    )
    [ runner.call(apply:), out.string ]
  end

  test "corrections-production: the trial run reports what it would apply and writes nothing" do
    rows, out = run_script(data(notion_change, explanation_change))

    assert_equal [ :a_appliquer, :a_appliquer ], rows.map(&:status)
    assert_includes out, "essai (aucune écriture)"
    assert_equal "Ancien retenu.", @notion.reload.sheet["remember"]
    assert_equal "Ancienne explication.", @question.reload.explanation
    assert_equal 0, Orm::AuditEvent.where(action: "content.corrected").count
  end

  test "corrections-production: applying writes through the use cases, journals them, and a second run finds nothing to apply" do
    rows, = run_script(data(notion_change, explanation_change, key_change, key_change(answer: 0, avant: true)), apply: true)

    assert_equal [ :appliquee ] * 4, rows.map(&:status)
    assert_equal "Nouveau retenu.", @notion.reload.sheet["remember"]
    assert_equal 3, @notion.sheet["method"].size
    assert_equal "Nouvelle explication.", @question.reload.explanation
    assert_equal [ 2 ], @question.answers.where(correct: true).order(:position).pluck(:position)
    assert_equal 2, Orm::AuditEvent.where(action: "content.corrected").count

    again, = run_script(data(notion_change, explanation_change, key_change, key_change(answer: 0, avant: true)))
    assert_equal [ :deja_a_jour ] * 4, again.map(&:status)
  end

  test "corrections-production: a value that is not the Avant is listed and never forced, the rest is applied" do
    rows, out = run_script(data(notion_change(avant: "Autre texte."), explanation_change), apply: true)

    assert_equal [ :introuvable, :appliquee ], rows.map(&:status)
    assert_equal "Ancien retenu.", @notion.reload.sheet["remember"]
    assert_equal "Nouvelle explication.", @question.reload.explanation
    assert_includes out, "[introuvable] 3eme/mathematiques/calcul-litteral.json · notions[0].remember"
  end

  test "corrections-production: a target with one missing Avant is left whole, none of its fields is written" do
    rows, out = run_script(data(explanation_change, explanation_change.merge("field" => "content", "avant" => "Autre", "apres" => "X")), apply: true)

    assert_equal [ :introuvable, :introuvable ], rows.map(&:status)
    assert_equal "Ancienne explication.", @question.reload.explanation
    assert_includes out, "cible laissée telle quelle"
    assert_equal 0, Orm::AuditEvent.where(action: "content.corrected").count
  end

  test "corrections-production: a missing lesson, notion or exercise is listed, a change without use case is out of scope" do
    gone, = run_script(data(notion_change, course: { "name" => "Absente", "level_name" => @level.name, "material_name" => @material.name }))
    assert_equal [ :introuvable ], gone.map(&:status)

    other_notion = notion_change.merge("notion" => 5)
    other_exercise = explanation_change.merge("exercise" => 4)
    practice = { "kind" => "hors_perimetre", "path" => "notions[0].practice.questions[0].explanation", "avant" => "a", "apres" => "b" }
    rows, = run_script(data(other_notion, other_exercise, practice), apply: true)
    assert_equal [ :hors_perimetre, :introuvable, :introuvable ], rows.map(&:status).sort_by { [ :hors_perimetre, :introuvable ].index(it) }
  end

  def change_in(group, **place)
    explanation_change.merge("group" => group, "path" => "#{group}.explanation", **place.transform_keys(&:to_s))
  end

  test "corrections-production: problems and subject exercises are found by their place, a missing one is listed" do
    problem = create_lesson_wide_exercise(course: @course)
    problem.questions.order(:position).first.update!(explanation: "Ancienne explication.")
    subject = create_subject(course: @course)
    in_subject = create_exercise(subject:, course: @course)
    in_subject.questions.order(:position).first.update!(explanation: "Ancienne explication.")

    rows, = run_script(data(change_in("problem", exercise: 0), change_in("subject", subject: 0, exercise: 0), change_in("subject", subject: 3, exercise: 0),
                            change_in("problem", exercise: 7)), apply: true)

    assert_equal [ :appliquee, :appliquee, :introuvable, :introuvable ], rows.map(&:status)
    assert_equal "Nouvelle explication.", problem.questions.order(:position).first.reload.explanation
    assert_equal "Nouvelle explication.", in_subject.questions.order(:position).first.reload.explanation
  end

  test "corrections-production: a question or an answer that does not exist is listed" do
    rows, = run_script(data(explanation_change.merge("question" => 9), key_change(answer: 9)))

    assert_equal [ :introuvable, :introuvable ], rows.map(&:status)
  end

  test "corrections-production: a lesson of a series is found by its series" do
    course = create_course(level: @level, material: @material, series: @series, name: "Calcul serie")
    create_essential(course:, name: "Notion serie", sheet: @notion.sheet)
    identity = { "name" => "Calcul serie", "level_name" => @level.name, "material_name" => @material.name, "series_name" => @series.name }
    with_series = notion_change.merge("path" => "notions[0].example.steps[1]", "field" => "example.steps[1]", "avant" => "Un", "apres" => "Deux")
    steps = @notion.sheet.dig("example", "steps")
    rows, = run_script(data(with_series.merge("avant" => steps[1], "apres" => "Corrigé"), course: identity), apply: true)

    assert_equal [ :appliquee ], rows.map(&:status)
    assert_equal "Corrigé", course.essentials.first.reload.sheet.dig("example", "steps", 1)
  end

  test "corrections-production: the name, the example and the method of a notion are corrected by their path" do
    sheet = @notion.sheet
    edits = [ [ "name", "name", @notion.name, "Notion corrigée" ], [ "example.statement", "example.statement", sheet.dig("example", "statement"), "Énoncé corrigé" ],
              [ "method[1]", "method[1]", sheet["method"][1], "Méthode corrigée" ] ]
    changes = edits.map { |path, field, avant, apres| notion_change(avant:, apres:).merge("path" => path, "field" => field) }
    rows, = run_script(data(*changes), apply: true)

    assert_equal [ :appliquee ] * 3, rows.map(&:status)
    @notion.reload
    assert_equal [ "Notion corrigée", "Énoncé corrigé", "Méthode corrigée" ], [ @notion.name, @notion.sheet.dig("example", "statement"), @notion.sheet["method"][1] ]
  end

  test "corrections-production: the title of an exercise is corrected, and fields already up to date stay as they are in a mixed target" do
    title = explanation_change.except("question").merge("path" => "notions[0].exercise[0].title", "field" => "title", "avant" => "Exo un", "apres" => "Exo corrigé")
    done = explanation_change(avant: "Autre", apres: "Ancienne explication.")
    rows, = run_script(data(title, done), apply: true)

    assert_equal [ :appliquee, :deja_a_jour ], rows.map(&:status)
    assert_equal "Exo corrigé", @exercise.reload.title

    refused = title.merge("avant" => "Exo corrigé", "apres" => "")
    failed, = run_script(data(refused, done), apply: true)
    assert_equal [ :echec, :deja_a_jour ], failed.map(&:status)
    assert_equal "Exo corrigé", @exercise.reload.title
  end

  test "corrections-production: a refused write is reported as a failure and changes nothing" do
    rows, = run_script(data(notion_change(apres: "")), apply: true)

    assert_equal [ :echec ], rows.map(&:status)
    assert_equal "Ancien retenu.", @notion.reload.sheet["remember"]
  end

  test "corrections-production: the rake task refuses to run without a team actor" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("contenus:corriger")
    task = Rake::Task["contenus:corriger"]
    task.reenable
    teacher = create_teacher
    with_env = lambda do |values, &block|
      previous = values.keys.index_with { ENV[it] }
      values.each { |key, value| ENV[key] = value }
      block.call
    ensure
      previous.each { |key, value| ENV[key] = value }
    end

    [ {}, { "ACTEUR" => "inconnu@example.com" }, { "ACTEUR" => teacher.contact } ].each do |variables|
      assert_raises(SystemExit) do
        with_env.call({ "LNCLASS_TEAM_CONTACT" => nil, "ACTEUR" => nil }.merge(variables)) { capture_io { task.invoke } }
      end
      task.reenable
    end
  end
end
