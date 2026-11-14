require "test_helper"
require "rake"
require Rails.root.join("lib/contenus/corrections_production")

# Chantier corrections-production : le script reporte les corrections par les use cases « Modifier le texte », jamais par SQL, et ne force
# jamais une valeur qui n'est pas l'« Avant ».
class CorrectionsProductionTest < ActiveSupport::TestCase
  setup do
    referential = seed_referential
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

  test "corrections-production: a missing lesson, notion or exercise is listed, a change without use case is out of scope" do
    gone, = run_script(data(notion_change, course: { "name" => "Absente", "level_name" => @level.name, "material_name" => @material.name }))
    assert_equal [ :introuvable ], gone.map(&:status)

    other_notion = notion_change.merge("notion" => 5)
    other_exercise = explanation_change.merge("exercise" => 4)
    practice = { "kind" => "hors_perimetre", "path" => "notions[0].practice.questions[0].explanation", "avant" => "a", "apres" => "b" }
    rows, = run_script(data(other_notion, other_exercise, practice), apply: true)
    assert_equal [ :hors_perimetre, :introuvable, :introuvable ], rows.map(&:status).sort_by { [ :hors_perimetre, :introuvable ].index(it) }
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
