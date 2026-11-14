require "test_helper"
require "open3"
require "yaml"
require Rails.root.join("script/contenus/synchroniser")

# ADR contenus-dans-un-depot-dedie-copie-figee §4 et §7 : la copie figée des leçons ne s'écrit que depuis une version
# du dépôt de contenus, après contrôle de chaque fichier, et la CI repère une leçon modifiée sans nouvelle version.
class ContenusSynchroniserTest < ActiveSupport::TestCase
  setup do
    @dir = Pathname(Dir.mktmpdir("synchroniser"))
    @source = @dir.join("contenus")
    @target = @dir.join("app/lecons-traitees")
    @version = @dir.join("app/VERSION")
    @out = StringIO.new
    @target.mkpath
    git("init", "-q", "-b", "main")
    git("config", "user.email", "test@example.invalid")
    git("config", "user.name", "Test")
  end

  teardown { FileUtils.rm_rf(@dir) }

  def git(*args)
    @source.mkpath
    output, status = Open3.capture2e("git", "-C", @source.to_s, *args)
    assert status.success?, output
    output.strip
  end

  def lesson(path, document = revision_sheet_document)
    file = @source.join("lecons", path)
    file.dirname.mkpath
    file.write(JSON.pretty_generate(document))
  end

  def commit(message = "leçons")
    git("add", "-A")
    git("commit", "-q", "-m", message)
    git("rev-parse", "HEAD")
  end

  def synchroniser(**options) = Contenus::Synchroniser.new(source: @source, target: @target, version_file: @version, out: @out).synchroniser(**options)

  def verifier = Contenus::Synchroniser.new(target: @target, version_file: @version, out: @out).verifier

  test "copie les leçons d'une version, retire celles qui n'y sont plus et écrit la version" do
    lesson("3eme/mathematiques/01-thales.json")
    sha = commit
    stale = @target.join("3eme/francais/ancienne.json")
    stale.dirname.mkpath
    stale.write("{}")

    assert_equal 0, synchroniser
    assert @target.join("3eme/mathematiques/01-thales.json").file?
    assert_not stale.exist?, "une leçon absente de la version est retirée de la copie"
    version = YAML.safe_load_file(@version)
    assert_equal sha, version.fetch("sha")
    assert_equal 1, version.fetch("fichiers")
    assert_match(/\A\h{64}\z/, version.fetch("empreinte"))
  end

  test "refuse une version dont une leçon échoue au contrôle : rien n'est copié" do
    lesson("3eme/mathematiques/01-thales.json")
    broken = Marshal.load(Marshal.dump(revision_sheet_document))
    broken["courses"].first["notions"][1].delete("exercise")
    lesson("3eme/mathematiques/02-faute.json", broken)
    commit
    kept = @target.join("3eme/francais/en-place.json")
    kept.dirname.mkpath
    kept.write("{}")

    assert_equal 1, synchroniser
    assert kept.exist?, "la copie en place reste intacte"
    assert_not @target.join("3eme/mathematiques/01-thales.json").exist?
    assert_not @version.exist?
    assert_includes @out.string, "02-faute.json"
  end

  test "refuse un JSON illisible : rien n'est copié" do
    file = @source.join("lecons/3eme/svt/01-cassee.json")
    file.dirname.mkpath
    file.write("{ pas du json")
    commit

    assert_equal 1, synchroniser
    assert_not @version.exist?
    assert_includes @out.string, "01-cassee.json"
  end

  test "refuse une source qui n'est pas un dépôt git, ou dont l'arbre n'est pas propre" do
    plain = @dir.join("pas-un-depot/lecons")
    plain.mkpath
    assert_equal 1, Contenus::Synchroniser.new(source: plain.dirname, target: @target, version_file: @version, out: @out).synchroniser

    lesson("3eme/mathematiques/01-thales.json")
    commit
    lesson("3eme/mathematiques/02-non-commitee.json")
    assert_equal 1, synchroniser
    assert_not @version.exist?
  end

  test "refuse de revenir à une version plus ancienne, sauf si on le force" do
    lesson("3eme/mathematiques/01-thales.json")
    old = commit("v1")
    lesson("3eme/mathematiques/02-pythagore.json")
    commit("v2")
    assert_equal 0, synchroniser
    git("checkout", "-q", old)

    assert_equal 1, synchroniser
    assert_equal 2, YAML.safe_load_file(@version).fetch("fichiers")
    assert_equal 0, synchroniser(forcer: true)
    assert_equal old, YAML.safe_load_file(@version).fetch("sha")
  end

  test "la vérification passe sur une copie synchronisée et refuse une leçon modifiée, ajoutée ou retirée à la main" do
    lesson("3eme/mathematiques/01-thales.json")
    commit
    synchroniser
    assert_equal 0, verifier

    copy = @target.join("3eme/mathematiques/01-thales.json")
    original = copy.read
    copy.write(original.sub("}", ", \"x\": 1}"))
    assert_equal 1, verifier
    copy.write(original)

    @target.join("3eme/mathematiques/02-ajout.json").write("{}")
    assert_equal 1, verifier
    @target.join("3eme/mathematiques/02-ajout.json").delete

    copy.delete
    assert_equal 1, verifier
    assert_includes @out.string, "synchroniser"
  end

  test "la vérification ne refuse rien tant qu'aucune version n'a été synchronisée" do
    @target.join("3eme").mkpath
    @target.join("3eme/libre.json").write("{}")

    assert_equal 0, verifier
    assert_includes @out.string, "aucune version"
  end
end
