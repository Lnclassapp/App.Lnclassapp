require "test_helper"
require "rake"
require "open3"

# Chantier standard-de-test, Lot C : `bin/rails pages:lentes` (bin/pages-lentes). Un petit établissement fictif, les vraies pages de chaque
# rôle par de vraies requêtes de l'application ; l'environnement est joué en développement le temps d'un appel (le test tourne en `test`,
# que la tâche refuse comme tout autre).
class PagesLentesTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("pages:lentes")
    referential = seed_referential
    level = referential[:levels].fetch("3eme")
    material = referential[:materials].fetch("mathematiques")
    @school = create_school(name: "Grand établissement test")
    @classroom = create_classroom(school: @school, level:, name: "3ème 1")
    @quiet_classroom = create_classroom(school: @school, level:, name: "3ème 2")
    @teacher = create_teacher(classrooms: [ @classroom, @quiet_classroom ], school: @school, material:)
    @student = create_student(classroom: @classroom, last_name: "Bamba")
    create_student(classroom: @quiet_classroom)
    @direction = create_school_admin(school: @school, position: "head")
    @team = create_team_member(team_role: "admin")
    course = create_course(level:, material:)
    create_assignment(classroom: @classroom, assignable: create_exercise(course:, lesson_wide: true), by: @teacher)
  end

  # → [sortie, erreur, SystemExit ou nil]
  def lentes(environment: "development", **variables)
    task = Rake::Task["pages:lentes"]
    task.reenable
    exit_error = nil
    out, err = capture_io do
      with_env({ "PAGES_LENTES_ECOLE" => @school.name, "PAGES_LENTES_CHAUFFE" => "0" }.merge(variables.transform_keys(&:to_s))) do
        with_rails_env(environment) { task.invoke }
      end
    rescue SystemExit => e
      exit_error = e
    end
    [ out, err, exit_error ]
  end

  def with_rails_env(name)
    original = Rails.method(:env)
    Rails.define_singleton_method(:env) { ActiveSupport::EnvironmentInquirer.new(name) }
    yield
  ensure
    Rails.define_singleton_method(:env, original)
  end

  def with_env(variables)
    saved = variables.keys.to_h { [ it, ENV[it] ] }
    variables.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| ENV[key] = value }
  end

  # Les lignes du tableau d'un rôle : [rôle, page, durée, requêtes, état, drapeaux].
  def rows(out, role)
    out.lines.filter_map { |line| line.strip.split(/\s{2,}/) if line.start_with?("#{role} ") }
  end

  test "refuses outside development and visits nothing" do
    %w[production test staging].each do |environment|
      out, err, exit_error = lentes(environment:)

      assert exit_error, "#{environment} doit être refusé"
      assert_match(/development/, err)
      assert_empty out
    end
  end

  test "the script refuses a RAILS_ENV other than development, a Railway environment or a DATABASE_URL" do
    [ { "RAILS_ENV" => "test" }, { "RAILS_ENV" => "production" }, { "RAILWAY_ENVIRONMENT_NAME" => "Develop" },
      { "DATABASE_URL" => "postgres://example.invalid/db" } ].each do |env|
      out, status = Open3.capture2e({ "RAILS_ENV" => "test", **env }, Rails.root.join("bin/pages-lentes").to_s)

      assert_not status.success?, "#{env} doit être refusé"
      assert_match(/refus/, out)
    end
  end

  test "the task refuses a Railway environment, a DATABASE_URL and a database that is not local, and visits nothing" do
    [ { "RAILWAY_ENVIRONMENT_NAME" => "Develop" }, { "DATABASE_URL" => "postgres://example.invalid/db" } ].each do |variables|
      out, err, exit_error = lentes(**variables)

      assert exit_error, "#{variables} doit être refusé"
      assert_match(/refus/, err)
      assert_empty out
    end
    original = PagesLentes.method(:database_host)
    PagesLentes.define_singleton_method(:database_host) { "db.example.com" }
    out, err, exit_error = lentes

    assert exit_error
    assert_match(/refus.*local/, err)
    assert_empty out
  ensure
    PagesLentes.define_singleton_method(:database_host, original)
  end

  test "the script refuses an unknown option, role or threshold" do
    [ "--vite", "--role=parent", "--seuil=lent", "--seuil=0" ].each do |argument|
      out, status = Open3.capture2e({ "RAILS_ENV" => "development" }, Rails.root.join("bin/pages-lentes").to_s, argument)

      assert_not status.success?, "#{argument} doit être refusé"
      assert_match(/Usage|refus/, out)
    end
  end

  test "lists the pages of every role with their time and their number of SQL queries" do
    out, _, exit_error = lentes

    assert_nil exit_error
    %w[eleve enseignant direction equipe].each do |role|
      pages = rows(out, role)

      assert_operator pages.size, :>=, 4, "#{role} : des pages attendues, reçu\n#{out}"
      pages.each do |_role, _page, milliseconds, queries, status|
        assert_match(/\A\d+(\.\d+)? ms\z/, milliseconds)
        assert_match(/\A\d+\z/, queries)
        assert_equal "200", status, "#{role} : une page qui ne répond pas 200 n'est pas mesurée\n#{out}"
      end
    end
    assert_match(/accueil/, out)
    assert_match(/Seuil : 500 ms/, out)
    assert_includes out, "assigner (modale)"
  end

  test "a page that does not answer 200 is flagged as a defect and the exit is not zero" do
    Orm::Exercise.update_all(status: "draft")

    out, _, exit_error = lentes("PAGES_LENTES_ROLE" => "eleve")

    assert_match(/STATUT/, out)
    assert_match(/page\(s\) en défaut/, out)
    assert exit_error
    assert_equal 1, exit_error.status
  end

  test "a sign-in that fails makes the exit not zero" do
    @direction.update!(pin: "1357")

    _, _, exit_error = lentes("PAGES_LENTES_ROLE" => "direction")

    assert_equal 1, exit_error.status
  end

  test "a team account whose second factor is refused is not measured" do
    Orm::TotpCredential.where(user_id: @team.id).update_all(secret: ROTP::Base32.random)
    Orm::User.where(id: @team.id).update_all(updated_at: Time.current)
    Orm::TotpCredential.where(user_id: @team.id).update_all(confirmed_at: nil)

    out, _, exit_error = lentes("PAGES_LENTES_ROLE" => "equipe")

    assert_match(/equipe.*connexion/i, out)
    assert_empty out.lines.grep(/\Aequipe .* ms/)
    assert_equal 1, exit_error.status
  end

  test "visits the heavy pages: filtered and long-period dashboards, a DRENA's schools" do
    out, = lentes

    assert_includes out, "tableau de bord (DRENA)"
    assert_includes out, "tableau de bord (année)"
    assert_includes out, "établissements d'une DRENA"
  end

  test "is sorted by time, slowest first" do
    out, = lentes

    times = out.lines.filter_map { |line| line[/\s(\d+(?:\.\d+)?) ms\s/, 1]&.to_f }
    assert_equal times.sort.reverse, times
  end

  test "flags the pages above the threshold and the pages above 100 queries" do
    out, = lentes("PAGES_LENTES_SEUIL" => "0.001")

    assert_match(/LENTE/, out)
    assert_match(/page\(s\) lente/, out)

    calm, = lentes("PAGES_LENTES_SEUIL" => "60000")
    assert_no_match(/LENTE|REQUÊTES/, calm)
    assert_match(/aucune page lente/i, calm)
  end

  test "flags a page that runs more than the queries limit" do
    out, = lentes("PAGES_LENTES_SEUIL" => "60000", "PAGES_LENTES_REQUETES" => "1")

    assert_match(/REQUÊTES/, out)
  end

  test "keeps only the asked role" do
    out, = lentes("PAGES_LENTES_ROLE" => "direction")

    assert_not_empty rows(out, "direction")
    %w[eleve enseignant equipe].each { |role| assert_empty rows(out, role) }
  end

  test "names the role it could not sign in as and goes on" do
    @direction.update!(pin: "1357")

    out, = lentes

    assert_match(/direction.*connexion/i, out)
    assert_not_empty rows(out, "enseignant")
  end

  test "skips a role the school does not have" do
    Orm::SchoolStaff.delete_all

    out, = lentes

    assert_match(/direction.*aucun compte/i, out)
    assert_not_empty rows(out, "eleve")
  end

  test "an unknown school is reported without any visit" do
    _, err, exit_error = lentes("PAGES_LENTES_ECOLE" => "Établissement inconnu")

    assert exit_error
    assert_match(/introuvable/, err)
  end
end
