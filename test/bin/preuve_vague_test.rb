require "test_helper"
require "open3"
require "tmpdir"

# standard-de-test, Lot G (ADR standard-de-test §4 point 8) : bin/preuve-vague joue valider.rb, le test d'affichage et les
# captures d'une vague de leçons. Ici on ne lance ni navigateur ni base : le refus hors development, l'arrêt sur un
# valider.rb rouge, et le plan (--plan) qui dit où vont les captures.
class PreuveVagueTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("bin/preuve-vague").to_s
  CLEAN = { "RAILS_ENV" => "development", "RAILWAY_ENVIRONMENT_NAME" => nil, "DATABASE_URL" => nil }.freeze

  def preuve(*args, env: {})
    env = { "PREUVE_VAGUE_RACINE" => @root }.compact.merge(env)
    Open3.capture2e(CLEAN.merge(env), SCRIPT, *args, chdir: Rails.root.to_s)
  end

  # Un dossier de vague jetable : <racine jetable>/<vague>/<matière>/<fichier>.json. La racine est hors du dépôt : le semis,
  # qui lit docs/contenus/lecons-traitees, ne peut jamais le voir (tests parallèles).
  def wave
    Dir.mktmpdir("lecons-") do |root|
      @root = File.realpath(root)
      folder = Pathname(@root).join("zz-preuve-test-#{Process.pid}")
      folder.join("mathematiques").mkpath
      folder.join("svt").mkpath
      yield folder
    ensure
      @root = nil
    end
  end

  test "sans dossier, il affiche son usage et ne fait rien" do
    output, status = preuve

    assert_not status.success?
    assert_includes output, "Usage : bin/preuve-vague <dossier>"
  end

  test "hors development, il refuse avant tout, rien n'est joué" do
    wave do |folder|
      [ { "RAILS_ENV" => "test" }, { "RAILS_ENV" => "production" }, { "RAILWAY_ENVIRONMENT_NAME" => "Develop" },
        { "DATABASE_URL" => "postgres://distant/base" } ].each do |env|
        output, status = preuve(folder.to_s, env:)

        assert_not status.success?, env.inspect
        assert_match(/refusé/, output, env.inspect)
        assert_no_match(/valider\.rb/, output, env.inspect)
      end
    end
  end

  test "un valider.rb rouge arrête la preuve : verdict ECHEC, code non nul, ni affichage ni captures" do
    wave do |folder|
      folder.join("mathematiques/cassee.json").write("{ pas du json")
      output, status = preuve(folder.to_s)

      assert_not status.success?
      assert_match(/valider\.rb/, output)
      assert_match(/Verdict : ECHEC/, output)
      assert_match(/affichage.*non joué/i, output)
      assert_match(/captures.*non jouées/i, output)
    end
  end

  test "un dossier sans fichier de leçon ou inexistant est refusé" do
    wave do |folder|
      output, status = preuve(folder.to_s)

      assert_not status.success?
      assert_match(/aucun fichier/i, output)
    end
    output, status = preuve("/nulle/part")

    assert_not status.success?
    assert_match(/introuvable/, output)
  end

  test "un dossier hors docs/contenus/lecons-traitees, ou la racine elle-même, est refusé et rien n'est effacé" do
    Dir.mktmpdir("vague-") do |root|
      Pathname(root).join("x.json").write("{}")
      [ root, "docs/contenus/lecons-traitees", "docs", "." ].each do |path|
        output, status = preuve(path)

        assert_not status.success?, path
        assert_match(/refusé/, output, path)
      end
      assert Pathname(root).join("x.json").exist?
    end
  end

  test "--plan dit les fichiers, une leçon par matière et un dossier de captures ignoré par git sous tmp/preuves" do
    wave do |folder|
      %w[mathematiques/b.json mathematiques/a.json svt/c.json].each { folder.join(it).write("{}") }
      output, status = preuve("--plan", folder.to_s)

      assert status.success?, output
      assert_includes output, "3 fichier(s)"
      assert_match(%r{capture : mathematiques/a\.json}, output)
      assert_no_match(%r{capture : mathematiques/b\.json}, output)
      assert_match(%r{capture : svt/c\.json}, output)
      target = output[%r{tmp/preuves/zz-preuve-test-\d+}]

      assert target, output
      _, ignored = Open3.capture2("git", "check-ignore", "-q", "#{target}/mathematiques-390.png", chdir: Rails.root.to_s)
      assert ignored.success?, "#{target} doit être ignoré par git"
    end
  end
end
